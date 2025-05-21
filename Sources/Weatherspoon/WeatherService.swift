import Foundation
import CoreLocation

class WeatherService {
    static let shared = WeatherService()
    
    private let urlSession = URLSession.shared
    private let baseURL = "https://wttr.in"
    
    // Weather emojis mapping
    let weatherEmojis: [String: String] = [
        "Clear": "☀️",
        "Sunny": "🌞",
        "Partly cloudy": "⛅",
        "Cloudy": "☁️",
        "Overcast": "🌥️",
        "Mist": "🌫",
        "Patchy rain possible": "🌦️",
        "Patchy snow possible": "🌨️",
        "Patchy sleet possible": "🌧️",
        "Patchy freezing drizzle possible": "🌧",
        "Thundery outbreaks possible": "⛈️",
        "Blowing snow": "🌬️❄️",
        "Blizzard": "❄️🌪",
        "Fog": "🌁",
        "Freezing fog": "❄️🌫️",
        "Patchy light drizzle": "🌦️",
        "Light drizzle": "🌧",
        "Freezing drizzle": "❄️🌧",
        "Heavy freezing drizzle": "🌧❄️",
        "Patchy light rain": "🌦️",
        "Light rain": "🌧",
        "Moderate rain at times": "🌦️🌧",
        "Moderate rain": "🌧",
        "Heavy rain at times": "🌧🌩",
        "Heavy rain": "🌧💧",
        "Light freezing rain": "❄️🌧",
        "Moderate or heavy freezing rain": "❄️🌧💧",
        "Light sleet": "🌧❄️",
        "Moderate or heavy sleet": "🌧❄️🌨",
        "Patchy light snow": "🌨",
        "Light snow": "❄️",
        "Patchy moderate snow": "🌨❄️",
        "Moderate snow": "❄️🌨",
        "Patchy heavy snow": "🌨❄️💨",
        "Heavy snow": "❄️❄️",
        "Ice pellets": "🧊",
        "Light rain shower": "🌦️",
        "Moderate or heavy rain shower": "🌧⛈️",
        "Torrential rain shower": "🌧🌊",
        "Light sleet showers": "🌨️❄️",
        "Moderate or heavy sleet showers": "🌧❄️🌨",
        "Light snow showers": "🌨❄️",
        "Moderate or heavy snow showers": "❄️🌨💨",
        "Patchy light rain with thunder": "🌦️⛈",
        "Moderate or heavy rain with thunder": "🌧⛈️",
        "Patchy light snow with thunder": "❄️⚡",
        "Moderate or heavy snow with thunder": "❄️🌨⚡"
    ]    
    // Temperature emojis with thresholds in Celsius
    struct TempThreshold {
        let threshold: Double
        let emoji: String
    }
    
    let tempThresholds: [TempThreshold] = [
        TempThreshold(threshold: 35, emoji: "🔥"),    // Very hot
        TempThreshold(threshold: 25, emoji: "🌞"),    // Hot
        TempThreshold(threshold: 15, emoji: "🌤️"),   // Warm
        TempThreshold(threshold: 5,  emoji: "☁️"),   // Cool
        TempThreshold(threshold: 0,  emoji: "❄️"),   // Cold
        TempThreshold(threshold: -10, emoji: "⛄")    // Very cold
    ]
    
    let defaultTempEmoji = "🌡️"
    let defaultWeatherEmoji = "🌡️"
    
    func getTempEmoji(forTemp temp: Double) -> String {
        for threshold in tempThresholds {
            if temp >= threshold.threshold {
                return threshold.emoji
            }
        }
        return defaultTempEmoji
    }
    
    func getWeatherEmoji(forCondition condition: String) -> String {
        return weatherEmojis[condition] ?? defaultWeatherEmoji
    }
    
    func fetchWeather(location: CLLocation?, cityName: String?, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        var urlString: String
        var isUsingLocation = false
        
        if let location = location {
            let latitude = String(format: "%.2f", location.coordinate.latitude)
            let longitude = String(format: "%.2f", location.coordinate.longitude)
            urlString = "\(baseURL)/\(latitude),\(longitude)?format=j1"
            isUsingLocation = true
        } else if let cityName = cityName, !cityName.isEmpty {
            guard let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                completion(.failure(NSError(domain: "com.weatherspoon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid city name"])))
                return
            }
            urlString = "\(baseURL)/\(encodedCity)?format=j1"
        } else {
            completion(.failure(NSError(domain: "com.weatherspoon", code: 2, userInfo: [NSLocalizedDescriptionKey: "No location or city provided"])))
            return
        }        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.weatherspoon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("curl/7.64.1", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "com.weatherspoon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "com.weatherspoon", code: 5, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let weatherResponse = try decoder.decode(WeatherResponse.self, from: data)
                
                // Parse the weather data into our model
                guard let currentCondition = weatherResponse.currentCondition.first,
                      let weatherDesc = currentCondition.weatherDesc.first?.value,
                      let tempC = Double(currentCondition.tempC),
                      let feelsLike = Double(currentCondition.feelsLikeC),
                      let humidity = Int(currentCondition.humidity),
                      let areaName = weatherResponse.nearestArea.first?.areaName.first?.value else {
                    completion(.failure(NSError(domain: "com.weatherspoon", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid weather data"])))
                    return
                }
                
                let chanceOfRain = Int(currentCondition.chanceOfRain ?? "0") ?? 0
                
                var forecasts: [Forecast] = []
                
                // Get current date in YYYY-MM-DD format
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let currentDateStr = dateFormatter.string(from: Date())
                
                // Get up to 3 days of forecast, filtering out past dates
                for forecastDay in weatherResponse.weather.prefix(3) {
                    guard let maxTemp = Double(forecastDay.maxtempC),
                          let minTemp = Double(forecastDay.mintempC) else {
                        continue
                    }
                    
                    // Skip dates earlier than today
                    if forecastDay.date < currentDateStr {
                        continue
                    }
                    
                    // Get afternoon forecast (index 4 corresponds to afternoon)
                    let desc = forecastDay.hourly.count >= 4 ? 
                        forecastDay.hourly[4].weatherDesc.first?.value ?? "Unknown" : "Unknown"
                    
                    let forecast = Forecast(
                        date: forecastDay.date,
                        maxTemp: maxTemp,
                        minTemp: minTemp,
                        description: desc
                    )
                    
                    forecasts.append(forecast)
                }
                
                let weatherData = WeatherData(
                    temperature: tempC,
                    feelsLike: feelsLike,
                    humidity: humidity,
                    chanceOfRain: chanceOfRain,
                    weatherDesc: weatherDesc,
                    areaName: areaName,
                    windSpeed: currentCondition.windspeedKmph,
                    windDirection: currentCondition.winddir16Point,
                    pressure: currentCondition.pressure,
                    visibility: currentCondition.visibility,
                    forecasts: forecasts,
                    isUsingLocation: isUsingLocation,
                    latitude: isUsingLocation ? location?.coordinate.latitude : nil,
                    longitude: isUsingLocation ? location?.coordinate.longitude : nil,
                    cityName: isUsingLocation ? nil : cityName
                )
                
                completion(.success(weatherData))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}