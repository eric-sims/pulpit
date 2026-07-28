import SacramentKit
import SwiftUI

struct HymnPickerView: View {
    @Bindable var item: ProgramItem
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var book: HymnBook = .hymns1985
    @State private var sacramentOnly = false

    private var results: [Hymn] {
        let pool = HymnCatalog.shared.search(query, in: book)
        guard sacramentOnly else { return pool }
        // `.unknown` stays in the list: the new hymnbook publishes no sections yet, and hiding
        // "As Bread Is Broken" from a sacrament-hymn filter would be plainly wrong.
        return pool.filter { $0.sacramentSuitability != .no }
    }

    var body: some View {
        NavigationStack {
            List {
                if item.hymn != nil {
                    Section {
                        Button("Clear selection", systemImage: "xmark.circle", role: .destructive) {
                            item.setHymn(nil)
                            dismiss()
                        }
                    }
                }
                Section {
                    ForEach(results) { hymn in
                        Button {
                            item.setHymn(hymn)
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(hymn.number)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 48, alignment: .trailing)
                                Text(hymn.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if hymn.id == item.hymn?.id {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("\(results.count) hymn\(results.count == 1 ? "" : "s")")
                } footer: {
                    if book == .homeAndChurch {
                        Text("Hymns—For Home and Church is still being released and has no topical sections yet, so the sacrament filter can't narrow it.")
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Number or title")
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Book", selection: $book) {
                        ForEach(HymnBook.allCases, id: \.self) { book in
                            Text(book.shortName).tag(book)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .safeAreaInset(edge: .top) {
                if item.kind.requiresSacramentHymn {
                    Toggle("Sacrament hymns only", isOn: $sacramentOnly)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
            .onAppear {
                sacramentOnly = item.kind.requiresSacramentHymn
                if let existing = item.hymn { book = existing.book }
            }
        }
    }
}
