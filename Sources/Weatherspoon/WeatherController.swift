import SwiftUI
import Combine
import CoreLocation

class WeatherController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem
    private let weatherService = WeatherService.shared
    private let locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Menu
    private let menu = NSMenu()
    
    // Data
    @Published private var currentWeather: WeatherData?
    private var cityName = UserDefaults.standard.string(forKey: "WeatherCityName") ?? "Brooklyn USA"
    private var updateInterval: Double = {
        let savedInterval = UserDefaults.standard.double(forKey: "WeatherUpdateInterval")
        return savedInterval > 0 ? savedInterval : 3600 // Default 1 hour
    }()
    
    // Timer
    private var timer: Timer?
    
    init(statusItem: NSStatusItem) {
        print("WeatherController initializing")
        self.statusItem = statusItem
        super.init()
        
        // Ensure the button is configured properly
        if let button = statusItem.button {
            button.title = "⌛ Loading..."
            print("Status button configured")
        } else {
            print("Status button is nil!")
        }
        
        setupStatusItem()
        setupMenu()
        setupLocationManager()
        setupTimer()
        
        // Initial fetch
        print("Performing initial weather fetch")
        fetchWeather()
    }
    
    func cleanup() {
        timer?.invalidate()
        locationManager.cleanup()
    }
    
    private func setupStatusItem() {
        print("Setting up status item")
        if let button = statusItem.button {
            button.title = "⌛ Loading..."
            button.action = #selector(statusItemClicked)
            button.target = self
            print("Status item setup complete")
        } else {
            print("Error: Status item button is nil during setup")
        }
    }
    
    private func setupMenu() {
        // Add initial menu items
        menu.addItem(NSMenuItem(title: "Updating weather...", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Settings submenu
        let settingsMenu = NSMenu()
        
        // City setting
        let cityMenuItem = NSMenuItem(title: "Set City", action: #selector(setCity), keyEquivalent: "c")
        cityMenuItem.target = self
        settingsMenu.addItem(cityMenuItem)        
        // Update interval settings
        let intervals = [("30 minutes", 1800.0), ("1 hour", 3600.0), ("2 hours", 7200.0), ("4 hours", 14400.0)]
        let updateMenu = NSMenu()
        
        for (title, seconds) in intervals {
            let item = NSMenuItem(title: title, action: #selector(setUpdateInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            updateMenu.addItem(item)
        }
        
        let updateMenuItem = NSMenuItem(title: "Update Interval", action: nil, keyEquivalent: "")
        updateMenuItem.submenu = updateMenu
        settingsMenu.addItem(updateMenuItem)
        
        // Manual refresh
        settingsMenu.addItem(NSMenuItem.separator())
        let refreshMenuItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshWeather), keyEquivalent: "r")
        refreshMenuItem.target = self
        settingsMenu.addItem(refreshMenuItem)
        
        // Add settings menu to main menu
        let settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsMenuItem.submenu = settingsMenu
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsMenuItem)
        
        // Add quit option
        menu.addItem(NSMenuItem.separator())
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        // Set menu style for better contrast
        menu.items.forEach { item in
            let title = item.title
            if !title.isEmpty && !item.isSeparatorItem {
                let attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: NSColor.textColor
                ]
                item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
            }
        }
    }    
    private func setupLocationManager() {
        locationManager.onLocationUpdate = { [weak self] location in
            guard let self = self else { return }
            self.fetchWeather()
        }
        
        locationManager.onLocationError = { [weak self] _ in
            guard let self = self else { return }
            // Fall back to city name
            self.fetchWeather()
        }
        
        locationManager.requestLocation()
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
    }
    
    private func fetchWeather() {
        print("Fetching weather...")
        
        if let button = statusItem.button {
            button.title = "⌛ Updating..."
        } else {
            print("Error: Status item button is nil during weather fetch")
        }
        
        weatherService.fetchWeather(location: locationManager.currentLocation, cityName: cityName) { [weak self] result in
            guard let self = self else { return }
            
            print("Weather fetch completed")
            
            DispatchQueue.main.async {
                switch result {
                case .success(let weatherData):
                    print("Weather fetch successful: \(weatherData.weatherDesc)")
                    self.currentWeather = weatherData
                    self.updateMenuBar(with: weatherData)
                    self.updateMenu(with: weatherData)
                case .failure(let error):
                    print("Weather error: \(error.localizedDescription)")
                    
                    if let button = self.statusItem.button {
                        button.title = "⚠️ Error"
                    } else {
                        print("Error: Status item button is nil after weather fetch error")
                    }
                    
                    // Update menu with error
                    self.clearMenuItems()
                    let errorItem = NSMenuItem(title: "Error: \(error.localizedDescription)", action: nil, keyEquivalent: "")
                    let attributes: [NSAttributedString.Key: Any] = [
                        .foregroundColor: NSColor.textColor
                    ]
                    errorItem.attributedTitle = NSAttributedString(string: errorItem.title, attributes: attributes)
                    self.menu.insertItem(errorItem, at: 0)
                }
            }
        }
    }    
    private func updateMenuBar(with weatherData: WeatherData) {
        let weatherEmoji = weatherService.getWeatherEmoji(forCondition: weatherData.weatherDesc)
        statusItem.button?.title = String(format: "%@ %.1f°C", weatherEmoji, weatherData.temperature)
        
        let tempEmoji = weatherService.getTempEmoji(forTemp: weatherData.temperature)
        statusItem.button?.toolTip = String(format: "%@ %@ %.1f°C", weatherData.weatherDesc, tempEmoji, weatherData.temperature)
    }
    
    private func clearMenuItems() {
        // Remove all items except settings and quit
        while menu.items.count > 0 && !menu.items[0].title.contains("Settings") && menu.items[0].title != "Quit" {
            menu.removeItem(at: 0)
        }
    }
    
    private func updateMenu(with weatherData: WeatherData) {
        // Clear existing items
        clearMenuItems()
        
        // Text attributes for better contrast
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.textColor
        ]
        
        // Add header item with current conditions
        let tempEmoji = weatherService.getTempEmoji(forTemp: weatherData.temperature)
        let headerTitle = String(format: "%@ %@ %.1f°C (Feels like %.1f°C) 💦 %d%% ☔ %d%%",
                                weatherData.areaName, tempEmoji, weatherData.temperature,
                                weatherData.feelsLike, weatherData.humidity, weatherData.chanceOfRain)
        
        let headerItem = NSMenuItem(title: headerTitle, action: #selector(openWeatherWebsite), keyEquivalent: "")
        headerItem.target = self
        headerItem.toolTip = "Click to open detailed weather info"
        headerItem.attributedTitle = NSAttributedString(string: headerTitle, attributes: textAttributes)
        menu.insertItem(headerItem, at: 0)
        
        menu.insertItem(NSMenuItem.separator(), at: 1)        
        // Current weather details
        let currentWeatherTitle = "Current Weather: \(weatherData.weatherDesc)"
        let currentWeatherItem = NSMenuItem(title: currentWeatherTitle, action: nil, keyEquivalent: "")
        currentWeatherItem.attributedTitle = NSAttributedString(string: currentWeatherTitle, attributes: textAttributes)
        menu.insertItem(currentWeatherItem, at: 2)
        
        let windTitle = "Wind: \(weatherData.windSpeed) km/h \(weatherData.windDirection)"
        let windItem = NSMenuItem(title: windTitle, action: nil, keyEquivalent: "")
        windItem.attributedTitle = NSAttributedString(string: windTitle, attributes: textAttributes)
        menu.insertItem(windItem, at: 3)
        
        let pressureTitle = "Pressure: \(weatherData.pressure) hPa"
        let pressureItem = NSMenuItem(title: pressureTitle, action: nil, keyEquivalent: "")
        pressureItem.attributedTitle = NSAttributedString(string: pressureTitle, attributes: textAttributes)
        menu.insertItem(pressureItem, at: 4)
        
        let visibilityTitle = "Visibility: \(weatherData.visibility) km"
        let visibilityItem = NSMenuItem(title: visibilityTitle, action: nil, keyEquivalent: "")
        visibilityItem.attributedTitle = NSAttributedString(string: visibilityTitle, attributes: textAttributes)
        menu.insertItem(visibilityItem, at: 5)
        
        menu.insertItem(NSMenuItem.separator(), at: 6)
        
        let forecastTitle = "Forecast:"
        let forecastItem = NSMenuItem(title: forecastTitle, action: nil, keyEquivalent: "")
        forecastItem.attributedTitle = NSAttributedString(string: forecastTitle, attributes: textAttributes)
        menu.insertItem(forecastItem, at: 7)
        
        // Add forecast items
        var index = 8
        for forecast in weatherData.forecasts {
            let maxEmoji = weatherService.getTempEmoji(forTemp: forecast.maxTemp)
            let minEmoji = weatherService.getTempEmoji(forTemp: forecast.minTemp)
            
            let forecastTitle = String(format: "%@: %@ (%@ %.1f°C - %@ %.1f°C)",
                                      forecast.date, forecast.description,
                                      minEmoji, forecast.minTemp, maxEmoji, forecast.maxTemp)
            
            let forecastItem = NSMenuItem(title: forecastTitle, action: nil, keyEquivalent: "")
            forecastItem.attributedTitle = NSAttributedString(string: forecastTitle, attributes: textAttributes)
            menu.insertItem(forecastItem, at: index)
            index += 1
        }        
        // Add separator before Settings (if not already there)
        if index < menu.items.count && !menu.items[index].isSeparatorItem {
            menu.insertItem(NSMenuItem.separator(), at: index)
        }
        
        // Make sure settings and quit menu items have proper contrast
        for i in 0..<menu.items.count {
            let title = menu.items[i].title
            if title == "Settings" || title == "Quit" {
                menu.items[i].attributedTitle = NSAttributedString(string: title, attributes: textAttributes)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func statusItemClicked() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }
    
    @objc private func setCity() {
        let alert = NSAlert()
        alert.messageText = "Set City Name"
        alert.informativeText = "Enter the name of the city for weather information"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = cityName
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            cityName = textField.stringValue
            UserDefaults.standard.set(cityName, forKey: "WeatherCityName")
            fetchWeather()
        }
    }
    
    @objc private func setUpdateInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else { return }
        updateInterval = interval
        UserDefaults.standard.set(updateInterval, forKey: "WeatherUpdateInterval")
        setupTimer()
    }    
    @objc private func refreshWeather() {
        fetchWeather()
    }
    
    @objc private func timerUpdate() {
        fetchWeather()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func openWeatherWebsite() {
        guard let weatherData = currentWeather else { return }
        
        var urlString: String
        
        if weatherData.isUsingLocation, let lat = weatherData.latitude, let lon = weatherData.longitude {
            urlString = "https://wttr.in/\(lat),\(lon)"
        } else if let cityName = weatherData.cityName, !cityName.isEmpty {
            let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString = "https://wttr.in/\(encodedCity)"
        } else {
            return
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
