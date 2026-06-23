import SwiftUI

/// Blocks the host app until the keyboard extension confirms Full Access (non-dismissible).
struct FullAccessRequiredView: View {
    @Bindable var monitor: KeyboardAccessMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "keyboard.badge.ellipsis")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    Text(String(localized: "onboarding.full_access.title"))
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text(String(localized: "onboarding.full_access.message"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    statusCard

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "onboarding.full_access.steps_title"))
                            .font(.subheadline.weight(.semibold))
                        Label(String(localized: "settings.keyboard_setup.step_enable"), systemImage: "1.circle.fill")
                        Label(String(localized: "onboarding.full_access.step_open_keyboard"), systemImage: "2.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Button {
                        monitor.openAppSettings()
                    } label: {
                        Text(String(localized: "onboarding.full_access.open_app_settings"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        monitor.refresh()
                    } label: {
                        Text(String(localized: "settings.keyboard_setup.refresh"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: String.LocalizationValue(monitor.fullAccessStatusKey)))
                    .font(.subheadline.weight(.semibold))
                Text(String(localized: "onboarding.full_access.status_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var statusIcon: String {
        switch monitor.status.fullAccessState {
        case .enabled: return "checkmark.circle.fill"
        case .disabled: return "exclamationmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch monitor.status.fullAccessState {
        case .enabled: return .green
        case .disabled: return .orange
        case .unknown: return .secondary
        }
    }
}
