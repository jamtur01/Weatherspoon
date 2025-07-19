import Foundation

class Configuration {
    static let shared = Configuration()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys
    private let cityNameKey = "WeatherCityName"
    private let updateIntervalKey = "WeatherUpdateInterval"
    private let useLocationKey = "WeatherUseLocation"
    
    // Default values
    private let defaultCityName = "Brooklyn, NYC"
    private let defaultUpdateInterval: TimeInterval = 3600 // 1 hour
    
    // Available update intervals
    let availableIntervals: [(title: String, seconds: TimeInterval)] = [
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("4 hours", 14400)
    ]
    
    var cityName: String {
        get {
            userDefaults.string(forKey: cityNameKey) ?? defaultCityName
        }
        set {
            userDefaults.set(newValue, forKey: cityNameKey)
        }
    }
    
    var updateInterval: TimeInterval {
        get {
            let interval = userDefaults.double(forKey: updateIntervalKey)
            return interval > 0 ? interval : defaultUpdateInterval
        }
        set {
            userDefaults.set(newValue, forKey: updateIntervalKey)
        }
    }
    
    var useLocation: Bool {
        get {
            // Default to true so location is used by default
            // If the key doesn't exist (first run), return true
            if userDefaults.object(forKey: useLocationKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: useLocationKey)
        }
        set {
            userDefaults.set(newValue, forKey: useLocationKey)
        }
    }
    
    private init() {}
}