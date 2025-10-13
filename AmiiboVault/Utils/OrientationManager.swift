import SwiftUI
import Combine

class OrientationManager: ObservableObject {
    @Published var isLandscape: Bool = UIDevice.current.orientation.isLandscape
    
    private var cancellable: AnyCancellable?
    
    init() {
        // Enable orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { _ in
                DispatchQueue.main.async {
                    self.isLandscape = UIDevice.current.orientation.isLandscape
                }
            }
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        cancellable?.cancel()
    }
}
