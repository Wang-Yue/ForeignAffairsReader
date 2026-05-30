import SwiftUI
import Translation

struct ContentView: View {
    @StateObject var model = AppModel()
    @State private var urlText: String = "https://www.foreignaffairs.com"
    
    var body: some View {
        VStack(spacing: 0) {
            // Elegant glassmorphic Toolbar
            HStack(spacing: 15) {
                // Navigation Controls
                HStack(spacing: 8) {
                    Button(action: { model.triggerBack = true }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button(action: { model.triggerForward = true }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    
                    Button(action: { model.triggerReload = true }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Address/Search Bar
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    TextField("URL", text: $urlText, onCommit: {
                        var correctedUrl = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !correctedUrl.lowercased().hasPrefix("http://") && !correctedUrl.lowercased().hasPrefix("https://") {
                            correctedUrl = "https://" + correctedUrl
                        }
                        model.urlString = correctedUrl
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                
                // Tab Picker (Browser vs Reader Mode)
                Picker("", selection: $model.currentTab) {
                    ForEach(ActiveTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            
            Divider()
            
            // Main Area
            ZStack {
                // Tab 1: Live Browser
                WebView(model: model)
                    .opacity(model.currentTab == .browser ? 1 : 0)
                
                // Tab 2: Reader view with full article and controls
                VStack(spacing: 0) {
                    // Reader Controls Bar
                    HStack(spacing: 15) {
                        // Theme Picker
                        HStack(spacing: 6) {
                            Text("Theme:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $model.readerTheme) {
                                ForEach(ReaderTheme.allCases) { theme in
                                    Text(theme.rawValue).tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                        
                        Spacer()
                        
                        // Font size controls
                        HStack(spacing: 4) {
                            Button(action: {
                                if model.fontSizeMultiplier > 0.6 {
                                    model.fontSizeMultiplier -= 0.1
                                }
                            }) {
                                Text("A-")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 28, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                            
                            Button(action: {
                                if model.fontSizeMultiplier < 2.0 {
                                    model.fontSizeMultiplier += 0.1
                                }
                            }) {
                                Text("A+")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 28, height: 24)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
                        // Native Apple Translation Selection Dropdown
                        HStack(spacing: 6) {
                            Image(systemName: "translate")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $model.selectedLanguage) {
                                ForEach(model.languages, id: \.code) { lang in
                                    Text(lang.name).tag(lang.code)
                                }
                            }
                            .frame(width: 160)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                    
                    Divider()
                    
                    ZStack {
                        ReaderView(model: model)
                        
                        if model.isLoading {
                            VStack(spacing: 15) {
                                ProgressView()
                                    .controlSize(.large)
                                Text(model.selectedLanguage != "en" ? "Translating Natively..." : "Unlocking Premium Article...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(30)
                            .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                            .cornerRadius(16)
                            .shadow(radius: 15)
                        }
                        
                        if let err = model.extractionError {
                            VStack {
                                Text(err)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .opacity(model.currentTab == .reader ? 1 : 0)
            }
        }
        .onReceive(model.$urlString) { newUrl in
            self.urlText = newUrl
        }
        .onChange(of: model.currentTab) { _, newTab in
            if newTab == .reader {
                // Reset translation state back to English whenever entering Reader Mode
                model.selectedLanguage = "en"
                
                // Always break the paywall and extract the fresh text of the current browser URL
                model.breakPaywall()
            }
        }
        .translationTask(model.translationConfig) { session in
            guard let article = model.article else { return }
            
            DispatchQueue.main.async {
                model.isLoading = true
                model.extractionError = nil
            }
            
            do {
                // Translate Header Info
                let trimmedTitle = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let transTitle = trimmedTitle.isEmpty ? "" : try await session.translate(article.title).targetText
                
                let trimmedSubtitle = article.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let transSubtitle = trimmedSubtitle.isEmpty ? "" : try await session.translate(article.subtitle).targetText
                
                let trimmedByline = article.byline.trimmingCharacters(in: .whitespacesAndNewlines)
                let transByline = trimmedByline.isEmpty ? "" : try await session.translate(article.byline).targetText
                
                let trimmedDate = article.date.trimmingCharacters(in: .whitespacesAndNewlines)
                let transDate = trimmedDate.isEmpty ? "" : try await session.translate(article.date).targetText
                
                let trimmedIssue = article.issue.trimmingCharacters(in: .whitespacesAndNewlines)
                let transIssue = trimmedIssue.isEmpty ? "" : try await session.translate(article.issue).targetText
                
                // Translate structured elements in sequence
                var transElements = [ArticleElement]()
                for element in article.elements {
                    let trimmedElement = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedElement.isEmpty {
                        transElements.append(element)
                    } else {
                        let transText = try await session.translate(element.text).targetText
                        transElements.append(ArticleElement(type: element.type, text: transText))
                    }
                }
                
                let translated = ArticleData(
                    title: transTitle,
                    subtitle: transSubtitle,
                    byline: transByline,
                    date: transDate,
                    issue: transIssue,
                    image: article.image,
                    elements: transElements
                )
                
                DispatchQueue.main.async {
                    model.translatedArticle = translated
                    model.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    model.isLoading = false
                    model.extractionError = "Native Apple Translation failed: \(error.localizedDescription)"
                    model.selectedLanguage = "en"
                }
            }
        }
        .frame(minWidth: 850, minHeight: 600)
    }
}

// Helper view to enable elegant blurred macOS backgrounds (glassmorphism)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
