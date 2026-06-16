//
//  TestInputView.swift
//  Remoboard
//
//  A scratch field for verifying remote input without leaving the app.
//

import SwiftUI

struct TestInputView: View {
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("testinput.hint", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            TextEditor(text: $text)
                .focused($focused)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .navigationTitle(NSLocalizedString("home.testinput", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(NSLocalizedString("testinput.clear", comment: "")) { text = "" }
            }
        }
        .onAppear { focused = true }
    }
}

#Preview {
    NavigationView { TestInputView() }
}
