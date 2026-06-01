import Foundation

#if os(iOS)
import UIKit
#endif

@MainActor
enum PlatformSessionControls {
    static func setMeditationActive(_ active: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = active
        #endif
    }
}
