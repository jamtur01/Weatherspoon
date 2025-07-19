import Foundation

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
    
    func debug(_ message: String) {
        #if DEBUG
        print("[\(category)] DEBUG: \(message)")
        #endif
    }
    
    func warning(_ message: String) {
        print("[\(category)] WARNING: \(message)")
    }
}