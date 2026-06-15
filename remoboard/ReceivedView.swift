//
//  ReceivedView.swift
//  Remoboard
//
//  Shows text handed off from the keyboard, with copy and share actions.
//

import SwiftUI
import UIKit

struct ReceivedView: View {
    let text: String
    var onDone: () -> Void

    @State private var copied = false
    @State private var showShare = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    Text(text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                Divider()
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = text
                        copied = true
                    } label: {
                        Label(copied ? NSLocalizedString("received.copied", comment: "")
                                     : NSLocalizedString("received.copy", comment: ""),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showShare = true
                    } label: {
                        Label(NSLocalizedString("received.share", comment: ""), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("received.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("received.done", comment: ""), action: onDone)
                }
            }
            .sheet(isPresented: $showShare) {
                ActivityView(items: [text])
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
