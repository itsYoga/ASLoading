import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let camera = AppModel.shared.camera
        camera.setupPreview(in: viewController.view)
        camera.start()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView().environmentObject(AppModel.shared)
    }
}
