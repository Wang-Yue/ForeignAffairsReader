import SwiftUI
@preconcurrency import Translation

struct ArticleCardView: View {
    let article: ArticleHeader
    let isSelected: Bool
    let theme: ReaderTheme
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.category)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isSelected ? theme.accentColor : theme.secondaryTextColor)
                        .tracking(1.2)
                    
                    Text(article.title)
                        .font(.custom("Playfair Display", size: 13))
                        .fontWeight(.semibold)
                        .foregroundColor(theme.primaryTextColor)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !article.byline.isEmpty {
                        Text("By \(article.byline)")
                            .font(.system(size: 10))
                            .foregroundColor(theme.secondaryTextColor)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if !article.image.isEmpty {
                    AsyncImage(url: URL(string: article.image)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .cornerRadius(6)
                        default:
                            theme.secondaryTextColor.opacity(0.1)
                                .frame(width: 50, height: 50)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.cardBackgroundColor(isSelected: isSelected, isHovered: isHovered))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}

struct ContentView: View {
    @State private var model = AppModel()
    @State private var searchInput: String = ""
    
    var body: some View {
        NavigationSplitView {
            // Left Side: Sidebar
            VStack(spacing: 0) {
                // Premium Sidebar Header (Title & Subtitle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Foreign Affairs")
                        .font(.custom("Playfair Display", size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(model.readerTheme.primaryTextColor)
                    
                    Text("Reader Edition")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(model.readerTheme.secondaryTextColor)
                        .tracking(1.5)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Elegant Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(model.readerTheme.secondaryTextColor)
                        .font(.system(size: 12))
                    
                    TextField("Search articles...", text: $searchInput, onCommit: {
                        model.searchQuery = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.fetchArticlesForCurrentSection()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(model.readerTheme.primaryTextColor)
                    
                    if !searchInput.isEmpty {
                        Button(action: {
                            searchInput = ""
                            model.searchQuery = ""
                            model.fetchArticlesForCurrentSection()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(model.readerTheme.secondaryTextColor)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(model.readerTheme.controlBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(model.readerTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Custom Horizontal Capsule Selector for Categories
                HStack(spacing: 4) {
                    ForEach(["Featured", "Latest", "Most Read"], id: \.self) { section in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                model.sidebarSection = section
                            }
                        }) {
                            Text(section)
                                .font(.system(size: 11, weight: model.sidebarSection == section ? .semibold : .medium))
                                .foregroundColor(model.sidebarSection == section ? model.readerTheme.primaryTextColor : model.readerTheme.secondaryTextColor)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(model.sidebarSection == section ? model.readerTheme.controlBackgroundColor : Color.clear)
                                        .shadow(color: model.sidebarSection == section ? Color.black.opacity(model.readerTheme == .dark ? 0.3 : 0.06) : Color.clear, radius: 1, x: 0, y: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(model.readerTheme.sidebarBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(model.readerTheme.borderColor, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                Rectangle()
                    .fill(model.readerTheme.borderColor)
                    .frame(height: 1)
                
                // Article List Scroll Area
                ZStack {
                    if model.isListLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching feed from live site...")
                                .font(.system(size: 11))
                                .foregroundColor(model.readerTheme.secondaryTextColor)
                        }
                        .frame(maxHeight: .infinity)
                    } else if let listErr = model.listError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(model.readerTheme.accentColor)
                            Text(listErr)
                                .font(.system(size: 11))
                                .foregroundColor(model.readerTheme.secondaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Button("Retry") {
                                model.fetchArticlesForCurrentSection()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxHeight: .infinity)
                    } else if model.articleList.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundColor(model.readerTheme.secondaryTextColor)
                            Text("No articles found")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(model.readerTheme.primaryTextColor)
                            Text("Try refining your query or browse a different section.")
                                .font(.system(size: 10))
                                .foregroundColor(model.readerTheme.secondaryTextColor)
                                .multilineTextAlignment(.center)
                        }
                        .padding(30)
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(model.articleList) { articleHeader in
                                    ArticleCardView(
                                        article: articleHeader,
                                        isSelected: model.urlString == articleHeader.url,
                                        theme: model.readerTheme,
                                        action: {
                                            model.selectArticle(articleHeader)
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .background(model.readerTheme.sidebarBackgroundColor)
            .navigationSplitViewColumnWidth(min: 320, ideal: 340, max: 400)
        } detail: {
            // Right Side: Reader View
            ZStack {
                ReaderView(model: model)
                
                if model.isLoading {
                    VStack(spacing: 15) {
                        ProgressView()
                            .controlSize(.large)
                        Text(model.selectedLanguage != "en" ? "Translating Natively..." : "Preparing Reader Mode...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(model.readerTheme.secondaryTextColor)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(model.readerTheme.controlBackgroundColor)
                            .shadow(color: Color.black.opacity(model.readerTheme == .dark ? 0.4 : 0.08), radius: 15)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(model.readerTheme.borderColor, lineWidth: 1)
                    )
                }
                
                if let err = model.extractionError {
                    VStack {
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(model.readerTheme == .dark ? .black : .white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(model.readerTheme.accentColor)
                            )
                    }
                }
            }
            .background(model.readerTheme.backgroundColor)
            .frame(minWidth: 500, idealWidth: 600, maxWidth: .infinity)
            .navigationTitle(model.translatedArticle?.title ?? model.article?.title ?? "Reading Room")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Theme Segment Picker
                    Picker("Theme", selection: $model.readerTheme) {
                        ForEach(ReaderTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Reader Theme")
                    
                    // Font sizing triggers
                    HStack(spacing: 2) {
                        Button(action: {
                            if model.fontSizeMultiplier > 0.6 {
                                model.fontSizeMultiplier -= 0.1
                            }
                        }) {
                            Label("Decrease Font Size", systemImage: "textformat.size.smaller")
                        }
                        .help("Decrease Font Size")
                        
                        Button(action: {
                            if model.fontSizeMultiplier < 2.0 {
                                model.fontSizeMultiplier += 0.1
                            }
                        }) {
                            Label("Increase Font Size", systemImage: "textformat.size.larger")
                        }
                        .help("Increase Font Size")
                    }
                    
                    // Native Translation Dropdown Selection
                    Picker(selection: $model.selectedLanguage, label: Label("Translate", systemImage: "translate")) {
                        ForEach(model.languages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("Translate Article")
                }
            }
        }
        .translationTask(model.translationConfig) { session in
            guard let article = model.article else { return }
            
            model.isLoading = true
            model.extractionError = nil
            
            do {
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
                
                model.translatedArticle = translated
                model.isLoading = false
            } catch {
                model.isLoading = false
                model.extractionError = "Native Apple Translation failed: \(error.localizedDescription)"
                model.selectedLanguage = "en"
            }
        }
        .id(model.article?.title ?? "empty")
        .frame(minWidth: 850, minHeight: 600)
        .onAppear {
            updateWindowAppearance(for: model.readerTheme)
        }
        .onChange(of: model.readerTheme) {
            updateWindowAppearance(for: model.readerTheme)
        }
        .onChange(of: model.article?.title) {
            updateWindowAppearance(for: model.readerTheme)
        }
        .onChange(of: model.translatedArticle?.title) {
            updateWindowAppearance(for: model.readerTheme)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { notification in
            if let window = notification.object as? NSWindow {
                updateWindowAppearance(for: model.readerTheme, window: window)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
            if let window = notification.object as? NSWindow {
                updateWindowAppearance(for: model.readerTheme, window: window)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { notification in
            if let window = notification.object as? NSWindow {
                updateWindowAppearance(for: model.readerTheme, window: window)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            if let window = notification.object as? NSWindow {
                updateWindowAppearance(for: model.readerTheme, window: window)
            }
        }
    }
    
    private func updateWindowAppearance(for theme: ReaderTheme, window: NSWindow? = nil) {
        DispatchQueue.main.async {
            guard let window = window ?? NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow }) ?? NSApp.windows.first else { return }
            
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .visible
            
            switch theme {
            case .dark:
                window.appearance = NSAppearance(named: .darkAqua)
                window.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
            case .light:
                window.appearance = NSAppearance(named: .aqua)
                window.backgroundColor = .white
            case .sepia:
                window.appearance = NSAppearance(named: .aqua)
                window.backgroundColor = NSColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1.0)
            }
        }
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
