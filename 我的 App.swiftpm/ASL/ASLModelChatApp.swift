import SwiftUI

@main
struct ASLModelChatApp: App {
    @StateObject var appModel = AppModel.shared
    
    var body: some Scene {
        WindowGroup {
            ASLChatView().environmentObject(appModel)
        }
    }
}
