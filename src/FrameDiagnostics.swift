import Foundation
import SwiftUI

#if canImport(Darwin)
import Darwin
#endif

struct FrameDiagnosticsSnapshot: Equatable {
    var framesPerSecond = 0.0
    var frameMilliseconds = 0.0
    var cpuUsagePercent: Double?
    var thermalState = ProcessInfo.ThermalState.nominal
    var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    var targetFramesPerSecond = 30.0
}

@MainActor
final class FrameDiagnosticsSampler: ObservableObject {
    @Published private(set) var snapshot = FrameDiagnosticsSnapshot()

    private var lastFrameDate: Date?
    private var lastPublishDate: Date?
    private var frameCount = 0
    private var frameMillisecondsTotal = 0.0

    func recordFrame(at date: Date) {
        defer {
            lastFrameDate = date
        }

        guard let lastFrameDate else {
            lastPublishDate = date
            return
        }

        let frameMilliseconds = max(0, date.timeIntervalSince(lastFrameDate) * 1_000)
        frameCount += 1
        frameMillisecondsTotal += frameMilliseconds

        let publishElapsed = date.timeIntervalSince(lastPublishDate ?? date)
        guard publishElapsed >= 0.75, frameCount > 0 else {
            return
        }

        snapshot = FrameDiagnosticsSnapshot(
            framesPerSecond: Double(frameCount) / publishElapsed,
            frameMilliseconds: frameMillisecondsTotal / Double(frameCount),
            cpuUsagePercent: ProcessDiagnostics.cpuUsagePercent(),
            thermalState: ProcessInfo.processInfo.thermalState,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            targetFramesPerSecond: 30
        )
        frameCount = 0
        frameMillisecondsTotal = 0
        lastPublishDate = date
    }
}

enum ProcessDiagnostics {
    static func cpuUsagePercent() -> Double? {
        #if canImport(Darwin)
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)

        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threadList else {
            return nil
        }

        defer {
            let byteCount = vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadList)), byteCount)
        }

        var total = 0.0

        for index in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                    thread_info(threadList[index], thread_flavor_t(THREAD_BASIC_INFO), reboundPointer, &count)
                }
            }

            guard result == KERN_SUCCESS, info.flags & TH_FLAGS_IDLE == 0 else {
                continue
            }

            total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
        }

        return total
        #else
        return nil
        #endif
    }
}
