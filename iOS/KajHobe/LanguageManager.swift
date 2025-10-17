import Foundation
import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: Language = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            Foundation.NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        }
    }
    
    enum Language: String, CaseIterable {
        case english = "en"
        case bangla = "bn"
        case german = "de"
        
        var displayName: String {
            switch self {
            case .english:
                return "English"
            case .bangla:
                return "বাংলা"
            case .german:
                return "Deutsch"
            }
        }
        
        var flag: String {
            switch self {
            case .english:
                return "🇺🇸"
            case .bangla:
                return "🇧🇩"
            case .german:
                return "🇩🇪"
            }
        }
    }
    
    private init() {
        // Load saved language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
    
    func localizedString(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle if localized bundle not found
            return NSLocalizedString(key, comment: "")
        }
        
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    func setLanguage(_ language: Language) {
        currentLanguage = language
    }
}

extension NSNotification.Name {
    static let languageChanged = NSNotification.Name("LanguageChanged")
}

// MARK: - Localized String Helper
func LocalizedString(_ key: String) -> String {
    return LanguageManager.shared.localizedString(for: key)
}

// MARK: - SwiftUI String Extension
extension String {
    var localized: String {
        return LanguageManager.shared.localizedString(for: self)
    }
}