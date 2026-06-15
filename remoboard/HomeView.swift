//
//  HomeView.swift
//  Remoboard
//
//  Onboarding + entry point. The host app explains how to enable the keyboard and
//  lets the user manage quick words and try the remote input out.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var handoff: HandoffStore

    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remoboard")
                            .font(.largeTitle.bold())
                        Text(NSLocalizedString("home.tagline", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section(NSLocalizedString("home.howto.title", comment: "")) {
                    StepRow(number: 1, text: NSLocalizedString("home.howto.step1", comment: ""))
                    StepRow(number: 2, text: NSLocalizedString("home.howto.step2", comment: ""))
                    StepRow(number: 3, text: NSLocalizedString("home.howto.step3", comment: ""))
                    StepRow(number: 4, text: NSLocalizedString("home.howto.step4", comment: ""))
                }

                Section {
                    NavigationLink {
                        QuickWordsView()
                    } label: {
                        Label(NSLocalizedString("home.quickwords", comment: ""), systemImage: "text.badge.star")
                    }
                    NavigationLink {
                        TestInputView()
                    } label: {
                        Label(NSLocalizedString("home.testinput", comment: ""), systemImage: "keyboard")
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(NSLocalizedString("home.opensettings", comment: ""), systemImage: "gear")
                    }
                } footer: {
                    Text(NSLocalizedString("home.fullaccess.note", comment: ""))
                }
            }
            .navigationTitle("Remoboard")
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: Binding(
            get: { handoff.receivedText != nil },
            set: { if !$0 { handoff.receivedText = nil } }
        )) {
            if let text = handoff.receivedText {
                ReceivedView(text: text) { handoff.receivedText = nil }
            }
        }
    }
}

private struct StepRow: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView()
        .environmentObject(HandoffStore())
}
