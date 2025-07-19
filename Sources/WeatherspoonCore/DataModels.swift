// Helper structs for our app
struct WeatherData {
    let temperature: Double
    let feelsLike: Double
    let humidity: Int
    let chanceOfRain: Int
    let weatherDesc: String
    let areaName: String
    let windSpeed: String
    let windDirection: String
    let pressure: String
    let visibility: String
    let forecasts: [Forecast]
    let isUsingLocation: Bool
    let latitude: Double?
    let longitude: Double?
    let cityName: String?
}

struct Forecast {
    let date: String
    let maxTemp: Double
    let minTemp: Double
    let description: String
}