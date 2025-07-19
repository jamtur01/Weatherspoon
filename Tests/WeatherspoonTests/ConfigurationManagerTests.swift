import XCTest
@testable import WeatherspoonCore

class ConfigurationManagerTests: XCTestCase {
    var config: Configuration!
    
    override func setUp() {
        super.setUp()
        config = Configuration.shared
    }
    
    func testDefaultValues() {
        // Clear UserDefaults for testing
        UserDefaults.standard.removeObject(forKey: "WeatherCityName")
        UserDefaults.standard.removeObject(forKey: "WeatherUpdateInterval")
        
        XCTAssertEqual(config.cityName, "Brooklyn, NYC")
        XCTAssertEqual(config.updateInterval, 3600)
    }
    
    func testSettingAndGettingCityName() {
        config.cityName = "New York"
        XCTAssertEqual(config.cityName, "New York")
        
        config.cityName = "San Francisco"
        XCTAssertEqual(config.cityName, "San Francisco")
    }
    
    func testSettingAndGettingUpdateInterval() {
        config.updateInterval = 1800
        XCTAssertEqual(config.updateInterval, 1800)
        
        config.updateInterval = 7200
        XCTAssertEqual(config.updateInterval, 7200)
    }
    
    func testAvailableIntervals() {
        XCTAssertEqual(config.availableIntervals.count, 4)
        XCTAssertEqual(config.availableIntervals[0].title, "30 minutes")
        XCTAssertEqual(config.availableIntervals[0].seconds, 1800)
        XCTAssertEqual(config.availableIntervals[1].title, "1 hour")
        XCTAssertEqual(config.availableIntervals[1].seconds, 3600)
    }
}