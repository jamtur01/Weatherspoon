import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T {
        get {
            return userDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct UserDefaultWithExistenceCheck {
    let key: String
    let defaultValue: Bool
    let userDefaults: UserDefaults
    
    init(key: String, defaultValue: Bool, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: Bool {
        get {
            // If the key doesn't exist (first run), return default value
            if userDefaults.object(forKey: key) == nil {
                return defaultValue
            }
            return userDefaults.bool(forKey: key)
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct UserDefaultDouble {
    let key: String
    let defaultValue: Double
    let userDefaults: UserDefaults
    
    init(key: String, defaultValue: Double, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: Double {
        get {
            // Check if the key exists
            if userDefaults.object(forKey: key) == nil {
                return defaultValue
            }
            return userDefaults.double(forKey: key)
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}