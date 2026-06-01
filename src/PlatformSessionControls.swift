import Foundation

#if os(iOS)
import AVFoundation
import UIKit
#endif

@MainActor
enum PlatformSessionControls {
    #if os(iOS)
    private static let backgroundAudio = BackgroundAudioKeepalive()
    #endif

    static func setMeditationActive(_ active: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = active

        if active {
            backgroundAudio.start()
        } else {
            backgroundAudio.stop()
        }
        #endif
    }
}

#if os(iOS)
@MainActor
private final class BackgroundAudioKeepalive {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isConfigured = false
    private var isRunning = false

    func start() {
        guard !isRunning else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            guard let format else {
                return
            }

            if !isConfigured {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                isConfigured = true
            }

            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }

            let frameCount: AVAudioFrameCount = 44_100
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return
            }

            buffer.frameLength = frameCount
            if let channel = buffer.floatChannelData?[0] {
                for frame in 0..<Int(frameCount) {
                    let phase = Double(frame) / 44_100 * 2 * Double.pi * 180
                    channel[frame] = Float(sin(phase) * 0.00008)
                }
            }

            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            isRunning = true
        } catch {
            stop()
        }
    }

    func stop() {
        guard isRunning || engine.isRunning else {
            return
        }

        player.stop()
        engine.stop()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
#endif
