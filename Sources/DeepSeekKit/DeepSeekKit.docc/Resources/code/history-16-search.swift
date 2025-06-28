import SwiftUI
import DeepSeekKit

// Advanced search functionality for conversation history
class ConversationSearchEngine: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchHistory: [String] = []
    
    struct SearchResult: Identifiable {
        let id = UUID()
        let conversation: Conversation
        let message: StorableMessage
        let relevanceScore: Double
        let highlightRanges: [Range<String.Index>]
        let context: SearchContext
    }
    
    struct SearchContext {
        let previousMessage: StorableMessage?
        let nextMessage: StorableMessage?
        let conversationPosition: Double // 0.0 = start, 1.0 = end
    }
    
    enum SearchMode {
        case simple
        case advanced
        case regex
        case semantic
    }
    
    struct SearchFilters {
        var dateRange: ClosedRange<Date>?
        var roles: Set<MessageRole> = Set(MessageRole.allCases)
        var minRelevanceScore: Double = 0.0
        var conversationTags: Set<String> = []
        var sortBy: SortOption = .relevance
        
        enum SortOption {
            case relevance
            case dateAscending
            case dateDescending
            case conversationTitle
        }
    }
    
    private let storage: ConversationStorage
    
    init(storage: ConversationStorage) {
        self.storage = storage
        loadSearchHistory()
    }
    
    // MARK: - Search Methods
    
    func search(query: String, 
               mode: SearchMode = .simple,
               filters: SearchFilters = SearchFilters()) async {
        
        await MainActor.run { isSearching = true }
        
        // Add to search history
        addToHistory(query)
        
        var results: [SearchResult] = []
        
        switch mode {
        case .simple:
            results = performSimpleSearch(query: query, filters: filters)
        case .advanced:
            results = performAdvancedSearch(query: query, filters: filters)
        case .regex:
            results = performRegexSearch(query: query, filters: filters)
        case .semantic:
            results = await performSemanticSearch(query: query, filters: filters)
        }
        
        // Apply sorting
        results = sortResults(results, by: filters.sortBy)
        
        await MainActor.run {
            self.searchResults = results
            self.isSearching = false
        }
    }
    
    private func performSimpleSearch(query: String, filters: SearchFilters) -> [SearchResult] {
        let lowercasedQuery = query.lowercased()
        var results: [SearchResult] = []
        
        for conversation in storage.conversations {
            // Check filters
            if !passesFilters(conversation: conversation, filters: filters) {
                continue
            }
            
            for (index, message) in conversation.messages.enumerated() {
                if !filters.roles.contains(message.role) {
                    continue
                }
                
                let content = message.content.lowercased()
                if content.contains(lowercasedQuery) {
                    let score = calculateRelevanceScore(
                        query: lowercasedQuery,
                        in: content,
                        position: Double(index) / Double(conversation.messages.count)
                    )
                    
                    if score >= filters.minRelevanceScore {
                        let context = createContext(
                            conversation: conversation,
                            messageIndex: index
                        )
                        
                        let highlightRanges = findHighlightRanges(
                            query: query,
                            in: message.content
                        )
                        
                        results.append(SearchResult(
                            conversation: conversation,
                            message: message,
                            relevanceScore: score,
                            highlightRanges: highlightRanges,
                            context: context
                        ))
                    }
                }
            }
        }
        
        return results
    }
    
    private func performAdvancedSearch(query: String, filters: SearchFilters) -> [SearchResult] {
        // Parse advanced query syntax (e.g., "role:user content:hello")
        let parsedQuery = parseAdvancedQuery(query)
        var results: [SearchResult] = []
        
        for conversation in storage.conversations {
            if !passesFilters(conversation: conversation, filters: filters) {
                continue
            }
            
            for (index, message) in conversation.messages.enumerated() {
                if matchesAdvancedQuery(message: message, query: parsedQuery) {
                    let score = 1.0 // Advanced search uses binary matching
                    
                    let context = createContext(
                        conversation: conversation,
                        messageIndex: index
                    )
                    
                    results.append(SearchResult(
                        conversation: conversation,
                        message: message,
                        relevanceScore: score,
                        highlightRanges: [],
                        context: context
                    ))
                }
            }
        }
        
        return results
    }
    
    private func performRegexSearch(query: String, filters: SearchFilters) -> [SearchResult] {
        var results: [SearchResult] = []
        
        do {
            let regex = try NSRegularExpression(pattern: query, options: .caseInsensitive)
            
            for conversation in storage.conversations {
                if !passesFilters(conversation: conversation, filters: filters) {
                    continue
                }
                
                for (index, message) in conversation.messages.enumerated() {
                    if !filters.roles.contains(message.role) {
                        continue
                    }
                    
                    let matches = regex.matches(
                        in: message.content,
                        range: NSRange(message.content.startIndex..., in: message.content)
                    )
                    
                    if !matches.isEmpty {
                        let context = createContext(
                            conversation: conversation,
                            messageIndex: index
                        )
                        
                        let highlightRanges = matches.compactMap { match in
                            Range(match.range, in: message.content)
                        }
                        
                        results.append(SearchResult(
                            conversation: conversation,
                            message: message,
                            relevanceScore: Double(matches.count),
                            highlightRanges: highlightRanges,
                            context: context
                        ))
                    }
                }
            }
        } catch {
            print("Invalid regex: \(error)")
        }
        
        return results
    }
    
    private func performSemanticSearch(query: String, filters: SearchFilters) async -> [SearchResult] {
        // This would integrate with a semantic search API
        // For now, return simple search as fallback
        return performSimpleSearch(query: query, filters: filters)
    }
    
    // MARK: - Helper Methods
    
    private func passesFilters(conversation: Conversation, filters: SearchFilters) -> Bool {
        // Date range filter
        if let dateRange = filters.dateRange {
            if !dateRange.contains(conversation.updatedAt) {
                return false
            }
        }
        
        // Tag filter
        if !filters.conversationTags.isEmpty {
            if filters.conversationTags.isDisjoint(with: Set(conversation.tags)) {
                return false
            }
        }
        
        return true
    }
    
    private func calculateRelevanceScore(query: String, in content: String, position: Double) -> Double {
        var score = 0.0
        
        // Frequency score
        let occurrences = content.components(separatedBy: query).count - 1
        score += Double(occurrences) * 0.3
        
        // Position score (earlier in conversation = higher relevance)
        score += (1.0 - position) * 0.2
        
        // Exact match bonus
        if content.contains(" \(query) ") {
            score += 0.5
        }
        
        return min(score, 1.0)
    }
    
    private func createContext(conversation: Conversation, messageIndex: Int) -> SearchContext {
        let previousMessage = messageIndex > 0 ? conversation.messages[messageIndex - 1] : nil
        let nextMessage = messageIndex < conversation.messages.count - 1 ? conversation.messages[messageIndex + 1] : nil
        let position = Double(messageIndex) / Double(max(conversation.messages.count - 1, 1))
        
        return SearchContext(
            previousMessage: previousMessage,
            nextMessage: nextMessage,
            conversationPosition: position
        )
    }
    
    private func findHighlightRanges(query: String, in content: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = content.startIndex..<content.endIndex
        
        while let range = content.range(of: query, options: .caseInsensitive, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<content.endIndex
        }
        
        return ranges
    }
    
    private func sortResults(_ results: [SearchResult], by option: SearchFilters.SortOption) -> [SearchResult] {
        switch option {
        case .relevance:
            return results.sorted { $0.relevanceScore > $1.relevanceScore }
        case .dateAscending:
            return results.sorted { $0.message.timestamp < $1.message.timestamp }
        case .dateDescending:
            return results.sorted { $0.message.timestamp > $1.message.timestamp }
        case .conversationTitle:
            return results.sorted { $0.conversation.title < $1.conversation.title }
        }
    }
    
    // MARK: - Advanced Query Parsing
    
    private struct AdvancedQuery {
        var role: MessageRole?
        var content: String?
        var before: Date?
        var after: Date?
    }
    
    private func parseAdvancedQuery(_ query: String) -> AdvancedQuery {
        var parsed = AdvancedQuery()
        
        // Simple parser for "key:value" syntax
        let components = query.components(separatedBy: " ")
        for component in components {
            if component.contains(":") {
                let parts = component.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                
                let key = String(parts[0]).lowercased()
                let value = String(parts[1])
                
                switch key {
                case "role":
                    parsed.role = MessageRole(rawValue: value)
                case "content":
                    parsed.content = value
                default:
                    break
                }
            }
        }
        
        return parsed
    }
    
    private func matchesAdvancedQuery(message: StorableMessage, query: AdvancedQuery) -> Bool {
        if let role = query.role, message.role != role {
            return false
        }
        
        if let content = query.content, !message.content.localizedCaseInsensitiveContains(content) {
            return false
        }
        
        return true
    }
    
    // MARK: - Search History
    
    private func loadSearchHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: "searchHistory") {
            searchHistory = history
        }
    }
    
    private func addToHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        searchHistory.insert(query, at: 0)
        
        // Keep only last 20 searches
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }
}

// MARK: - Search UI

struct ConversationSearchView: View {
    @StateObject private var searchEngine: ConversationSearchEngine
    @State private var searchQuery = ""
    @State private var searchMode: ConversationSearchEngine.SearchMode = .simple
    @State private var showingFilters = false
    @State private var filters = ConversationSearchEngine.SearchFilters()
    
    init(storage: ConversationStorage) {
        _searchEngine = StateObject(wrappedValue: ConversationSearchEngine(storage: storage))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: searchModeIcon)
                            .foregroundColor(.secondary)
                        
                        TextField("Search conversations...", text: $searchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: performSearch) {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(searchQuery.isEmpty)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Mode selector
                    Picker("Search Mode", selection: $searchMode) {
                        Text("Simple").tag(ConversationSearchEngine.SearchMode.simple)
                        Text("Advanced").tag(ConversationSearchEngine.SearchMode.advanced)
                        Text("Regex").tag(ConversationSearchEngine.SearchMode.regex)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
                
                // Results
                if searchEngine.isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchEngine.searchResults.isEmpty && !searchQuery.isEmpty {
                    NoResultsView()
                } else if !searchEngine.searchResults.isEmpty {
                    SearchResultsList(results: searchEngine.searchResults)
                } else {
                    SearchHistoryView(
                        history: searchEngine.searchHistory,
                        onSelect: { query in
                            searchQuery = query
                            performSearch()
                        }
                    )
                }
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(filters: $filters)
            }
        }
    }
    
    private var searchModeIcon: String {
        switch searchMode {
        case .simple: return "magnifyingglass"
        case .advanced: return "magnifyingglass.circle"
        case .regex: return "chevron.left.forwardslash.chevron.right"
        case .semantic: return "brain"
        }
    }
    
    private func performSearch() {
        Task {
            await searchEngine.search(
                query: searchQuery,
                mode: searchMode,
                filters: filters
            )
        }
    }
}

struct SearchResultsList: View {
    let results: [ConversationSearchEngine.SearchResult]
    
    var body: some View {
        List {
            ForEach(results) { result in
                SearchResultRow(result: result)
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct SearchResultRow: View {
    let result: ConversationSearchEngine.SearchResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Conversation title
            HStack {
                Text(result.conversation.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Relevance indicator
                RelevanceIndicator(score: result.relevanceScore)
            }
            
            // Message preview with highlights
            HighlightedText(
                text: result.message.content,
                highlights: result.highlightRanges
            )
            .font(.body)
            .lineLimit(isExpanded ? nil : 3)
            
            // Context
            if isExpanded && result.context.previousMessage != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Previous:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(result.context.previousMessage!.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.leading)
                }
            }
            
            // Metadata
            HStack {
                Label(result.message.role.rawValue, systemImage: "person.fill")
                    .font(.caption)
                
                Label(result.message.timestamp, format: .dateTime, systemImage: "calendar")
                    .font(.caption)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct HighlightedText: View {
    let text: String
    let highlights: [Range<String.Index>]
    
    var body: some View {
        let attributedString = createAttributedString()
        Text(AttributedString(attributedString))
    }
    
    private func createAttributedString() -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        
        for range in highlights {
            let nsRange = NSRange(range, in: text)
            attributed.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: nsRange)
            attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize), range: nsRange)
        }
        
        return attributed
    }
}

struct RelevanceIndicator: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(Double(index) < score * 5 ? .yellow : .gray.opacity(0.3))
            }
        }
    }
}

struct SearchHistoryView: View {
    let history: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Searches")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(history, id: \.self) { query in
                        Button(action: { onSelect(query) }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                
                                Text(query)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.top)
    }
}

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try adjusting your search query or filters")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchFiltersView: View {
    @Binding var filters: ConversationSearchEngine.SearchFilters
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Message Roles") {
                    ForEach(MessageRole.allCases, id: \.self) { role in
                        Toggle(role.rawValue.capitalized, isOn: Binding(
                            get: { filters.roles.contains(role) },
                            set: { isOn in
                                if isOn {
                                    filters.roles.insert(role)
                                } else {
                                    filters.roles.remove(role)
                                }
                            }
                        ))
                    }
                }
                
                Section("Relevance") {
                    VStack(alignment: .leading) {
                        Text("Minimum Score: \(Int(filters.minRelevanceScore * 100))%")
                            .font(.caption)
                        
                        Slider(value: $filters.minRelevanceScore, in: 0...1)
                    }
                }
                
                Section("Sort By") {
                    Picker("Sort Order", selection: $filters.sortBy) {
                        Text("Relevance").tag(ConversationSearchEngine.SearchFilters.SortOption.relevance)
                        Text("Date (Newest)").tag(ConversationSearchEngine.SearchFilters.SortOption.dateDescending)
                        Text("Date (Oldest)").tag(ConversationSearchEngine.SearchFilters.SortOption.dateAscending)
                        Text("Title").tag(ConversationSearchEngine.SearchFilters.SortOption.conversationTitle)
                    }
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { dismiss() }
                }
            }
        }
    }
}