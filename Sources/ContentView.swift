import SwiftUI
import Translation

struct ArticleCardView: View {
    let article: ArticleHeader
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.category)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .tracking(1.2)
                    
                    Text(article.title)
                        .font(.custom("Playfair Display", size: 13))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !article.byline.isEmpty {
                        Text("By \(article.byline)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
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
                            Color.secondary.opacity(0.1)
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
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.secondary.opacity(0.08) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
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
    @StateObject var model = AppModel()
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
                        .foregroundColor(.primary)
                    
                    Text("Reader Edition")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    TextField("Search articles...", text: $searchInput, onCommit: {
                        model.searchQuery = searchInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.fetchArticlesForCurrentSection()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    
                    if !searchInput.isEmpty {
                        Button(action: {
                            searchInput = ""
                            model.searchQuery = ""
                            model.fetchArticlesForCurrentSection()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
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
                                .foregroundColor(model.sidebarSection == section ? .primary : .secondary)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(model.sidebarSection == section ? Color(NSColor.selectedControlColor).opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                Divider()
                
                // Article List Scroll Area
                ZStack {
                    if model.isListLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching feed from live site...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else if let listErr = model.listError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text(listErr)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
                            Text("No articles found")
                                .font(.system(size: 12, weight: .medium))
                            Text("Try refining your query or browse a different section.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(8)
                    }
                }
            }
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
            
            DispatchQueue.main.async {
                model.isLoading = true
                model.extractionError = nil
            }
            
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
        .id(model.article?.title ?? "empty")
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
