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
    
    // (Optional) Buffer for smoothing—if desired.
    // private var keypointBuffer: [[HandKeypoint]] = []
    // private let bufferSize = 5
    
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
        
        let keypoints = await detectHandPoseAndReturnKeypoints(pixelBuffer: pixelBuffer)
        guard keypoints.count == 21 else {
            print("❌ Not enough keypoints for classification (\(keypoints.count))")
            isProcessingInference = false
            return
        }
        
        do {
            // Use the new buildInputAttribute method (mimicking the sample)
            let inputArray = try buildInputAttribute(from: keypoints)
            let config = MLModelConfiguration()
            let model = try ASLModel(configuration: config)
            let output = try model.prediction(poses: inputArray)
            
            DispatchQueue.main.async {
                let letter = output.label
                print("📝 ASLModel predicted: \(letter)")
                AppModel.shared.immediatePrediction = letter
            }
        } catch {
            print("❌ Error running model: \(error.localizedDescription)")
        }
        
        isProcessingInference = false
    }
    
    /// Build an MLMultiArray using a method similar to the sample.
    /// This method concatenates rows from each recognized point.
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
    func detectHandPoseAndReturnKeypoints(pixelBuffer: CVImageBuffer) async -> [HandKeypoint] {
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([handPoseRequest])
            if let observation = handPoseRequest.results?.first as? VNHumanHandPoseObservation {
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
                for joint in jointNames {
                    if let recognizedPoint = allPoints[joint] {
                        let conf = Float(recognizedPoint.confidence)
                        let nx = Float(1 - recognizedPoint.location.x)
                        // If you flipped y in training, do so here:
                        let ny = Float(1 - recognizedPoint.location.y)
                        kpArray.append(HandKeypoint(x: nx, y: ny, confidence: conf))
                        cgPoints.append(CGPoint(x: CGFloat(nx), y: CGFloat(ny)))
                    } else {
                        kpArray.append(HandKeypoint(x: 0, y: 0, confidence: 0))
                        cgPoints.append(.zero)
                    }
                }
                
                print("Hand Keypoints:", kpArray.map { "(\($0.x), \($0.y))" })
                
                DispatchQueue.main.async {
                    AppModel.shared.handKeypoints = cgPoints
                }
                return kpArray
            }
        } catch {
            print("Error detecting hand pose: \(error)")
        }
        DispatchQueue.main.async {
            AppModel.shared.handKeypoints = []
        }
        return []
    }
    
    /// (Optional) Stub
    func detectHandPose(pixelBuffer: CVImageBuffer) async {
        _ = await detectHandPoseAndReturnKeypoints(pixelBuffer: pixelBuffer)
    }
}
