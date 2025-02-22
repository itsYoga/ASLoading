import Foundation
import Combine
import UIKit

final class AppModel: ObservableObject {
    static let shared = AppModel()
    
    // The immediate prediction updated every inference
    @Published var immediatePrediction: String = "..."
    
    // The stable prediction updated only after immediatePrediction remains the same for 3 seconds
    @Published var stablePrediction: String = "..."
    
    // Live camera preview image
    @Published var viewfinderImage: UIImage? = nil
    
    // Hand keypoints for drawing the overlay (normalized points)
    @Published var handKeypoints: [CGPoint] = []
    
    // (New) Track a specific fingertip location (e.g. index tip) in normalized coordinates
    @Published var indexFingerTipLocation: CGPoint? = nil
    
    var camera: MLCamera = MLCamera()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Update stablePrediction only if immediatePrediction is unchanged for 3 seconds.
        $immediatePrediction
            .removeDuplicates()
            .debounce(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] letter in
                if letter != "..." && !letter.isEmpty {
                    self?.stablePrediction = letter
                    print("Stable letter: \(letter)")
                }
            }
            .store(in: &cancellables)
    }
}
