fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

証明書とプロファイルを取得する (読み取り専用)

### ios renew_certificates

```sh
[bundle exec] fastlane ios renew_certificates
```

Bundle ID を登録し、証明書とプロファイルを作成・更新して保存する

### ios add_device

```sh
[bundle exec] fastlane ios add_device
```

デバイスを登録して Development・Ad Hoc プロファイルを更新する (name: 名前, udid: UDID)

### ios distribute

```sh
[bundle exec] fastlane ios distribute
```

Ad Hoc ビルドを Firebase App Distribution にアップロードし、developers グループに配信する

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
