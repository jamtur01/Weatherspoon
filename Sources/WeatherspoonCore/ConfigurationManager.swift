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
    
    @UserDefault(key: "WeatherUpdateInterval", defaultValue: 3600.0, checkExistence: true) // 1 hour default
    var updateInterval: TimeInterval
    
    @UserDefault(key: "WeatherUseLocation", defaultValue: true, checkExistence: true)
    var useLocation: Bool
    
    private init() {}
}