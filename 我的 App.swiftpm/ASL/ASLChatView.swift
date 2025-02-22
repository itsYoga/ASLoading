import SwiftUI

struct ASLChatView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        ZStack {
            CameraView()
                .environmentObject(appModel)
            
            // Instead of HandPoseOverlayView, use the skeleton overlay
            HandSkeletonOverlayView(points: appModel.handKeypoints)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text("Detected Letter: \(appModel.stablePrediction)")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                    .padding()
                
                Button("Clear") {
                    appModel.immediatePrediction = "..."
                    appModel.stablePrediction = "..."
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .task {
            await appModel.camera.start()
        }
    }
}
