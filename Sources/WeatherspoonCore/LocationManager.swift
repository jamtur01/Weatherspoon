import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let queue = DispatchQueue(label: "com.weatherspoon.location")
    
    private var _currentLocation: CLLocation?
    var currentLocation: CLLocation? {
        get { queue.sync { _currentLocation } }
        set { queue.async { self._currentLocation = newValue } }
    }
    
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onLocationError: ((Error) -> Void)?
    
    private var _isAuthorized = false
    var isAuthorized: Bool {
        get { queue.sync { _isAuthorized } }
        set { queue.async { self._isAuthorized = newValue } }
    }
    
    private var locationRetryCount = 0
    private let locationMaxRetries = 3
    private weak var locationTimeout: Timer?
    private var _isMonitoring = false
    private var isMonitoring: Bool {
        get { queue.sync { _isMonitoring } }
        set { queue.async { self._isMonitoring = newValue } }
    }
    private let significantDistanceFilter: CLLocationDistance = 5000 // 5km
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = significantDistanceFilter
    }
    
    func startLocationTracking() {
        locationManager.requestWhenInUseAuthorization()
        
        queue.async { [weak self] in
            guard let self = self else { return }
            if !self._isMonitoring {
                self._isMonitoring = true
                DispatchQueue.main.async {
                    self.locationManager.startUpdatingLocation()
                }
            }
        }
    }
    
    func stopLocationTracking() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self._isMonitoring {
                self._isMonitoring = false
                DispatchQueue.main.async {
                    self.locationManager.stopUpdatingLocation()
                }
                self.clearLocationTimeout()
            }
        }
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        
        // Setup timeout timer for location requests
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.clearLocationTimeoutSyncronously()
            self.locationRetryCount = 0
            
            self.locationTimeout = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.locationRetryCount += 1
                
                if self.currentLocation == nil {
                    if self.locationRetryCount < self.locationMaxRetries {
                        self.locationManager.requestLocation()
                    } else {
                        self.clearLocationTimeoutSyncronously()
                        self.onLocationError?(NSError(domain: "com.weatherspoon", code: 0,
                                                      userInfo: [NSLocalizedDescriptionKey: "Location timeout"]))
                    }
                } else {
                    self.clearLocationTimeoutSyncronously()
                }
            }
        }
    }
    
    func cleanup() {
        stopLocationTracking()
        clearLocationTimeout()
    }
    
    private func clearLocationTimeout() {
        DispatchQueue.main.async { [weak self] in
            self?.locationTimeout?.invalidate()
            self?.locationTimeout = nil
        }
    }
    
    private func clearLocationTimeoutSyncronously() {
        locationTimeout?.invalidate()
        locationTimeout = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            // Only update if the location is reasonably fresh (within last 5 minutes)
            let locationAge = Date().timeIntervalSince(location.timestamp)
            if locationAge < 300 {
                // Check if this is a significant location change
                if let previousLocation = currentLocation {
                    let distance = location.distance(from: previousLocation)
                    // Only update if moved more than the distance filter
                    if distance >= significantDistanceFilter {
                        currentLocation = location
                        onLocationUpdate?(location)
                        clearLocationTimeout()
                    }
                } else {
                    // First location update
                    currentLocation = location
                    onLocationUpdate?(location)
                    clearLocationTimeout()
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
            onLocationError?(NSError(domain: "com.weatherspoon", code: 0,
                                     userInfo: [NSLocalizedDescriptionKey: "Location access denied"]))
        }
    }
}