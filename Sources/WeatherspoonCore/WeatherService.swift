import Foundation
import CoreLocation

class WeatherService {
    static let shared = WeatherService()
    
    private let urlSession: URLSession
    private let baseURL = "https://wttr.in"
    private var currentTask: URLSessionDataTask?
    
    // Simple weather emoji mappings
    private let weatherEmojis: [String: String] = [
        "Clear": "☀️", "Sunny": "🌞", "Partly cloudy": "⛅", "Cloudy": "☁️",
        "Overcast": "🌥️", "Mist": "🌫", "Fog": "🌁", "Light rain": "🌧",
        "Moderate rain": "🌧", "Heavy rain": "🌧💧", "Light snow": "❄️",
        "Moderate snow": "❄️🌨", "Heavy snow": "❄️❄️", "Blizzard": "❄️🌪", "Thunderstorm": "⛈️"
    ]
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)
    }
    
    func getTempEmoji(forTemp temp: Double) -> String {
        switch temp {
        case 35...: return "🔥"
        case 25..<35: return "🌞"
        case 15..<25: return "🌤️"
        case 5..<15: return "☁️"
        case 0..<5: return "❄️"
        default: return "⛄"
        }
    }
    
    func getWeatherEmoji(forCondition condition: String) -> String {
        // First try exact match
        if let emoji = weatherEmojis[condition] {
            return emoji
        }
        
        // Then try partial match with longer strings first to avoid incorrect matches
        let sortedKeys = weatherEmojis.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if condition.localizedCaseInsensitiveContains(key) {
                return weatherEmojis[key]!
            }
        }
        
        return "🌡️"
    }
    
    private func buildWeatherURL(location: CLLocation?, cityName: String?) -> Result<(URL, Bool), Error> {
        var isUsingLocation = false
        let urlString: String
        
        if let location = location {
            let lat = String(format: "%.4f", location.coordinate.latitude)
            let lon = String(format: "%.4f", location.coordinate.longitude)
            urlString = "\(baseURL)/\(lat),\(lon)?format=j1"
            isUsingLocation = true
        } else if let cityName = cityName, !cityName.isEmpty,
                  let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString = "\(baseURL)/\(encodedCity)?format=j1"
        } else {
            return .failure(NetworkError.noLocationOrCity)
        }
        
        guard let url = URL(string: urlString) else {
            return .failure(NetworkError.invalidURL)
        }
        
        return .success((url, isUsingLocation))
    }
    
    private func handleLocationFallback(isUsingLocation: Bool, cityName: String?, completion: @escaping (Result<WeatherData, Error>) -> Void, fallbackError: Error) {
        // If location failed and we have a city name, retry with city
        if isUsingLocation && cityName != nil {
            self.fetchWeather(location: nil, cityName: cityName, completion: completion)
        } else {
            completion(.failure(fallbackError))
        }
    }
    
    func fetchWeather(location: CLLocation?, cityName: String?, completion: @escaping (Result<WeatherData, Error>) -> Void) {
        // Cancel any existing request
        currentTask?.cancel()
        
        // Build URL
        let urlResult = buildWeatherURL(location: location, cityName: cityName)
        let (url, isUsingLocation): (URL, Bool)
        
        switch urlResult {
        case .success(let result):
            (url, isUsingLocation) = result
        case .failure(let error):
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("curl/7.64.1", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        currentTask = urlSession.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled {
                    return // Request was cancelled, don't report error
                }
                self.handleLocationFallback(isUsingLocation: isUsingLocation, cityName: cityName, completion: completion, fallbackError: NetworkError.networkError(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                self.handleLocationFallback(isUsingLocation: isUsingLocation, cityName: cityName, completion: completion, fallbackError: NetworkError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0))
                return
            }
            
            // Check if response is an error message
            if let responseString = String(data: data, encoding: .utf8),
               (responseString.lowercased().contains("unknown location") || !responseString.starts(with: "{")) {
                self.handleLocationFallback(isUsingLocation: isUsingLocation, cityName: cityName, completion: completion, fallbackError: NetworkError.invalidWeatherData)
                return
            }
            
            do {
                let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
                
                guard let currentCondition = weatherResponse.currentCondition.first,
                      let weatherDesc = currentCondition.weatherDesc.first?.value,
                      let tempC = Double(currentCondition.tempC),
                      let feelsLike = Double(currentCondition.feelsLikeC),
                      let humidity = Int(currentCondition.humidity),
                      let areaName = weatherResponse.nearestArea.first?.areaName.first?.value else {
                    completion(.failure(NetworkError.invalidWeatherData))
                    return
                }
                
                let chanceOfRain = Int(currentCondition.chanceOfRain ?? "0") ?? 0
                
                // Get forecasts
                var forecasts: [Forecast] = []
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let today = dateFormatter.string(from: Date())
                
                for forecastDay in weatherResponse.weather.prefix(3) {
                    guard forecastDay.date >= today,
                          let maxTemp = Double(forecastDay.maxtempC),
                          let minTemp = Double(forecastDay.mintempC) else {
                        continue
                    }
                    
                    let desc = forecastDay.hourly.count > 4 ?
                        forecastDay.hourly[4].weatherDesc.first?.value ?? "Unknown" : "Unknown"
                    
                    forecasts.append(Forecast(
                        date: forecastDay.date,
                        maxTemp: maxTemp,
                        minTemp: minTemp,
                        description: desc
                    ))
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
                completion(.failure(NetworkError.decodingError(error)))
            }
        }
        
        currentTask?.resume()
    }
}