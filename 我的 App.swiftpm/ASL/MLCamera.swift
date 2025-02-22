import Vision
import CoreML
import os.log

struct HandKeypoint {
    let x: Float
    let y: Float
    let confidence: Float
}

class MLCamera: Camera {
    var aslModel: VNCoreMLModel?
    private let logger = Logger(subsystem: "com.example.ASLModelChat", category: "MLCamera")
    
    // Throttle inference: run only once per second.
    private var lastInferenceTime: Date = Date.distantPast
    private let inferenceInterval: TimeInterval = 1.0  // 1 second
    private var isProcessingInference = false
    
    override init() {
        super.init()
        loadASLModel()
    }
    
    func loadASLModel() {
        do {
            let config = MLModelConfiguration()
            let model = try ASLModel(configuration: config)
            aslModel = try VNCoreMLModel(for: model.model)
            logger.debug("✅ ASL ML model loaded successfully")
        } catch {
            logger.error("❌ Unable to load ASL ML model: \(error.localizedDescription)")
        }
    }
    
    /// Main method called for each camera frame; throttles processing.
    func gatherObservations(pixelBuffer: CVImageBuffer) async {
        if isProcessingInference { return }
        let now = Date()
        guard now.timeIntervalSince(lastInferenceTime) >= inferenceInterval else { return }
        lastInferenceTime = now
        isProcessingInference = true
        
        // 1) Detect keypoints from Vision
        let keypoints = await detectHandPoseAndReturnKeypoints(pixelBuffer: pixelBuffer)
        guard keypoints.count == 21 else {
            print("❌ Not enough keypoints for classification (\(keypoints.count))")
            isProcessingInference = false
            return
        }
        
        // 2) If we have a valid ML model, run classification
        guard let model = try? ASLModel(configuration: MLModelConfiguration()) else {
            print("❌ ASL model not loaded.")
            isProcessingInference = false
            return
        }
        
        do {
            let inputArray = try buildInputAttribute(from: keypoints)
            let output = try model.prediction(poses: inputArray)
            
            // 3) (New) Confidence check from labelProbabilities
            let labelProbabilities = output.labelProbabilities
            let label = output.label
            let confidence = labelProbabilities[label] ?? 0.0
            
            // For example, only update immediatePrediction if above 0.9
            if confidence > 0.9 {
                DispatchQueue.main.async {
                    AppModel.shared.immediatePrediction = label
                    print("📝 ASLModel predicted: \(label) (confidence=\(confidence))")
                }
            } else {
                // You could choose to do nothing or set immediatePrediction to "..."
                // if confidence is below threshold.
                DispatchQueue.main.async {
                    AppModel.shared.immediatePrediction = "..."
                }
            }
            
        } catch {
            print("❌ Error running model: \(error.localizedDescription)")
        }
        
        isProcessingInference = false
    }
    
    /// Build an MLMultiArray using a method similar to the sample.
    private func buildInputAttribute(from keypoints: [HandKeypoint]) throws -> MLMultiArray {
        // We expect a shape of [1, 3, 21]
        let mlArray = try MLMultiArray(shape: [1, 3, 21], dataType: .float32)
        var attributeArray: [Float] = []
        
        // The expected order of joints.
        // (Make sure this order exactly matches your training.)
        for kp in keypoints {
            attributeArray.append(kp.x)
            attributeArray.append(kp.y)
            attributeArray.append(kp.confidence)
        }
        // Now copy the values into mlArray.
        let count = attributeArray.count
        let pointer = mlArray.dataPointer.bindMemory(to: Float.self, capacity: count)
        for i in 0..<count {
            pointer[i] = attributeArray[i]
        }
        return mlArray
    }
    
    /// Use Vision to detect hand pose keypoints and return an array of 21 HandKeypoint.
    /// Also sets AppModel.shared.indexFingerTipLocation if found with sufficient confidence.
    func detectHandPoseAndReturnKeypoints(pixelBuffer: CVImageBuffer) async -> [HandKeypoint] {
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([handPoseRequest])
            if let observation = handPoseRequest.results?.first {
                
                // 1) Gather recognized points
                let allPoints = try observation.recognizedPoints(.all)
                let jointNames: [VNHumanHandPoseObservation.JointName] = [
                    .wrist,
                    .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                    .indexMCP, .indexPIP, .indexDIP, .indexTip,
                    .middleMCP, .middlePIP, .middleDIP, .middleTip,
                    .ringMCP, .ringPIP, .ringDIP, .ringTip,
                    .littleMCP, .littlePIP, .littleDIP, .littleTip
                ]
                
                var kpArray: [HandKeypoint] = []
                var cgPoints: [CGPoint] = []
                
                // 2) Convert recognized points to your HandKeypoint array
                for joint in jointNames {
                    if let recognizedPoint = allPoints[joint] {
                        let conf = Float(recognizedPoint.confidence)
                        // If you flipped x or y in training, do so here:
                        let nx = Float(1 - recognizedPoint.location.x)
                        let ny = Float(1 - recognizedPoint.location.y)
                        kpArray.append(HandKeypoint(x: nx, y: ny, confidence: conf))
                        cgPoints.append(CGPoint(x: CGFloat(nx), y: CGFloat(ny)))
                    } else {
                        kpArray.append(HandKeypoint(x: 0, y: 0, confidence: 0))
                        cgPoints.append(.zero)
                    }
                }
                
                // 3) (New) Extract the index finger tip location with confidence threshold
                let landmarkConfidenceThreshold: Float = 0.2
                if let indexTip = allPoints[.indexTip], indexTip.confidence > landmarkConfidenceThreshold {
                    // Convert to same coordinate system as above
                    let tipX = CGFloat(1 - indexTip.location.x)
                    let tipY = CGFloat(1 - indexTip.location.y)
                    DispatchQueue.main.async {
                        AppModel.shared.indexFingerTipLocation = CGPoint(x: tipX, y: tipY)
                    }
                } else {
                    DispatchQueue.main.async {
                        AppModel.shared.indexFingerTipLocation = nil
                    }
                }
                
                // 4) Update the SwiftUI overlay with all the hand keypoints
                DispatchQueue.main.async {
                    AppModel.shared.handKeypoints = cgPoints
                }
                
                return kpArray
            }
        } catch {
            print("Error detecting hand pose: \(error)")
        }
        
        // If no hand or an error occurred:
        DispatchQueue.main.async {
            AppModel.shared.handKeypoints = []
            AppModel.shared.indexFingerTipLocation = nil
        }
        return []
    }
}
