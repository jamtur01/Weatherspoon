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
    private var isMonitoring = false
    private let significantDistanceFilter: CLLocationDistance = 1000 // 1km
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = significantDistanceFilter
    }
    
    func startLocationTracking() {
        locationManager.requestWhenInUseAuthorization()
        
        if !isMonitoring {
            isMonitoring = true
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopLocationTracking() {
        if isMonitoring {
            isMonitoring = false
            locationManager.stopUpdatingLocation()
            locationTimeout?.invalidate()
        }
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
                    self.onLocationError?(NSError(domain: "net.kartar.weatherspoon", code: 0, 
                                                  userInfo: [NSLocalizedDescriptionKey: "Location timeout"]))
                }
            } else {
                self.locationTimeout?.invalidate()
            }
        }
    }    
    func cleanup() {
        stopLocationTracking()
        locationTimeout?.invalidate()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            // Only update if the location is reasonably fresh (within last 5 minutes)
            let locationAge = Date().timeIntervalSince(location.timestamp)
            if locationAge < 300 { // 5 minutes
                // Check if this is a significant location change
                if let previousLocation = currentLocation {
                    let distance = location.distance(from: previousLocation)
                    // Only update if moved more than the distance filter
                    if distance >= significantDistanceFilter {
                        currentLocation = location
                        onLocationUpdate?(location)
                        locationTimeout?.invalidate()
                    }
                } else {
                    // First location update
                    currentLocation = location
                    onLocationUpdate?(location)
                    locationTimeout?.invalidate()
                }
            } else if !isMonitoring {
                // Request a fresh location if the cached one is too old and we're not monitoring
                locationManager.requestLocation()
            }
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
            if isMonitoring {
                locationManager.startUpdatingLocation()
            } else {
                locationManager.requestLocation()
            }
        default:
            isAuthorized = false
            stopLocationTracking()
            onLocationError?(NSError(domain: "net.kartar.weatherspoon", code: 0, 
                                     userInfo: [NSLocalizedDescriptionKey: "Location access denied"]))
        }
    }
}