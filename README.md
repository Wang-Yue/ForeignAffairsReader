# Foreign Affairs Custom Reader 📰✨

A beautifully crafted, premium native **macOS Desktop Application** designed specifically to format, read, and translate articles from *Foreign Affairs* in a clean, distraction-free editorial view.

Built entirely with **Swift 6, SwiftUI, and Cocoa API integrations**, this app presents a seamless, high-fidelity custom reading experience.

---

## 🎨 Rich Premium Aesthetics

Designed to impress at first glance:
- **Glassmorphism Header**: Implemented using macOS native `NSVisualEffectView` for a gorgeous, semi-transparent blurred toolbar.
- **Golden Sepia & Velvet Dark Modes**: Curated color palettes matching high-end editorial platforms, providing exceptional reading comfort.
- **Stunning Editorial Typography**: Automatically loads premium fonts (*Playfair Display*, *Inter*, *Georgia*) with optimal line height (1.68x) and paragraph margins for reading long-form essays.
- **Actionable Micro-Animations**: Hover effects and gradients on navigation bar controls and segmented theme pickers.

---

## 🚀 Core Capabilities & Features

### 1. Custom Article Formatting & Reader Mode
- **In-Place Layout Optimization**: When navigating the live browser, the app automatically evaluates optimized JS styling rules to clean up promotional overlays, banners, and blocking dialogs.
- **High-Fidelity Reader View**: Selecting the **Reader Mode** tab triggers a native Swift-JS pipeline that:
  1. Extracts structural DOM elements (Title, Subtitle, Author, Date, Cover Image, and article body paragraphs).
  2. Sends them asynchronously to Swift via a secure `WKScriptMessageHandler` bridge.
  3. Instantly compiles a local, clean, distraction-free editorial template, loaded under a simulated domain to preserve relative image paths.

### 2. Native Apple Translation (On-Device ML)
*Instead of relying on third-party web translation scripts, this app integrates Apple's native Translation framework.*
- **Zero Third-Party Dependencies**: Translation is performed completely natively using Apple's secure, on-device machine learning models.
- **Premium Serif Interface integration**: When you select a target language from the dropdown (Spanish, Chinese, French, Japanese, Korean, Russian, Arabic, Portuguese, Italian, German, and more), the system triggers a native `.translationTask` to translate the title, subtitle, and every individual paragraph in sequence, dynamically updating the premium serif reading pane.


### 3. Reader Style Tuning
- **Dynamic Scale**: Scale text font sizes up or down dynamically (from `0.6x` up to `2.0x`) with immediate UI rendering.
- **Three Premium Themes**:
  - `Light`: Clean, paper-white background with high-contrast text.
  - `Sepia` (Default): Warm, cream background with coffee-colored text to protect your eyes.
  - `Dark`: Pitch-black dark mode for comfortable nighttime reading.

---

## 🏗️ Project Structure

The workspace contains the following source files inside `./Sources/`:
- [Package.swift](file:///Users/wangyue/ForeignAffairsReader/Package.swift): Configuration for Swift Package Manager (SPM), enabling direct integration with Xcode, easy dependency management, and clean standard builds.
- [AppModel.swift](file:///Users/wangyue/ForeignAffairsReader/Sources/AppModel.swift): Shared observable application state holding current themes, text sizes, and extracted articles.
- [ReaderView.swift](file:///Users/wangyue/ForeignAffairsReader/Sources/ReaderView.swift): Represents the SwiftUI wrapper rendering the beautiful premium HTML page template and managing translation states.
- [ContentView.swift](file:///Users/wangyue/ForeignAffairsReader/Sources/ContentView.swift): Implements the user interface including sidebar feeding list, search, styling settings bar, and reader pane detail column.
- [AppEntry.swift](file:///Users/wangyue/ForeignAffairsReader/Sources/AppEntry.swift): The programmatic application entry point that spins up our NSWindow, attaches native macOS menus, and hosts the SwiftUI environment (renamed from `main.swift` to conform to Swift Package Manager `@main` standards).
- [WebView.swift](file:///Users/wangyue/ForeignAffairsReader/Sources/WebView.swift): Excluded layout experimental web view.

---

## ⚙️ How to Build and Run

A convenient `Makefile` is provided to manage all build tasks using Swift Package Manager. You can also **open this directory directly in Xcode** to build, run, and debug the application!

- **Build and Launch:**
  ```bash
  make run
  ```
- **Build Only:**
  ```bash
  make build
  ```
- **Clean Build Files:**
  ```bash
  make clean
  ```

---

### 🛠️ Re-compiling from Source & Assets

If you make any modifications to the Swift source files or the master application icon:

1. **To rebuild the application bundle:**
   ```bash
   make clean && make build
   ```
2. **To regenerate the macOS system AppIcon:**
   If you update `icon.png`, compile it into standard multi-resolution `.icns` assets and package it into the bundle by running:
   ```bash
   make icon
   ```

