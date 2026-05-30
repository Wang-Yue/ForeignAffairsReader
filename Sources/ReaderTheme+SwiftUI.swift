import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (1, 1, 1, 0)
    }

    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

extension ReaderTheme {
  // Window background color (used for detail view and main areas)
  var backgroundColor: Color {
    switch self {
    case .light:
      return Color(hex: "#ffffff")
    case .sepia:
      return Color(hex: "#fdfbf7")
    case .dark:
      return Color(hex: "#141414")
    }
  }

  // Sidebar background
  var sidebarBackgroundColor: Color {
    switch self {
    case .light:
      return Color(hex: "#f6f6f6")
    case .sepia:
      return Color(hex: "#f4ecd8")
    case .dark:
      return Color(hex: "#1c1c1c")
    }
  }

  // Primary text color
  var primaryTextColor: Color {
    switch self {
    case .light:
      return Color(hex: "#111111")
    case .sepia:
      return Color(hex: "#5c4033")
    case .dark:
      return Color(hex: "#e0e0e0")
    }
  }

  // Secondary / subtitle / byline text color
  var secondaryTextColor: Color {
    switch self {
    case .light:
      return Color(hex: "#555555")
    case .sepia:
      return Color(hex: "#705335")
    case .dark:
      return Color(hex: "#a0a0a0")
    }
  }

  // Brand/Accent highlights (matching the reader views)
  var accentColor: Color {
    switch self {
    case .light:
      return Color(hex: "#9e2a2b")
    case .sepia:
      return Color(hex: "#8b0000")
    case .dark:
      return Color(hex: "#ff7b7b")
    }
  }

  // Border, divider and separator lines
  var borderColor: Color {
    switch self {
    case .light:
      return Color(hex: "#eaeaea")
    case .sepia:
      return Color(hex: "#e4d9c4")
    case .dark:
      return Color(hex: "#2a2a2a")
    }
  }

  // Visual control background overlays (search inputs, segment selections)
  var controlBackgroundColor: Color {
    switch self {
    case .light:
      return Color(hex: "#ffffff")
    case .sepia:
      return Color(hex: "#ebdcb9")
    case .dark:
      return Color(hex: "#262626")
    }
  }

  // Visual card overlays on hover or selection
  func cardBackgroundColor(isSelected: Bool, isHovered: Bool) -> Color {
    if isSelected {
      return accentColor.opacity(self == .dark ? 0.18 : 0.12)
    } else if isHovered {
      return primaryTextColor.opacity(0.06)
    } else {
      return Color.clear
    }
  }
}
