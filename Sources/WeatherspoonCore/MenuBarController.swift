import Cocoa
import CoreLocation

public class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    
    // Direct dependencies - no DI
    private let weatherService = WeatherService.shared
    private let locationManager = LocationManager.shared
    private let config = Configuration.shared
    
    private var timer: Timer?
    private var currentLocation: CLLocation?
    
    // Weather data cache
    private let weatherCache = CacheManager<WeatherData>(ttl: 300) // 5 minutes
    
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
    
    private func createDummyMenuItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(dummyAction), keyEquivalent: "")
        item.target = self
        return item
    }
    
    private func insertDummyMenuItem(_ title: String, at index: Int) {
        menu.insertItem(createDummyMenuItem(title: title), at: index)
    }
    
    private func setupMenu() {
        // Add initial menu items
        menu.addItem(createDummyMenuItem(title: "Updating weather..."))
        menu.addItem(NSMenuItem.separator())
        
        setupSettingsMenu()
        setupQuitOption()
    }
    
    private func setupSettingsMenu() {
        let settingsMenu = NSMenu()
        
        setupLocationSettings(in: settingsMenu)
        setupUpdateIntervalMenu(in: settingsMenu)
        setupRefreshOption(in: settingsMenu)
        
        // Add settings menu to main menu
        let settingsMenuItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsMenuItem.submenu = settingsMenu
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsMenuItem)
    }
    
    private func setupLocationSettings(in settingsMenu: NSMenu) {
        // Location toggle
        let useLocationItem = NSMenuItem(title: "Use Current Location", action: #selector(toggleUseLocation), keyEquivalent: "l")
        useLocationItem.target = self
        useLocationItem.state = config.useLocation ? .on : .off
        settingsMenu.addItem(useLocationItem)
        
        // City name setting
        let cityMenuItem = NSMenuItem(title: "Set City", action: #selector(setCity), keyEquivalent: "c")
        cityMenuItem.target = self
        settingsMenu.addItem(cityMenuItem)
    }
    
    private func setupUpdateIntervalMenu(in settingsMenu: NSMenu) {
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
    }
    
    private func setupRefreshOption(in settingsMenu: NSMenu) {
        settingsMenu.addItem(NSMenuItem.separator())
        let refreshMenuItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshWeather), keyEquivalent: "r")
        refreshMenuItem.target = self
        settingsMenu.addItem(refreshMenuItem)
    }
    
    private func setupQuitOption() {
        menu.addItem(NSMenuItem.separator())
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
    }
    
    private func setupLocationManager() {
        locationManager.onLocationUpdate = { [weak self] location in
            self?.currentLocation = location
            // Clear cache to force using new location
            self?.weatherCache.invalidate()
            // Only fetch weather if we're using location
            if self?.config.useLocation == true {
                self?.fetchWeather()
            }
        }
        
        locationManager.onLocationError = { [weak self] error in
            // If location fails, fall back to city name
            self?.fetchWeather()
        }
        
        // Request location if enabled (default is true)
        if config.useLocation {
            // Check if we already have a location from the shared instance
            if let existingLocation = locationManager.currentLocation {
                currentLocation = existingLocation
            }
            locationManager.startLocationTracking()
        } else {
            locationManager.stopLocationTracking()
        }
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: config.updateInterval, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
    }
    
    @objc private func timerUpdate() {
        fetchWeather()
    }
    
    @objc private func refreshWeather() {
        // Clear cache to force fresh data
        weatherCache.invalidate()
        
        // If using location, fetch weather with current location
        if config.useLocation {
            if let location = locationManager.currentLocation {
                currentLocation = location
                fetchWeather()
            } else {
                // Request location if we don't have one
                locationManager.requestLocation()
            }
        } else {
            // If using city name, fetch weather immediately
            fetchWeather()
        }
    }
    
    @objc private func statusItemClicked() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }
    
    @objc private func toggleUseLocation() {
        config.useLocation = !config.useLocation
        
        // Update menu checkmark
        if let settingsMenuItem = menu.items.first(where: { $0.title == "Settings" }),
           let settingsMenu = settingsMenuItem.submenu,
           let locationItem = settingsMenu.items.first(where: { $0.title == "Use Current Location" }) {
            locationItem.state = config.useLocation ? .on : .off
        }
        
        // Clear cached data to force refresh
        weatherCache.invalidate()
        
        // Start or stop location tracking based on setting
        if config.useLocation {
            locationManager.startLocationTracking()
        } else {
            // Stop tracking and clear current location if disabled
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
            
            // Clear cache to force fresh data
            weatherCache.invalidate()
            
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
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func fetchWeather() {
        // Check if we have cached data that's still fresh
        if let weatherData = weatherCache.get() {
            updateMenuBar(with: weatherData)
            updateMenu(with: weatherData)
            return
        }
        
        statusItem.button?.title = "⌛ Updating..."
        
        // Use location only if enabled AND we have a location, otherwise use city name
        let locationToUse = (config.useLocation && currentLocation != nil) ? currentLocation : nil
        
        weatherService.fetchWeather(location: locationToUse, cityName: config.cityName) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let weatherData):
                    self.weatherCache.set(weatherData)
                    self.updateMenuBar(with: weatherData)
                    self.updateMenu(with: weatherData)
                case .failure(let error):
                    self.statusItem.button?.title = "⚠️ Error"
                    
                    // Update menu with error
                    self.clearMenuItems()
                    self.insertDummyMenuItem("Error: \(error.localizedDescription)", at: 0)
                    
                    // Add retry option
                    self.menu.insertItem(NSMenuItem.separator(), at: 1)
                    let retryItem = NSMenuItem(title: "Retry", action: #selector(self.refreshWeather), keyEquivalent: "")
                    retryItem.target = self
                    self.menu.insertItem(retryItem, at: 2)
                    self.menu.insertItem(NSMenuItem.separator(), at: 3)
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
        // Find the first separator before Settings
        var indexToRemoveTo = -1
        for (index, item) in menu.items.enumerated() {
            if item.title == "Settings" && index > 0 && menu.items[index-1].isSeparatorItem {
                indexToRemoveTo = index - 1
                break
            }
        }
        
        // Remove all items before the separator
        if indexToRemoveTo > 0 {
            for _ in 0..<indexToRemoveTo {
                menu.removeItem(at: 0)
            }
        }
    }
    
    private func updateMenu(with weatherData: WeatherData) {
        // Clear existing weather menu items
        clearMenuItems()
        
        var index = 0
        
        // Add header
        index = addHeaderMenuItem(weatherData: weatherData, at: index)
        menu.insertItem(NSMenuItem.separator(), at: index)
        index += 1
        
        // Add current weather details
        index = addCurrentWeatherMenuItems(weatherData: weatherData, startingAt: index)
        menu.insertItem(NSMenuItem.separator(), at: index)
        index += 1
        
        // Add forecast
        index = addForecastMenuItems(weatherData: weatherData, startingAt: index)
        
        // Add location info
        menu.insertItem(NSMenuItem.separator(), at: index)
        index += 1
        index = addLocationInfoMenuItem(weatherData: weatherData, at: index)
        
        // Add separator before Settings (if not already there)
        if index < menu.items.count && !menu.items[index].isSeparatorItem {
            menu.insertItem(NSMenuItem.separator(), at: index)
        }
    }
    
    private func addHeaderMenuItem(weatherData: WeatherData, at index: Int) -> Int {
        let tempEmoji = weatherService.getTempEmoji(forTemp: weatherData.temperature)
        let headerTitle = String(format: "%@ %@ %.1f°C (Feels like %.1f°C) 💦 %d%% ☔ %d%%",
                                weatherData.areaName, tempEmoji, weatherData.temperature,
                                weatherData.feelsLike, weatherData.humidity, weatherData.chanceOfRain)
        
        let headerItem = NSMenuItem(title: headerTitle, action: #selector(openWeatherWebsite), keyEquivalent: "")
        headerItem.target = self
        headerItem.toolTip = "Click to open detailed weather info"
        menu.insertItem(headerItem, at: index)
        return index + 1
    }
    
    private func addCurrentWeatherMenuItems(weatherData: WeatherData, startingAt index: Int) -> Int {
        var currentIndex = index
        
        // Current weather description
        let currentWeatherTitle = "Current Weather: \(weatherData.weatherDesc)"
        insertDummyMenuItem(currentWeatherTitle, at: currentIndex)
        currentIndex += 1
        
        // Wind
        let windTitle = "Wind: \(weatherData.windSpeed) km/h \(weatherData.windDirection)"
        insertDummyMenuItem(windTitle, at: currentIndex)
        currentIndex += 1
        
        // Pressure
        let pressureTitle = "Pressure: \(weatherData.pressure) hPa"
        insertDummyMenuItem(pressureTitle, at: currentIndex)
        currentIndex += 1
        
        // Visibility
        let visibilityTitle = "Visibility: \(weatherData.visibility) km"
        insertDummyMenuItem(visibilityTitle, at: currentIndex)
        currentIndex += 1
        
        return currentIndex
    }
    
    private func addForecastMenuItems(weatherData: WeatherData, startingAt index: Int) -> Int {
        var currentIndex = index
        
        // Forecast header
        let forecastTitle = "Forecast:"
        insertDummyMenuItem(forecastTitle, at: currentIndex)
        currentIndex += 1
        
        // Add each forecast day
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
            
            insertDummyMenuItem(forecastTitle, at: currentIndex)
            currentIndex += 1
        }
        
        return currentIndex
    }
    
    private func addLocationInfoMenuItem(weatherData: WeatherData, at index: Int) -> Int {
        let locationInfoTitle: String
        if weatherData.isUsingLocation, let lat = weatherData.latitude, let lon = weatherData.longitude {
            locationInfoTitle = String(format: "📍 Using location: %.2f, %.2f", lat, lon)
        } else if let cityName = weatherData.cityName {
            locationInfoTitle = "🏙️ Using city: \(cityName)"
        } else {
            locationInfoTitle = "❓ Location unknown"
        }
        
        insertDummyMenuItem(locationInfoTitle, at: index)
        return index + 1
    }
    
    // MARK: - Helper methods
    
    private func formatForecastDate(_ dateString: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        if calendar.isDate(date, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "EEEE" // Just show day name
            return formatter.string(from: date)
        }
    }
    
    @objc private func openWeatherWebsite() {
        guard let weatherData = weatherCache.get() else { return }
        
        var urlString: String
        
        if weatherData.isUsingLocation, let lat = weatherData.latitude, let lon = weatherData.longitude {
            urlString = "https://wttr.in/\(lat),\(lon)"
        } else if let cityName = weatherData.cityName, !cityName.isEmpty {
            guard let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                // Handle encoding error silently
                return
            }
            urlString = "https://wttr.in/\(encodedCity)"
        } else {
            return
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}