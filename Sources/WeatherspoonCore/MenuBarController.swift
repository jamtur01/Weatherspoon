import Cocoa
import CoreLocation

public class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let weatherService = WeatherService.shared
    private let locationManager = LocationManager.shared
    private let logger = Logger(subsystem: "net.kartar.weatherspoon", category: "weather")
    private let config = Configuration.shared
    
    private var timer: Timer?
    private var currentLocation: CLLocation?
    
    // Weather data cache
    private var currentWeatherData: WeatherData?
    private var lastFetchTime: Date?
    
    public override init() {
        super.init()
        
        setupStatusItem()
        setupMenu()
        setupLocationManager()
        
        // Initial weather fetch
        fetchWeather()
        
        // Setup timer for periodic updates
        setupTimer()
    }
    
    public func cleanup() {
        timer?.invalidate()
        locationManager.cleanup()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌛ Loading..."
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
    }
    
    @objc private func dummyAction() {
        // Do nothing - this is just to make menu items appear active
    }
    
    private func setupMenu() {
        // Add initial menu items
        let updatingItem = NSMenuItem(title: "Updating weather...", action: #selector(dummyAction), keyEquivalent: "")
        updatingItem.target = self
        menu.addItem(updatingItem)
        menu.addItem(NSMenuItem.separator())        
        // Add settings submenu
        let settingsMenu = NSMenu()
        
        // Location toggle
        let useLocationItem = NSMenuItem(title: "Use Current Location", action: #selector(toggleUseLocation), keyEquivalent: "l")
        useLocationItem.target = self
        useLocationItem.state = config.useLocation ? .on : .off
        settingsMenu.addItem(useLocationItem)
        
        // City name setting
        let cityMenuItem = NSMenuItem(title: "Set City", action: #selector(setCity), keyEquivalent: "c")
        cityMenuItem.target = self
        settingsMenu.addItem(cityMenuItem)
        
        // Update interval settings
        let updateMenu = NSMenu()
        
        for (title, seconds) in config.availableIntervals {
            let item = NSMenuItem(title: title, action: #selector(setUpdateInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            // Add checkmark to currently selected interval
            if seconds == config.updateInterval {
                item.state = .on
            }
            updateMenu.addItem(item)
        }
        
        let updateMenuItem = NSMenuItem(title: "Update Interval", action: nil, keyEquivalent: "")
        updateMenuItem.submenu = updateMenu
        settingsMenu.addItem(updateMenuItem)
        
        // Manual refresh option
        settingsMenu.addItem(NSMenuItem.separator())
        let refreshMenuItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshWeather), keyEquivalent: "r")
        refreshMenuItem.target = self
        settingsMenu.addItem(refreshMenuItem)
        
        // Add settings menu to main menu
        let settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsMenuItem.submenu = settingsMenu
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsMenuItem)
        
        // Add Quit option
        menu.addItem(NSMenuItem.separator())
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
    }    
    private func setupLocationManager() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.currentLocation = location
            self?.logger.info("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            // Clear cache to force using new location
            self?.lastFetchTime = nil
            self?.currentWeatherData = nil
            // Only fetch weather if we're using location
            if self?.config.useLocation == true {
                self?.fetchWeather()
            }
        }
        
        locationManager.onLocationError = { [weak self] error in
            self?.logger.error("Location error: \(error.localizedDescription)")
            // If location fails, fall back to city name
            self?.fetchWeather()
        }
        
        // Request location if enabled (default is true)
        if config.useLocation {
            logger.info("Starting location tracking (useLocation: true)")
            // Check if we already have a location from the shared instance
            if let existingLocation = locationManager.currentLocation {
                currentLocation = existingLocation
                logger.info("Using existing location: \(existingLocation.coordinate.latitude), \(existingLocation.coordinate.longitude)")
            }
            locationManager.startLocationTracking()
        } else {
            logger.info("Not tracking location (useLocation: false)")
            locationManager.stopLocationTracking()
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: config.updateInterval, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
    }
    
    @objc private func timerUpdate() {
        logger.info("Timer triggered weather update (interval: \(config.updateInterval) seconds)")
        fetchWeather()
    }
    
    @objc private func refreshWeather() {
        logger.info("Manual refresh requested")
        
        // Clear cache to force fresh data
        lastFetchTime = nil
        currentWeatherData = nil
        
        // If using location, fetch weather with current location
        if config.useLocation {
            logger.info("Refresh requested with location enabled")
            if let location = locationManager.currentLocation {
                currentLocation = location
                fetchWeather()
            } else {
                // Request location if we don't have one
                locationManager.requestLocation()
            }
        } else {
            // If using city name, fetch weather immediately
            logger.info("Refresh requested with city name: \(config.cityName)")
            fetchWeather()
        }
    }
    
    @objc private func statusItemClicked() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }
    
    @objc private func toggleUseLocation() {
        config.useLocation.toggle()
        
        // Update menu checkmark
        if let settingsMenuItem = menu.items.first(where: { $0.title == "Settings" }),
           let settingsMenu = settingsMenuItem.submenu,
           let locationItem = settingsMenu.items.first(where: { $0.title == "Use Current Location" }) {
            locationItem.state = config.useLocation ? .on : .off
        }
        
        // Clear cached data to force refresh
        currentWeatherData = nil
        lastFetchTime = nil
        
        // Start or stop location tracking based on setting
        if config.useLocation {
            logger.info("Location enabled, starting location tracking")
            locationManager.startLocationTracking()
        } else {
            // Stop tracking and clear current location if disabled
            logger.info("Location disabled, using city name: \(config.cityName)")
            locationManager.stopLocationTracking()
            currentLocation = nil
        }
        
        // Refresh weather with new setting
        fetchWeather()
    }
    
    @objc private func setCity() {
        let alert = NSAlert()
        alert.messageText = "Set City Name"
        alert.informativeText = "Enter the name of the city for weather information (e.g., 'Brooklyn, NYC' or 'London, UK')"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = config.cityName
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            config.cityName = textField.stringValue
            logger.info("City name changed to: \(textField.stringValue)")
            
            // Clear cache to force fresh data
            lastFetchTime = nil
            currentWeatherData = nil
            
            // Refresh weather with new city
            fetchWeather()
        }
    }    
    @objc private func setUpdateInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? Double else { return }
        config.updateInterval = interval
        
        // Update checkmarks in menu
        if let updateMenuItem = menu.items.first(where: { $0.title == "Settings" }),
           let settingsMenu = updateMenuItem.submenu,
           let intervalMenuItem = settingsMenu.items.first(where: { $0.title == "Update Interval" }),
           let updateMenu = intervalMenuItem.submenu {
            
            for item in updateMenu.items {
                item.state = (item.representedObject as? Double == interval) ? .on : .off
            }
        }
        
        setupTimer()
        logger.info("Weather update interval changed to \(interval) seconds")
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func fetchWeather() {
        // Check if we have cached data that's still fresh (within 5 minutes)
        if let lastFetch = lastFetchTime, 
           let weatherData = currentWeatherData,
           Date().timeIntervalSince(lastFetch) < 300 { // 5 minutes
            logger.debug("Using cached weather data")
            updateMenuBar(with: weatherData)
            updateMenu(with: weatherData)
            return
        }
        
        statusItem.button?.title = "⌛ Updating..."
        
        // Use location only if enabled AND we have a location, otherwise use city name
        let locationToUse = (config.useLocation && currentLocation != nil) ? currentLocation : nil
        
        // Log what we're using
        if config.useLocation {
            if let loc = currentLocation {
                logger.info("Using location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            } else {
                logger.warning("Location enabled but no location available yet, using city: \(config.cityName)")
            }
        } else {
            logger.info("Using city name: \(config.cityName)")
        }
        
        weatherService.fetchWeather(location: locationToUse, cityName: config.cityName) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let weatherData):
                    self.currentWeatherData = weatherData
                    self.lastFetchTime = Date()
                    self.updateMenuBar(with: weatherData)
                    self.updateMenu(with: weatherData)
                    self.logger.info("Weather updated successfully")
                case .failure(let error):
                    self.logger.error("Weather fetch failed: \(error.localizedDescription)")
                    self.statusItem.button?.title = "⚠️ Error"
                    
                    // Update menu with error
                    self.clearMenuItems()
                    let errorItem = NSMenuItem(title: "Error: \(error.localizedDescription)", action: #selector(self.dummyAction), keyEquivalent: "")
                    errorItem.target = self
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
        while menu.items.count > 0 && !menu.items[0].title.hasPrefix("Settings") && menu.items[0].title != "Quit" {
            menu.removeItem(at: 0)
        }
    }
    
    private func updateMenu(with weatherData: WeatherData) {
        // Clear existing weather menu items
        clearMenuItems()
        
        // Add header item with current conditions
        let tempEmoji = weatherService.getTempEmoji(forTemp: weatherData.temperature)
        let headerTitle = String(format: "%@ %@ %.1f°C (Feels like %.1f°C) 💦 %d%% ☔ %d%%",
                                weatherData.areaName, tempEmoji, weatherData.temperature,
                                weatherData.feelsLike, weatherData.humidity, weatherData.chanceOfRain)
        
        let headerItem = NSMenuItem(title: headerTitle, action: #selector(openWeatherWebsite), keyEquivalent: "")
        headerItem.target = self
        headerItem.toolTip = "Click to open detailed weather info"
        menu.insertItem(headerItem, at: 0)
        
        menu.insertItem(NSMenuItem.separator(), at: 1)
        
        // Current weather details - add dummy action to make text appear active
        let currentWeatherTitle = "Current Weather: \(weatherData.weatherDesc)"
        let currentWeatherItem = NSMenuItem(title: currentWeatherTitle, action: #selector(dummyAction), keyEquivalent: "")
        currentWeatherItem.target = self
        menu.insertItem(currentWeatherItem, at: 2)
        
        let windTitle = "Wind: \(weatherData.windSpeed) km/h \(weatherData.windDirection)"
        let windItem = NSMenuItem(title: windTitle, action: #selector(dummyAction), keyEquivalent: "")
        windItem.target = self
        menu.insertItem(windItem, at: 3)        
        let pressureTitle = "Pressure: \(weatherData.pressure) hPa"
        let pressureItem = NSMenuItem(title: pressureTitle, action: #selector(dummyAction), keyEquivalent: "")
        pressureItem.target = self
        menu.insertItem(pressureItem, at: 4)
        
        let visibilityTitle = "Visibility: \(weatherData.visibility) km"
        let visibilityItem = NSMenuItem(title: visibilityTitle, action: #selector(dummyAction), keyEquivalent: "")
        visibilityItem.target = self
        menu.insertItem(visibilityItem, at: 5)
        
        menu.insertItem(NSMenuItem.separator(), at: 6)
        
        let forecastTitle = "Forecast:"
        let forecastItem = NSMenuItem(title: forecastTitle, action: #selector(dummyAction), keyEquivalent: "")
        forecastItem.target = self
        menu.insertItem(forecastItem, at: 7)
        
        // Add forecast items
        var index = 8
        for forecast in weatherData.forecasts {
            let maxEmoji = weatherService.getTempEmoji(forTemp: forecast.maxTemp)
            let minEmoji = weatherService.getTempEmoji(forTemp: forecast.minTemp)
            
            // Format the date for display
            let dateTitle: String
            if let formattedDate = formatForecastDate(forecast.date) {
                dateTitle = formattedDate
            } else {
                dateTitle = forecast.date
            }
            
            let forecastTitle = String(format: "%@: %@ (%@ %.1f°C - %@ %.1f°C)",
                                     dateTitle, forecast.description,
                                     minEmoji, forecast.minTemp, maxEmoji, forecast.maxTemp)
            
            let forecastItem = NSMenuItem(title: forecastTitle, action: #selector(dummyAction), keyEquivalent: "")
            forecastItem.target = self
            menu.insertItem(forecastItem, at: index)
            index += 1
        }
        
        // Add location/city info
        menu.insertItem(NSMenuItem.separator(), at: index)
        index += 1
        
        let locationInfoTitle: String
        if weatherData.isUsingLocation, let lat = weatherData.latitude, let lon = weatherData.longitude {
            locationInfoTitle = String(format: "📍 Using location: %.2f, %.2f", lat, lon)
        } else if let cityName = weatherData.cityName {
            locationInfoTitle = "🏙️ Using city: \(cityName)"
        } else {
            locationInfoTitle = "❓ Location unknown"
        }
        
        let locationInfoItem = NSMenuItem(title: locationInfoTitle, action: #selector(dummyAction), keyEquivalent: "")
        locationInfoItem.target = self
        menu.insertItem(locationInfoItem, at: index)
        index += 1        
        // Add separator before Settings (if not already there)
        if index < menu.items.count && !menu.items[index].isSeparatorItem {
            menu.insertItem(NSMenuItem.separator(), at: index)
        }
    }
    
    // MARK: - Helper methods
    
    private func formatForecastDate(_ dateString: String) -> String? {
        // Parse the date string in format yyyy-MM-dd
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = inputFormatter.date(from: dateString) else {
            return nil
        }
        
        // Get today's and tomorrow's dates for comparison
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
        
        // Compare the date to today, tomorrow, and day after tomorrow
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        } else if calendar.isDate(date, inSameDayAs: dayAfterTomorrow) {
            return "Day after tomorrow"
        } else {
            // For other dates, format as "yyyy-MM-dd (Day)"
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd (EEEE)"
            return dayFormatter.string(from: date)
        }
    }
    
    @objc private func openWeatherWebsite() {
        guard let weatherData = currentWeatherData else { return }
        
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