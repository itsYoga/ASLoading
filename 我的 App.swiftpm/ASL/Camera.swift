import AVFoundation
import UIKit
import os.log

class Camera: NSObject {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "camera session queue")
    
    var isRunning: Bool {
        captureSession.isRunning
    }
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        // Use the front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            print("❌ Unable to find camera device")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self,
                                                queue: DispatchQueue(label: "video output queue", qos: .userInteractive))
            
            captureSession.beginConfiguration()
            if captureSession.canAddInput(input) { captureSession.addInput(input) }
            if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
            captureSession.commitConfiguration()
        } catch {
            print("❌ Camera configuration error: \(error)")
        }
    }
    
    func start() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func setupPreview(in view: UIView) {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        view.layer.addSublayer(previewLayer!)
    }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        DispatchQueue.main.async {
            if let uiImage = ciImage.toUIImage() {
                AppModel.shared.viewfinderImage = uiImage
            }
        }
        
        if let mlCamera = self as? MLCamera {
            Task {
                await mlCamera.gatherObservations(pixelBuffer: pixelBuffer)
            }
        }
    }
}

extension CIImage {
    func toUIImage() -> UIImage? {
        let context = CIContext()
        if let cgImage = context.createCGImage(self, from: self.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
