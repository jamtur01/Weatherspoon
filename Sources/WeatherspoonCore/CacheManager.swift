import Foundation

class CacheManager<T> {
    private let queue = DispatchQueue(label: "com.weatherspoon.cache", attributes: .concurrent)
    private var value: T?
    private var timestamp: Date?
    private let ttl: TimeInterval
    
    init(ttl: TimeInterval = 300) { // 5 minutes default
        self.ttl = ttl
    }
    
    
    func get() -> T? {
        queue.sync {
            guard let timestamp = timestamp,
                  Date().timeIntervalSince(timestamp) < ttl else {
                return nil
            }
            return value
        }
    }
    
    func set(_ newValue: T) {
        queue.sync(flags: .barrier) {
            self.value = newValue
            self.timestamp = Date()
        }
    }
    
    func invalidate() {
        queue.sync(flags: .barrier) {
            self.value = nil
            self.timestamp = nil
        }
    }
}