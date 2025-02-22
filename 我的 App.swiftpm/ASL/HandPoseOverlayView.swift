import SwiftUI

struct HandPoseOverlayView: View {
    var keypoints: [CGPoint]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<keypoints.count, id: \.self) { index in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(
                            x: keypoints[index].x * geometry.size.width,
                            y: keypoints[index].y * geometry.size.height
                        )
                }
            }
        }
    }
}

struct HandPoseOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        HandPoseOverlayView(keypoints: [
            CGPoint(x: 0.2, y: 0.8),
            CGPoint(x: 0.3, y: 0.7),
            CGPoint(x: 0.4, y: 0.6)
        ])
        .background(Color.black.opacity(0.5))
    }
}
