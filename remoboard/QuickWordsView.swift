//
//  QuickWordsView.swift
//  Remoboard
//

import SwiftUI
import RemoboardKit

struct QuickWordsView: View {
    @State private var words: [String] = Settings.shared.quickWords
    @State private var newWord: String = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField(NSLocalizedString("quickwords.add.placeholder", comment: ""), text: $newWord)
                        .onSubmit(add)
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                ForEach(words.indices, id: \.self) { index in
                    Text(words[index])
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            } footer: {
                Text(NSLocalizedString("quickwords.footer", comment: ""))
            }
        }
        .navigationTitle(NSLocalizedString("home.quickwords", comment: ""))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarLeading) {
                Button(NSLocalizedString("quickwords.reset", comment: ""), action: reset)
            }
        }
    }

    private func add() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Settings.shared.addWord(trimmed)
        words = Settings.shared.quickWords
        newWord = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            Settings.shared.removeWord(at: index)
        }
        words = Settings.shared.quickWords
    }

    private func move(from source: IndexSet, to destination: Int) {
        words.move(fromOffsets: source, toOffset: destination)
        Settings.shared.quickWords = words
    }

    private func reset() {
        Settings.shared.resetDefaultWords()
        words = Settings.shared.quickWords
    }
}

#Preview {
    NavigationView { QuickWordsView() }
}
