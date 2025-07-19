import XCTest
@testable import WeatherspoonCore

class WeatherServiceTests: XCTestCase {
    var weatherService: WeatherService!
    
    override func setUp() {
        super.setUp()
        weatherService = WeatherService.shared
    }
    
    func testGetWeatherEmojiForConditions() {
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Clear"), "☀️")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Partly cloudy"), "⛅")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Cloudy"), "☁️")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Overcast"), "🌥️")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Mist"), "🌫")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Light rain"), "🌧")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Heavy rain"), "🌧💧")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Light snow"), "❄️")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Heavy snow"), "❄️❄️")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Blizzard"), "❄️🌪")
        XCTAssertEqual(weatherService.getWeatherEmoji(forCondition: "Unknown condition"), "🌡️")
    }
    
    func testGetTempEmojiForTemperatures() {
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: -15), "🌡️") // Below threshold, uses default
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: -10), "⛄")
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: -5), "⛄")
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: 0), "❄️")
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: 5), "☁️")
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: 15), "🌤️")
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: 25), "🌞")
        XCTAssertEqual(weatherService.getTempEmoji(forTemp: 35), "🔥")
    }
    
    func testFetchWeatherWithInvalidCity() {
        let expectation = XCTestExpectation(description: "Weather fetch should complete")
        
        weatherService.fetchWeather(location: nil, cityName: "") { result in
            switch result {
            case .success(_):
                XCTFail("Should have failed with empty city name")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}