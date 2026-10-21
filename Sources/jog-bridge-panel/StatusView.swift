import AppKit
import SwiftUI

extension StatusLevel {
    var color: Color {
        switch self {
        case .ok: .green
        case .attention: .orange
        case .problem: .red
        }
    }

    /// The status is never conveyed by colour alone: each level also has its own symbol.
    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .problem: "xmark.octagon.fill"
        }
    }

    var spokenName: String {
        switch self {
        case .ok: "OK"
        case .attention: "Needs attention"
        case .problem: "Problem"
        }
    }
}

extension CheckRow.Result {
    var color: Color {
        switch self {
        case .ok: .green
        case .warning: .orange
        case .failure: .red
        case .unknown: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failure: "xmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

@MainActor
struct StatusView: View {
    let probe: any BridgeProbing
    let actions: BridgeActions

    @State private var snapshot: BridgeSnapshot?
    @State private var busy = false
    @State private var copied = false

    /// `initialSnapshot` lets previews and tests show a given state without waiting for a probe.
    init(probe: any BridgeProbing, actions: BridgeActions, initialSnapshot: BridgeSnapshot? = nil) {
        self.probe = probe
        self.actions = actions
        _snapshot = State(initialValue: initialSnapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if let snapshot {
                let status = BridgeStatus.evaluate(snapshot)
                statusCard(status)
                checks(status.checks)
                if !status.actions.isEmpty {
                    actionButtons(status.actions)
                }
                details(snapshot: snapshot, status: status)
            } else {
                ProgressView("Checking…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(24)
        .frame(width: 460)
        .task { await refreshForever() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Jog Bridge").font(.title2.bold())
                Text("USB-to-MIDI bridge for the Hercules DJ Control MP3 e2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusCard(_ status: BridgeStatus) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: status.level.symbol)
                .font(.system(size: 34))
                .foregroundStyle(status.level.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title).font(.headline)
                Text(status.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.level.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.level.spokenName). \(status.title). \(status.detail)")
    }

    private func checks(_ rows: [CheckRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.result.symbol)
                        .foregroundStyle(row.result.color)
                        .accessibilityHidden(true)
                    Text(row.title).font(.callout)
                    Spacer()
                    Text(row.value).font(.callout).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func actionButtons(_ list: [BridgeAction]) -> some View {
        HStack {
            ForEach(Array(list.enumerated()), id: \.offset) { index, action in
                if index == 0 {
                    Button(action.title) { run(action) }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(action.title) { run(action) }
                        .buttonStyle(.bordered)
                }
            }
            if busy { ProgressView().controlSize(.small) }
        }
        .disabled(busy)
    }

    private func details(snapshot: BridgeSnapshot, status: BridgeStatus) -> some View {
        DisclosureGroup("Details") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Version \(snapshot.appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Show Log") { actions.showLog() }
                    Button(copied ? "Copied" : "Copy Diagnostics") {
                        let report = BridgeStatus.diagnostics(
                            snapshot: snapshot, status: status,
                            osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
                        actions.copy(report)
                        copied = true
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Behaviour

    private func refreshForever() async {
        while !Task.isCancelled {
            snapshot = await probe.snapshot()
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func run(_ action: BridgeAction) {
        Task {
            busy = true
            switch action {
            case .start: await actions.start()
            case .restart: await actions.restart()
            case .openLoginItems: actions.openLoginItems()
            }
            // Give launchd a moment before looking again.
            try? await Task.sleep(for: .seconds(1))
            snapshot = await probe.snapshot()
            busy = false
        }
    }
}

// MARK: - Previews

/// A probe that always returns the same snapshot, for Xcode previews.
private struct StaticProbe: BridgeProbing {
    let value: BridgeSnapshot
    func snapshot() async -> BridgeSnapshot { value }
}

@MainActor private func previewOf(_ snapshot: BridgeSnapshot) -> some View {
    StatusView(probe: StaticProbe(value: snapshot), actions: BridgeActions(), initialSnapshot: snapshot)
}

private let previewStart = "[20:50:09] Virtual MIDI ports “Hercules MP3 e2” created."
private let previewConnected = "[20:50:09] Console connected — input 0x81 (bulk)"

private let healthy = BridgeSnapshot(
    installed: true, service: ServiceState(loaded: true, running: true, pid: 4242, lastExitCode: nil),
    approval: .approved, midiPortPresent: true, usbDevicePresent: true,
    logTail: previewStart + "\n" + previewConnected, appVersion: "1.0.0")

#Preview("Everything OK") { previewOf(healthy) }

#Preview("Console unplugged") {
    var snapshot = healthy
    snapshot.usbDevicePresent = false
    snapshot.logTail = previewStart + "\n[21:02:11] Waiting for the console…"
    return previewOf(snapshot)
}

#Preview("Service stopped") {
    var snapshot = healthy
    snapshot.service = ServiceState(loaded: true, running: false, pid: nil, lastExitCode: 1)
    return previewOf(snapshot)
}

#Preview("Needs approval") {
    var snapshot = healthy
    snapshot.service = .notLoaded
    snapshot.approval = .requiresApproval
    snapshot.midiPortPresent = false
    return previewOf(snapshot)
}

#Preview("Console held by another app") {
    var snapshot = healthy
    snapshot.logTail = previewStart + "\n[21:03:00] Cannot claim interface 0: LIBUSB_ERROR_ACCESS.\n[21:03:00] Waiting for the console…"
    return previewOf(snapshot)
}
