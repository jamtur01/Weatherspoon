import Cocoa
import CoreLocation

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let weatherService = WeatherService.shared
    private let locationManager = LocationManager.shared
    
    private var timer: Timer?
    private var currentLocation: CLLocation?
    
    // Default settings
    private var cityName = UserDefaults.standard.string(forKey: "WeatherCityName") ?? "Brooklyn USA"
    private var updateInterval: Double = {
        let savedInterval = UserDefaults.standard.double(forKey: "WeatherUpdateInterval") 
        return savedInterval > 0 ? savedInterval : 3600 // Default 1 hour if not set or zero
    }()
    
    // Weather data
    private var currentWeatherData: WeatherData?
    private var logger = Logger(subsystem: "com.weatherspoon", category: "weather")
    
    override init() {
        super.init()
        
        setupStatusItem()
        setupMenu()
        setupLocationManager()
        
        // Initial weather fetch
        fetchWeather()
        
        // Setup timer for periodic updates
        setupTimer()
    }
    
    func cleanup() {
        timer?.invalidate()
        locationManager.cleanup()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌛ Loading..."
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
    }    
    private func setupMenu() {
        // Add initial menu items
        menu.addItem(NSMenuItem(title: "Updating weather...", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        // Add settings submenu
        let settingsMenu = NSMenu()
        
        // City name setting
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
            self?.fetchWeather()
        }
        
        locationManager.onLocationError = { [weak self] error in
            print("Location error: \(error.localizedDescription)")
            // If location fails, fall back to city name
            self?.fetchWeather()
        }
        
        // Request location
        locationManager.requestLocation()
    }
    
    private func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(timerUpdate), userInfo: nil, repeats: true)
    }
    
    @objc private func timerUpdate() {
        fetchWeather()
    }
    
    @objc private func refreshWeather() {
        fetchWeather()
    }
    
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
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func fetchWeather() {
        statusItem.button?.title = "⌛ Updating..."
        
        weatherService.fetchWeather(location: currentLocation, cityName: cityName) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let weatherData):
                    self.currentWeatherData = weatherData
                    self.updateMenuBar(with: weatherData)
                    self.updateMenu(with: weatherData)
                case .failure(let error):
                    print("Weather error: \(error.localizedDescription)")
                    self.statusItem.button?.title = "⚠️ Error"
                    
                    // Update menu with error
                    self.clearMenuItems()
                    let errorItem = NSMenuItem(title: "Error: \(error.localizedDescription)", action: nil, keyEquivalent: "")
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
        
        // Current weather details
        menu.insertItem(NSMenuItem(title: "Current Weather: \(weatherData.weatherDesc)", action: nil, keyEquivalent: ""), at: 2)
        menu.insertItem(NSMenuItem(title: "Wind: \(weatherData.windSpeed) km/h \(weatherData.windDirection)", action: nil, keyEquivalent: ""), at: 3)
        menu.insertItem(NSMenuItem(title: "Pressure: \(weatherData.pressure) hPa", action: nil, keyEquivalent: ""), at: 4)
        menu.insertItem(NSMenuItem(title: "Visibility: \(weatherData.visibility) km", action: nil, keyEquivalent: ""), at: 5)
        
        menu.insertItem(NSMenuItem.separator(), at: 6)
        menu.insertItem(NSMenuItem(title: "Forecast:", action: nil, keyEquivalent: ""), at: 7)        
        // Add forecast items
        var index = 8
        for forecast in weatherData.forecasts {
            let maxEmoji = weatherService.getTempEmoji(forTemp: forecast.maxTemp)
            let minEmoji = weatherService.getTempEmoji(forTemp: forecast.minTemp)
            
            let forecastTitle = String(format: "%@: %@ (%@ %.1f°C - %@ %.1f°C)",
                                      forecast.date, forecast.description,
                                      minEmoji, forecast.minTemp, maxEmoji, forecast.maxTemp)
            
            menu.insertItem(NSMenuItem(title: forecastTitle, action: nil, keyEquivalent: ""), at: index)
            index += 1
        }
        
        // Add separator before Settings (if not already there)
        if index < menu.items.count && !menu.items[index].isSeparatorItem {
            menu.insertItem(NSMenuItem.separator(), at: index)
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

class Logger {
    let subsystem: String
    let category: String
    
    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }
    
    func info(_ message: String) {
        print("[\(category)] INFO: \(message)")
    }
    
    func error(_ message: String) {
        print("[\(category)] ERROR: \(message)")
    }
}