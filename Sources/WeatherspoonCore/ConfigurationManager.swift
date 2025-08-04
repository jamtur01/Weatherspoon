import Foundation

class Configuration {
    static let shared = Configuration()
    
    // Available update intervals
    let availableIntervals: [(title: String, seconds: TimeInterval)] = [
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200),
        ("4 hours", 14400)
    ]
    
    @UserDefault(key: "WeatherCityName", defaultValue: "Brooklyn, NYC")
    var cityName: String
    
    @UserDefaultDouble(key: "WeatherUpdateInterval", defaultValue: 3600) // 1 hour default
    var updateInterval: TimeInterval
    
    @UserDefaultWithExistenceCheck(key: "WeatherUseLocation", defaultValue: true)
    var useLocation: Bool
    
    private init() {}
}