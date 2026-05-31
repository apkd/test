import SwiftUI
import Testing
@testable import TestApp

@MainActor
struct ContentViewSmokeTests {
    @Test
    func contentViewCanBeConstructed() {
        let view = ContentView()

        _ = view.body
    }
}
