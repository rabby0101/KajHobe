import SwiftUI

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("select_language".localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("app_language".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Language options
                VStack(spacing: 12) {
                    ForEach(LanguageManager.Language.allCases, id: \.self) { language in
                        LanguageOptionRow(
                            language: language,
                            isSelected: languageManager.currentLanguage == language,
                            onSelect: {
                                selectLanguage(language)
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .alert("language_changed".localized, isPresented: $showingSuccessAlert) {
            Button("ok".localized) {
                dismiss()
            }
        } message: {
            Text("language_change_message".localized)
        }
    }
    
    private func selectLanguage(_ language: LanguageManager.Language) {
        let previousLanguage = languageManager.currentLanguage
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        languageManager.setLanguage(language)
        
        // Show success alert if language actually changed
        if previousLanguage != language {
            showingSuccessAlert = true
        }
    }
}

struct LanguageOptionRow: View {
    let language: LanguageManager.Language
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.title2)
                
                // Language info
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                    
                    Text(language.rawValue.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LanguageSelectionView()
}