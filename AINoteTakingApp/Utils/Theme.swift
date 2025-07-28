//
//  Theme.swift
//  AINoteTakingApp
//
//  Created by AI Assistant on 2024-01-01.
//

import SwiftUI

// MARK: - Theme Protocol
protocol ThemeProtocol {
    // Primary Colors
    var primary: Color { get }
    var secondary: Color { get }
    var accent: Color { get }
    var background: Color { get }
    var surface: Color { get }
    
    // Semantic Colors
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var info: Color { get }
    
    // Text Colors
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    
    // Card & Section Colors
    var cardBackground: Color { get }
    var sectionBackground: Color { get }
    var separator: Color { get }
    
    // Category Colors
    var categoryPersonal: Color { get }
    var categoryWork: Color { get }
    var categoryIdeas: Color { get }
    var categoryTasks: Color { get }
    var categoryMeetings: Color { get }
    var categoryResearch: Color { get }
}

// MARK: - Default Light Theme
struct DefaultLightTheme: ThemeProtocol {
    // Primary Colors
    let primary = Color.blue
    let secondary = Color.gray
    let accent = Color.blue
    let background = Color(.systemBackground)
    let surface = Color(.secondarySystemBackground)
    
    // Semantic Colors
    let success = Color.green
    let warning = Color.orange
    let error = Color.red
    let info = Color.blue
    
    // Text Colors
    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textTertiary = Color(.tertiaryLabel)
    
    // Card & Section Colors
    let cardBackground = Color(.systemBackground)
    let sectionBackground = Color(.systemGray6)
    let separator = Color(.separator)
    
    // Category Colors
    let categoryPersonal = Color.green
    let categoryWork = Color.blue
    let categoryIdeas = Color.purple
    let categoryTasks = Color.red
    let categoryMeetings = Color.orange
    let categoryResearch = Color.indigo
}

// MARK: - Professional Blue Theme
struct ProfessionalBlueTheme: ThemeProtocol {
    // Primary Colors
    let primary = Color(hex: "#1E3A8A")  // Deep Blue
    let secondary = Color(hex: "#64748B") // Slate Gray
    let accent = Color(hex: "#3B82F6")   // Bright Blue
    let background = Color(.systemBackground)
    let surface = Color(.secondarySystemBackground)
    
    // Semantic Colors
    let success = Color(hex: "#10B981")  // Emerald
    let warning = Color(hex: "#F59E0B")  // Amber
    let error = Color(hex: "#EF4444")    // Red
    let info = Color(hex: "#3B82F6")     // Blue
    
    // Text Colors
    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textTertiary = Color(.tertiaryLabel)
    
    // Card & Section Colors
    let cardBackground = Color(.systemBackground)
    let sectionBackground = Color(hex: "#F1F5F9") // Light Blue Gray
    let separator = Color(.separator)
    
    // Category Colors
    let categoryPersonal = Color(hex: "#10B981")  // Emerald
    let categoryWork = Color(hex: "#1E3A8A")      // Deep Blue
    let categoryIdeas = Color(hex: "#8B5CF6")     // Violet
    let categoryTasks = Color(hex: "#EF4444")     // Red
    let categoryMeetings = Color(hex: "#F59E0B")  // Amber
    let categoryResearch = Color(hex: "#6366F1")  // Indigo
}

// MARK: - Dark Professional Theme
struct DarkProfessionalTheme: ThemeProtocol {
    // Primary Colors
    let primary = Color(hex: "#60A5FA")  // Light Blue
    let secondary = Color(hex: "#94A3B8") // Light Slate
    let accent = Color(hex: "#3B82F6")   // Blue
    let background = Color(.systemBackground)
    let surface = Color(.secondarySystemBackground)
    
    // Semantic Colors
    let success = Color(hex: "#34D399")  // Light Emerald
    let warning = Color(hex: "#FBBF24")  // Light Amber
    let error = Color(hex: "#F87171")    // Light Red
    let info = Color(hex: "#60A5FA")     // Light Blue
    
    // Text Colors
    let textPrimary = Color.primary
    let textSecondary = Color.secondary
    let textTertiary = Color(.tertiaryLabel)
    
    // Card & Section Colors
    let cardBackground = Color(.systemBackground)
    let sectionBackground = Color(hex: "#1F2937") // Dark Gray
    let separator = Color(.separator)
    
    // Category Colors
    let categoryPersonal = Color(hex: "#34D399")  // Light Emerald
    let categoryWork = Color(hex: "#60A5FA")      // Light Blue
    let categoryIdeas = Color(hex: "#A78BFA")     // Light Violet
    let categoryTasks = Color(hex: "#F87171")     // Light Red
    let categoryMeetings = Color(hex: "#FBBF24")  // Light Amber
    let categoryResearch = Color(hex: "#818CF8")  // Light Indigo
}

// MARK: - Theme Manager
@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: DefaultLightTheme = DefaultLightTheme()
    
    init() {
        // For now, just use the default light theme
        // This can be expanded later to support theme switching
    }
    
    func setLightTheme() {
        currentTheme = DefaultLightTheme()
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Environment Key
private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = DefaultLightTheme()
}

extension EnvironmentValues {
    var theme: DefaultLightTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extension for Theme Access
extension View {
    func themed(_ theme: DefaultLightTheme) -> some View {
        self.environment(\.theme, theme)
    }
}

// MARK: - Theme-Aware Components
struct ThemedCard<Content: View>: View {
    @Environment(\.theme) private var theme
    let content: Content
    let backgroundColor: Color?
    
    init(backgroundColor: Color? = nil, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(backgroundColor ?? theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }
}

struct ThemedSection<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let icon: String
    let color: Color?
    let content: Content
    
    init(title: String, icon: String, color: Color? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color ?? theme.primary)
                    .font(.headline)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(color ?? theme.primary)
                
                Spacer()
            }
            
            content
        }
    }
}

struct ThemedButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    var buttonColor: Color {
        switch style {
        case .primary: return theme.primary
        case .secondary: return theme.secondary
        case .destructive: return theme.error
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(buttonColor)
                .cornerRadius(8)
        }
    }
}

// MARK: - Category Theme Helper
extension Category {
    func themedColor(for theme: DefaultLightTheme) -> Color {
        switch name.lowercased() {
        case "personal":
            return theme.categoryPersonal
        case "work":
            return theme.categoryWork
        case "ideas":
            return theme.categoryIdeas
        case "tasks":
            return theme.categoryTasks
        case "meetings":
            return theme.categoryMeetings
        case "research":
            return theme.categoryResearch
        default:
            return Color(hex: color)
        }
    }
}

// MARK: - Priority Theme Helper
extension Priority {
    func themedColor(for theme: DefaultLightTheme) -> Color {
        switch self {
        case .low:
            return theme.success
        case .medium:
            return theme.warning
        case .high:
            return theme.error
        case .urgent:
            return theme.accent
        }
    }
}

// MARK: - Color String Extension
extension Color {
    init(_ hexString: String) {
        self.init(hex: hexString)
    }
}