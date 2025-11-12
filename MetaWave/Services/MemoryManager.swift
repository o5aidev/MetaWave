import Foundation

final class MemoryManager {
    static let shared = MemoryManager()
    private init() {}
    
    func performMemoryCleanup() {
        URLCache.shared.removeAllCachedResponses()
    }
}
