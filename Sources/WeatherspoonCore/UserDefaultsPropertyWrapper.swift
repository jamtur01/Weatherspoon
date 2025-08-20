import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults
    let checkExistence: Bool
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard, checkExistence: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
        self.checkExistence = checkExistence
    }
    
    var wrappedValue: T {
        get {
            // If checkExistence is true and key doesn't exist, return default value
            if checkExistence && userDefaults.object(forKey: key) == nil {
                return defaultValue
            }
            
            // Handle different types appropriately
            if T.self == Bool.self && checkExistence {
                return userDefaults.bool(forKey: key) as! T
            } else if T.self == Double.self && checkExistence {
                return userDefaults.double(forKey: key) as! T
            } else {
                return userDefaults.object(forKey: key) as? T ?? defaultValue
            }
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

// Type aliases for convenience and backward compatibility
typealias UserDefaultWithExistenceCheck = UserDefault<Bool>
typealias UserDefaultDouble = UserDefault<Double>