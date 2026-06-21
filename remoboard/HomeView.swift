//
//  HomeView.swift
//  Remoboard
//
//  Home / onboarding. A brand hero, a visual setup card with one primary action,
//  quick-action tiles for the main features, and a footer — the pattern used by
//  well-designed keyboard utility apps.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var handoff: HandoffStore

    private let issuesURL = URL(string: "https://github.com/everettjf/Remoboard/issues/new?title=Language%20request:%20")!
    private let siteURL = URL(string: "https://xnu.app/remoboard")!

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    setupCard
                    quickActions
                    footer
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Text("Remoboard")
                .font(.largeTitle.bold())
            Text(NSLocalizedString("home.tagline", comment: ""))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: Setup card

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("home.howto.title", comment: ""))
                .font(.headline)

            VStack(spacing: 14) {
                StepRow(number: 1, text: NSLocalizedString("home.howto.step1", comment: ""))
                StepRow(number: 2, text: NSLocalizedString("home.howto.step2", comment: ""))
                StepRow(number: 3, text: NSLocalizedString("home.howto.step3", comment: ""))
                StepRow(number: 4, text: NSLocalizedString("home.howto.step4", comment: ""))
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(NSLocalizedString("home.opensettings", comment: ""), systemImage: "gear")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(NSLocalizedString("home.fullaccess.note", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(card)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 14) {
            NavigationLink {
                QuickWordsView()
            } label: {
                ActionTile(icon: "text.badge.star",
                           title: NSLocalizedString("home.quickwords", comment: ""),
                           subtitle: NSLocalizedString("home.quickwords.sub", comment: ""))
            }
            .buttonStyle(.plain)

            NavigationLink {
                TestInputView()
            } label: {
                ActionTile(icon: "keyboard",
                           title: NSLocalizedString("home.testinput", comment: ""),
                           subtitle: NSLocalizedString("home.testinput.sub", comment: ""))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Link(destination: issuesURL) {
                Label(NSLocalizedString("home.requestlang", comment: ""), systemImage: "globe")
                    .font(.subheadline)
            }
            Link("xnu.app", destination: siteURL)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

private struct StepRow: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(HandoffStore())
}
