import Foundation
import SwiftUI

struct DiagnosticsOverlay: View {
    let snapshot: FrameDiagnosticsSnapshot

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.25))
    }

    private var text: String {
        let cpuText = snapshot.cpuUsagePercent.map { String(format: "CPU %.0f%%", $0) } ?? "CPU n/a"

        guard let thermalText = snapshot.thermalState.diagnosticTitle else {
            return cpuText
        }

        return "\(cpuText) (\(thermalText))"
    }
}

private extension ProcessInfo.ThermalState {
    var diagnosticTitle: String? {
        switch self {
        case .nominal:
            nil
        case .fair:
            "WARM"
        case .serious:
            "HOT"
        case .critical:
            "CRIT"
        @unknown default:
            nil
        }
    }
}
