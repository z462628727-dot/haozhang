import SwiftUI

@main
@MainActor
struct XingliApp: App {
    @StateObject private var companion = CompanionModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CompanionView(model: companion)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { phase in
                    companion.save()
                    if phase == .active { companion.updateFocus() }
                }
        }
    }
}
