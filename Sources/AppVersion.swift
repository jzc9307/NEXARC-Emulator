import Foundation

enum AppVersion {
    static var current:String {
        Bundle.main.object(forInfoDictionaryKey:"NEXARCReleaseVersion") as? String
        ?? Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
        ?? "Development"
    }
}
