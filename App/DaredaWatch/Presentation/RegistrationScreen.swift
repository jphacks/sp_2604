import SwiftUI

/// 新規登録の入力。要約は iPhone で作った内容を初期値にし、保存は iPhone で行う。
struct RegistrationScreen: View {
    let draft: WatchRegistrationDraft
    let send: (WatchCommand) -> Void

    @State private var name = ""
    @State private var affiliation = ""
    @State private var summary: String?
    @State private var placeQuery = ""
    @State private var place: WatchPlace?

    var body: some View {
        Form {
            Section {
                TextField("名前", text: $name)
                    .accessibilityIdentifier("watch.registration.name")
                TextField("所属", text: $affiliation)
                    .accessibilityIdentifier("watch.registration.affiliation")
                TextField("要約", text: Binding(get: { summary ?? draft.summary }, set: { summary = $0 }), axis: .vertical)
                    .accessibilityIdentifier("watch.registration.summary")
            } footer: {
                Text(draft.metAt, format: .dateTime.month().day().hour().minute())
            }

            Section("場所") {
                if let place {
                    Label(place.name, systemImage: "mappin.and.ellipse")
                    Button("場所を外す", role: .destructive) { self.place = nil }
                }
                TextField("場所を検索", text: $placeQuery)
                    .onSubmit { if !placeQuery.isEmpty { send(.searchPlaces(placeQuery)) } }
                    .accessibilityIdentifier("watch.registration.placeQuery")
                ForEach(draft.placeCandidates, id: \.self) { candidate in
                    Button(candidate.name) { place = candidate }
                }
            }

            if let errorMessage = draft.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                }
            }

            Section {
                Button("保存") {
                    send(.register(name: name, affiliation: affiliation, summary: summary ?? draft.summary, place: place))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("watch.registration.save")
            }
        }
        .navigationTitle("新規登録")
    }
}

#Preview {
    NavigationStack {
        RegistrationScreen(
            draft: WatchRegistrationDraft(
                summary: "展示会で名刺交換した。",
                metAt: Date(timeIntervalSince1970: 1_800_000_000),
                placeCandidates: [WatchPlace(name: "東京ビッグサイト", latitude: 35.63, longitude: 139.79)]
            ),
            send: { _ in }
        )
    }
}
