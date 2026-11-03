import SwiftUI

struct SettingsView: View {

    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !state.accessibilityGranted { permissionCard }
                    soundSection
                    hapticsSection
                    feelSection
                    gesturesSection
                    footer
                }
                .padding(18)
            }
        }
        .frame(width: 430, height: 680)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(state.active && state.accessibilityGranted
                                 ? Color.accentColor : Color.secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("Detent").font(.system(size: 15, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $state.active)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!state.accessibilityGranted)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var statusText: String {
        if !state.accessibilityGranted { return "Waiting for Accessibility access" }
        return state.active ? "Clicking on every scroll" : "Paused"
    }

    // MARK: Permission

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility access needed", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text("macOS only reports scrolling to apps with this permission. "
                 + "Detent reads scroll movement and nothing else.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Privacy Settings") { state.requestAccessibility() }
                .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Sound

    private var soundSection: some View {
        Section(title: "Sound") {
            Toggle("Play a click", isOn: $state.soundEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("Voice").font(.system(size: 11)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)],
                          spacing: 6) {
                    ForEach(allVoices, id: \.id) { voice in
                        VoiceChip(voice: voice,
                                  selected: state.voice == voice.id) {
                            state.voice = voice.id
                        }
                    }
                }
            }
            .disabled(!state.soundEnabled)
            .opacity(state.soundEnabled ? 1 : 0.4)

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Slider(value: $state.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Text("\(Int(state.volume * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
            .disabled(!state.soundEnabled)
            .opacity(state.soundEnabled ? 1 : 0.4)
        }
    }

    // MARK: Haptics

    private var hapticsSection: some View {
        Section(title: "Haptics") {
            Toggle("Tap the trackpad", isOn: $state.hapticsEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("Strength").font(.system(size: 11)).foregroundStyle(.secondary)
                Picker("", selection: $state.hapticStrength) {
                    ForEach(HapticStrength.allCases, id: \.self) { strength in
                        Text(strength.name).tag(strength)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Toggle("Double pulse", isOn: $state.doublePulse)
                Text("Adds a second pulse 6 ms behind the first. Can feel heavier, "
                     + "but it can also feel like a double tick.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Test") { state.testHaptic() }
                    .controlSize(.small)
            }
            .disabled(!state.hapticsEnabled)
            .opacity(state.hapticsEnabled ? 1 : 0.4)
        }
    }

    // MARK: Feel

    private var feelSection: some View {
        Section(title: "Feel") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Click density").font(.system(size: 11)).foregroundStyle(.secondary)
                Picker("", selection: $state.density) {
                    ForEach(Density.allCases, id: \.self) { density in
                        Text(density.name).tag(density)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("One click every \(Int(state.density.spacing)) points of scrolling.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 2)

            HStack(spacing: 6) {
                Circle()
                    .fill(state.clicksFired > 0 ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("\(state.clicksFired) clicks")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Toggle("Keep clicking through momentum", isOn: $state.clickDuringMomentum)
            Text("Carries on after you lift your fingers and the page coasts.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Gestures

    private var gesturesSection: some View {
        Section(title: "Gestures") {
            Toggle("Click on trackpad gestures", isOn: $state.gesturesEnabled)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Pinch to zoom", isOn: $state.gesturePinch)
                Text("A notch every 5% of zoom, so pinching ratchets instead of "
                     + "gliding. Also covers two-finger double-tap zoom.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Rotate", isOn: $state.gestureRotate)
                Text("A notch every 5 degrees.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Toggle("Three-finger swipe", isOn: $state.gestureSwipe)
                Text("Only works if Swipe between pages uses three fingers in "
                     + "Trackpad settings. macOS keeps Mission Control and "
                     + "full-screen swipes to itself.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Force click", isOn: $state.gestureForceClick)
                Text("Plays your click sound on a deep press. macOS already taps "
                     + "the trackpad here, so Detent adds no second haptic.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(!state.gesturesEnabled)
            .opacity(state.gesturesEnabled ? 1 : 0.4)

            HStack(spacing: 6) {
                Circle()
                    .fill(state.gesturesFired > 0 ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text("\(state.gesturesFired) gesture notches")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
            HStack {
                Toggle("Open at login", isOn: $state.launchAtLogin)
                Spacer()
                Button("Quit Detent") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
    }
}

// MARK: - Pieces

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.6)
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct VoiceChip: View {
    let voice: Voice
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(voice.name).font(.system(size: 11, weight: .medium))
                Text(voice.blurb)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help(voice.blurb)
    }
}
