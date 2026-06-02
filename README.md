# Foreign Affairs Custom Reader 📰✨

A beautifully crafted, premium native **Multiplatform (macOS, iPadOS, iOS) Application** designed specifically to format, read, and translate articles from *Foreign Affairs* in a clean, distraction-free native editorial view.

Built entirely with **Swift 6, SwiftUI, and Apple Native Platform API integrations**, this app presents a seamless, high-fidelity custom reading experience.

---

## 🎨 Rich Premium Aesthetics

Designed to impress at first glance:
- **Integrated Sidebar**: Structured with a native modern `NavigationSplitView` layout that integrates seamlessly on macOS and iOS, providing clean navigation and responsive list views.
- **System-Adaptive Light & Dark Modes**: High-fidelity typography and color systems that automatically adapt to macOS and iOS appearance preferences, ensuring optimal reading comfort in any lighting environment.
- **Stunning Editorial Typography**: Tailored styling using premium system-serif fonts for article content and clean system sans-serif designs for navigation elements, ensuring comfortable long-form reading.
- **Actionable Micro-Animations**: Fluid hover effects, responsive scales, and smooth transitions on article cards, list scroll areas, and button controls.

---

## 🚀 Core Capabilities & Features

### 1. Curated RSS Feed & Native Elasticsearch Search
- **Curated RSS Listing**: Fetches the latest article catalog directly from the official *Foreign Affairs* RSS feed (`rss.xml`) using a lightweight SAX-based XML Parser, reducing data consumption and loading times to milliseconds.
- **Native Elasticsearch Search**: Triggers direct JSON queries to the native *Foreign Affairs* Elasticsearch search endpoint for high-performance full-index search results when actively searching.
- **High-Speed Native Parsing**: A blazing-fast, fully native HTML parser (`ArticleParser`) uses regular expressions and an optimized tags-offset scanner to extract structural editorial elements (Title, Subtitle, Byline, Date, Issue, Cover Image, and body elements) in under 20 milliseconds, eliminating the overhead of WebViews or JavaScript bridges.
- **Distraction-Free Rendering**: Compiles the extracted content and renders it natively using premium, fully-styled SwiftUI views.

### 2. On-Device Native Translation (Apple ML)
- **Zero Third-Party Dependencies**: Translation is performed completely natively using Apple's secure, on-device machine learning models.
- **Premium Multilingual Interface**: Triggers a native `.translationTask` to translate UI strings, feed headers, and article body elements (paragraphs, subheadings, and blockquotes) recursively while preserving the author's byline in its original language.

### 3. Interactive Reader Style Tuning
- **Dynamic Scale**: Scale text font sizes up or down dynamically (from `0.6x` up to `2.0x`) with immediate UI rendering and proportional line height.
- **System-Adaptive Contrast**:
  - Automatically aligns with system appearance preferences to present clear, high-contrast text in Light mode and soft, eye-friendly text/backgrounds in Dark mode.

---

## 🏛️ Clean Architecture & Separation of Concerns

This project is designed with strong architectural boundaries separating core domain logic from user interface frameworks:
- **UI-Independent Domain Model (`AppModel`)**: Built using `Foundation`, `Observation`, and the native `Translation` API. It contains **zero dependencies on SwiftUI**, making the business logic entirely decoupled, highly portable, and easily testable.
- **Declarative State-Driven Animations**: Transitions and view layout changes (such as auto-fading translation/extraction error banners) are triggered declaratively using SwiftUI's native `.animation(_:value:)` state hooks on the view layer rather than imperative animation logic in the model.

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
