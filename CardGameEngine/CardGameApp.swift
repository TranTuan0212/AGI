import SwiftUI

@main
struct CardGameApp: App {
    @StateObject private var authManager = AppAuthManager.shared

    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
            } else {
                AppLoginView()
            }
        }
    }
}
