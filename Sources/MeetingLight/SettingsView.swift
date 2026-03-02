import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: LightState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Meeting Light")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $state.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            Picker("Mode", selection: modeBinding) {
                Text("Warm").tag(0)
                Text("Color").tag(1)
            }
            .pickerStyle(.segmented)

            if state.mode == .warm {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Warmth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Image(systemName: "snowflake")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Slider(value: $state.warmth, in: 0...1)
                            .tint(warmthTint)
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hue: state.hue, saturation: 0.8, brightness: 1.0))
                            .frame(width: 16, height: 16)
                        Slider(value: $state.hue, in: 0...1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Border Size")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.center.inset.filled")
                        .font(.caption)
                    Slider(value: $state.borderSizePercent, in: 0.01...0.35)
                    Image(systemName: "rectangle.inset.filled")
                        .font(.caption)
                }
                Text("\(Int(state.borderSizePercent * 100))% of screen height")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            HStack {
                Text("Hotkey:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: {
                    HotkeyManager.shared?.startRecording()
                }) {
                    Text(state.isRecordingHotkey ? "Press keys..." : state.hotkeyDisplayString)
                        .font(.caption)
                        .frame(minWidth: 60)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }

            HStack {
                Toggle("Launch at Login", isOn: $state.launchAtLogin)
                    .font(.caption)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var modeBinding: Binding<Int> {
        Binding(
            get: { state.mode.rawValue },
            set: { state.mode = LightMode(rawValue: $0) ?? .warm }
        )
    }

    private var warmthTint: Color {
        Color(hue: 0.08 * state.warmth, saturation: state.warmth * 0.5, brightness: 1.0)
    }
}
