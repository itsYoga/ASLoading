import SwiftUI

struct PredictionLabelOverlay: View {
    var label: String
    var showIcon: Bool = true
    
    var body: some View {
        HStack {
            if showIcon {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundColor(.white)
            }
            Text(label)
                .foregroundColor(.white)
                .font(.headline)
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
        }
        .padding()
    }
}

struct PredictionLabelOverlay_Previews: PreviewProvider {
    static var previews: some View {
        PredictionLabelOverlay(label: "A")
    }
}
