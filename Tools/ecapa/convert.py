"""SpeechBrain の ECAPA-TDNN (spkrec-ecapa-voxceleb) を Core ML に変換する。

入力は 16kHz モノラルの波形 (1, N)。fbank 特徴量の算出と文単位の平均正規化もモデルに含めるため、
アプリ側は PCM サンプルをそのまま渡せばよい。出力は 192 次元の埋め込みベクトル (L2 正規化前)。

使い方: uv run --python 3.11 --with-requirements requirements.txt convert.py <出力先 .mlpackage> [--fp16]
"""

import sys

import coremltools as ct
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from speechbrain.inference.speaker import EncoderClassifier

SAMPLE_RATE = 16000
N_FFT = 400
HOP = 160
TOP_DB = 80.0
MIN_SAMPLES = 8000  # 0.5 秒
MAX_SAMPLES = 16000 * 60
FP16 = "--fp16" in sys.argv


class Wrapper(nn.Module):
    """波形 -> fbank (speechbrain の Fbank と同等) -> 平均正規化 -> ECAPA-TDNN。"""

    def __init__(self, classifier):
        super().__init__()
        fbank = classifier.mods.compute_features
        self.embedding_model = classifier.mods.embedding_model
        # speechbrain の STFT は hamming 窓、center=True (ゼロパディング)
        window = torch.hamming_window(N_FFT, periodic=True)
        k = torch.arange(N_FFT // 2 + 1).unsqueeze(1)
        n = torch.arange(N_FFT).unsqueeze(0)
        angle = 2 * np.pi * k * n / N_FFT
        self.register_buffer("cos_kernel", (torch.cos(angle) * window).unsqueeze(1))
        self.register_buffer("sin_kernel", (torch.sin(angle) * window).unsqueeze(1))
        # (n_fft/2+1, n_mels)
        # 単位行列を通して三角フィルタ行列を取り出す
        fb = fbank.compute_fbanks
        log_mel = fb.log_mel
        fb.log_mel = False
        with torch.no_grad():
            matrix = fb(torch.eye(N_FFT // 2 + 1).unsqueeze(0))[0]
        fb.log_mel = log_mel
        self.register_buffer("fbank_matrix", matrix.detach().clone())

    def forward(self, wav):
        x = F.pad(wav.unsqueeze(1), (N_FFT // 2, N_FFT // 2), mode="constant", value=0.0)
        real = F.conv1d(x, self.cos_kernel, stride=HOP)
        imag = F.conv1d(x, self.sin_kernel, stride=HOP)
        power = real * real + imag * imag  # (1, F, T)
        mel = torch.matmul(power.transpose(1, 2), self.fbank_matrix)  # (1, T, n_mels)
        db = 10.0 * torch.log10(torch.clamp(mel, min=1e-10))
        db = torch.clamp(db, min=db.max() - TOP_DB)
        feats = db - db.mean(dim=1, keepdim=True)
        emb = self.embedding_model(feats)  # (1, 1, 192)
        return emb.reshape(1, -1)


def main(out_path):
    classifier = EncoderClassifier.from_hparams(
        source="speechbrain/spkrec-ecapa-voxceleb", savedir="pretrained", run_opts={"device": "cpu"}
    )
    classifier.eval()
    wrapper = Wrapper(classifier).eval()

    # 参照実装との一致を確認する
    wav = torch.randn(1, SAMPLE_RATE * 4) * 0.1
    with torch.no_grad():
        ref = classifier.encode_batch(wav).reshape(1, -1)
        got = wrapper(wav)
    cos = F.cosine_similarity(ref, got).item()
    print("torch parity cosine:", cos)
    assert cos > 0.999, cos

    with torch.no_grad():
        traced = torch.jit.trace(wrapper, wav)
    length = ct.RangeDim(lower_bound=MIN_SAMPLES, upper_bound=MAX_SAMPLES, default=SAMPLE_RATE * 4)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="waveform", shape=ct.Shape(shape=(1, length)), dtype=np.float32)],
        outputs=[ct.TensorType(name="embedding", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16 if FP16 else ct.precision.FLOAT32,
        convert_to="mlprogram",
    )
    mlmodel.short_description = "ECAPA-TDNN (speechbrain/spkrec-ecapa-voxceleb, Apache-2.0)"
    mlmodel.save(out_path)

    try:
        pred = mlmodel.predict({"waveform": wav.numpy()})["embedding"]
    except RuntimeError as e:  # macOS 以外・サンドボックス内など Core ML のコンパイルができない環境
        print("skip coreml parity:", e)
        return
    r = ref.numpy().flatten()
    p = pred.flatten()
    print("coreml parity cosine:", float(np.dot(p, r) / (np.linalg.norm(p) * np.linalg.norm(r))))


if __name__ == "__main__":
    main(sys.argv[1])
