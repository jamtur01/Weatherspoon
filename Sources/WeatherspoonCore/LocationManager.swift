import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    var currentLocation: CLLocation?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onLocationError: ((Error) -> Void)?
    var isAuthorized = false
    private var locationRetryCount = 0
    private let locationMaxRetries = 5
    private var locationTimeout: Timer?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        
        // Setup timeout timer similar to Hammerspoon spoon
        locationTimeout?.invalidate()
        locationRetryCount = 0
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.locationRetryCount += 1
            
            if self.currentLocation == nil {
                if self.locationRetryCount < self.locationMaxRetries {
                    print("Retrying to fetch location...")
                    self.locationManager.requestLocation()
                } else {
                    print("Max retries reached, using cityName instead")
                    self.locationTimeout?.invalidate()
                    self.onLocationError?(NSError(domain: "com.weatherspoon", code: 0, 
                                                  userInfo: [NSLocalizedDescriptionKey: "Location timeout"]))
                }
            } else {
                self.locationTimeout?.invalidate()
            }
        }
    }    
    func cleanup() {
        locationTimeout?.invalidate()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            currentLocation = location
            onLocationUpdate?(location)
            locationTimeout?.invalidate()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onLocationError?(error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // For macOS 10.15 compatibility, we'll handle this in the older delegate method
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
            locationManager.requestLocation()
        default:
            isAuthorized = false
            onLocationError?(NSError(domain: "com.weatherspoon", code: 0, 
                                     userInfo: [NSLocalizedDescriptionKey: "Location access denied"]))
        }
    }
}