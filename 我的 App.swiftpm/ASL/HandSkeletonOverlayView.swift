import SwiftUI

struct HandSkeletonOverlayView: View {
    let points: [CGPoint]
    
    private let skeleton: [(Int, Int)] = [
        (0,1), (1,2), (2,3), (3,4),     // Thumb
        (0,5), (5,6), (6,7), (7,8),     // Index
        (0,9), (9,10), (10,11), (11,12), // Middle
        (0,13), (13,14), (14,15), (15,16), // Ring
        (0,17), (17,18), (18,19), (19,20)  // Little
    ]
    
    // ✅ 手勢偏移量：可以調整這兩個數值來校正骨架位置
    private let offsetX: CGFloat = 300
    private let offsetY: CGFloat = -50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1) 畫骨架線條
                Path { path in
                    for (startIndex, endIndex) in skeleton {
                        guard startIndex < points.count, endIndex < points.count else { continue }
                        
                        let start = CGPoint(
                            x: points[startIndex].x * geometry.size.width + offsetX,
                            y: points[startIndex].y * geometry.size.height + offsetY
                        )
                        let end = CGPoint(
                            x: points[endIndex].x * geometry.size.width + offsetX,
                            y: points[endIndex].y * geometry.size.height + offsetY
                        )
                        
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                }
                .stroke(Color.orange, lineWidth: 2)
                
                // 2) 畫關節點（圓點）
                ForEach(points.indices, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .position(
                            x: points[i].x * geometry.size.width + offsetX,
                            y: points[i].y * geometry.size.height + offsetY
                        )
                }
            }
        }
    }
}

struct HandSkeletonOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        HandSkeletonOverlayView(points: Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 21))
            .background(Color.black.opacity(0.5))
    }
}
