import SwiftUI
import Testing
@testable import TestApp

@MainActor
struct ContentViewSmokeTests {
    @Test
    func contentViewCanBeInitialized() {
        _ = ContentView()
    }
}
