import SwiftUI
import DeepSeekKit

// Conversation template system
struct ConversationTemplate: Identifiable, Codable {
    let id = UUID()
    let name: String
    let description: String
    let category: Category
    let icon: String
    let systemPrompt: String
    let initialMessages: [TemplateMessage]
    let variables: [TemplateVariable]
    let tags: [String]
    
    enum Category: String, CaseIterable, Codable {
        case productivity = "Productivity"
        case creative = "Creative"
        case technical = "Technical"
        case educational = "Educational"
        case business = "Business"
        case personal = "Personal"
        
        var color: Color {
            switch self {
            case .productivity: return .blue
            case .creative: return .purple
            case .technical: return .green
            case .educational: return .orange
            case .business: return .indigo
            case .personal: return .pink
            }
        }
    }
    
    struct TemplateMessage: Codable {
        let role: MessageRole
        let content: String
    }
    
    struct TemplateVariable: Codable {
        let name: String
        let description: String
        let defaultValue: String
        let required: Bool
    }
}

// Template manager
class ConversationTemplateManager: ObservableObject {
    @Published var templates: [ConversationTemplate] = []
    @Published var customTemplates: [ConversationTemplate] = []
    
    init() {
        loadBuiltInTemplates()
        loadCustomTemplates()
    }
    
    private func loadBuiltInTemplates() {
        templates = [
            // Productivity Templates
            ConversationTemplate(
                name: "Daily Standup",
                description: "Structure your daily standup meeting",
                category: .productivity,
                icon: "person.3.fill",
                systemPrompt: "You are a scrum master assistant helping to facilitate daily standup meetings. Keep responses concise and focused on the three key questions: What did you do yesterday? What will you do today? Are there any blockers?",
                initialMessages: [
                    ConversationTemplate.TemplateMessage(
                        role: .assistant,
                        content: "Good morning! Let's start our daily standup. {{userName}}, what did you accomplish yesterday?"
                    )
                ],
                variables: [
                    ConversationTemplate.TemplateVariable(
                        name: "userName",
                        description: "Team member's name",
                        defaultValue: "Team Member",
                        required: true
                    )
                ],
                tags: ["standup", "agile", "meeting"]
            ),
            
            ConversationTemplate(
                name: "Code Review",
                description: "Systematic code review assistant",
                category: .technical,
                icon: "chevron.left.forwardslash.chevron.right",
                systemPrompt: "You are a senior developer conducting code reviews. Focus on code quality, best practices, potential bugs, performance, and maintainability. Be constructive and educational in your feedback.",
                initialMessages: [
                    ConversationTemplate.TemplateMessage(
                        role: .assistant,
                        content: "I'll help you review your code. Please share the code you'd like me to review, and let me know if there are specific areas of concern."
                    )
                ],
                variables: [],
                tags: ["code", "review", "development"]
            ),
            
            // Creative Templates
            ConversationTemplate(
                name: "Story Brainstorming",
                description: "Creative writing companion",
                category: .creative,
                icon: "book.fill",
                systemPrompt: "You are a creative writing coach helping to brainstorm and develop story ideas. Ask thought-provoking questions, suggest plot twists, and help develop characters. Be enthusiastic and encouraging.",
                initialMessages: [
                    ConversationTemplate.TemplateMessage(
                        role: .assistant,
                        content: "Let's create an amazing story together! What genre interests you for this story - {{genre}}? And do you have any initial ideas about characters or setting?"
                    )
                ],
                variables: [
                    ConversationTemplate.TemplateVariable(
                        name: "genre",
                        description: "Story genre",
                        defaultValue: "fantasy, sci-fi, mystery, etc.",
                        required: false
                    )
                ],
                tags: ["writing", "creative", "story"]
            ),
            
            // Educational Templates
            ConversationTemplate(
                name: "Socratic Tutor",
                description: "Learn through guided questions",
                category: .educational,
                icon: "graduationcap.fill",
                systemPrompt: "You are a Socratic tutor. Guide the student to discover answers through thoughtful questions rather than direct explanations. Help them think critically and develop problem-solving skills.",
                initialMessages: [
                    ConversationTemplate.TemplateMessage(
                        role: .assistant,
                        content: "I'm here to help you learn about {{subject}}. Instead of giving you direct answers, I'll guide you with questions. What specific aspect would you like to explore?"
                    )
                ],
                variables: [
                    ConversationTemplate.TemplateVariable(
                        name: "subject",
                        description: "Subject to learn",
                        defaultValue: "any subject",
                        required: true
                    )
                ],
                tags: ["education", "learning", "socratic"]
            ),
            
            // Business Templates
            ConversationTemplate(
                name: "SWOT Analysis",
                description: "Structured business analysis",
                category: .business,
                icon: "chart.pie.fill",
                systemPrompt: "You are a business strategist helping to conduct SWOT analyses. Guide through identifying Strengths, Weaknesses, Opportunities, and Threats systematically. Ask probing questions and provide insights.",
                initialMessages: [
                    ConversationTemplate.TemplateMessage(
                        role: .assistant,
                        content: "Let's conduct a SWOT analysis for {{company}}. We'll examine Strengths, Weaknesses, Opportunities, and Threats. Let's start with Strengths - what are the key advantages or positive attributes?"
                    )
                ],
                variables: [
                    ConversationTemplate.TemplateVariable(
                        name: "company",
                        description: "Company or project name",
                        defaultValue: "your company",
                        required: true
                    )
                ],
                tags: ["business", "strategy", "analysis"]
            )
        ]
    }
    
    private func loadCustomTemplates() {
        // Load from UserDefaults or file storage
        if let data = UserDefaults.standard.data(forKey: "customTemplates"),
           let templates = try? JSONDecoder().decode([ConversationTemplate].self, from: data) {
            customTemplates = templates
        }
    }
    
    func saveCustomTemplate(_ template: ConversationTemplate) {
        customTemplates.append(template)
        
        if let data = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(data, forKey: "customTemplates")
        }
    }
    
    func deleteCustomTemplate(_ template: ConversationTemplate) {
        customTemplates.removeAll { $0.id == template.id }
        
        if let data = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(data, forKey: "customTemplates")
        }
    }
    
    func applyTemplate(_ template: ConversationTemplate, with values: [String: String]) -> [Message] {
        var messages: [Message] = []
        
        // Apply system prompt with variables
        let systemContent = replaceVariables(in: template.systemPrompt, with: values)
        messages.append(Message(role: .system, content: systemContent))
        
        // Apply initial messages with variables
        for templateMessage in template.initialMessages {
            let content = replaceVariables(in: templateMessage.content, with: values)
            messages.append(Message(role: templateMessage.role, content: content))
        }
        
        return messages
    }
    
    private func replaceVariables(in text: String, with values: [String: String]) -> String {
        var result = text
        
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return result
    }
}

// MARK: - UI Components

struct ConversationTemplatesView: View {
    @StateObject private var templateManager = ConversationTemplateManager()
    @State private var selectedCategory: ConversationTemplate.Category?
    @State private var searchText = ""
    @State private var showingCreateTemplate = false
    @State private var selectedTemplate: ConversationTemplate?
    
    var filteredTemplates: [ConversationTemplate] {
        let allTemplates = templateManager.templates + templateManager.customTemplates
        
        return allTemplates.filter { template in
            let categoryMatch = selectedCategory == nil || template.category == selectedCategory
            let searchMatch = searchText.isEmpty || 
                             template.name.localizedCaseInsensitiveContains(searchText) ||
                             template.description.localizedCaseInsensitiveContains(searchText) ||
                             template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            return categoryMatch && searchMatch
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search templates...", text: $searchText)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        CategoryChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            color: .gray
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(ConversationTemplate.Category.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                isSelected: selectedCategory == category,
                                color: category.color
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Templates grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(filteredTemplates) { template in
                            TemplateCard(template: template) {
                                selectedTemplate = template
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateTemplate = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplateConfigurationView(template: template)
            }
            .sheet(isPresented: $showingCreateTemplate) {
                CreateTemplateView(templateManager: templateManager)
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

struct TemplateCard: View {
    let template: ConversationTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(template.category.color)
                    
                    Spacer()
                    
                    Text(template.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(template.category.color.opacity(0.2))
                        .foregroundColor(template.category.color)
                        .cornerRadius(4)
                }
                
                Text(template.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Tags
                if !template.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(template.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateConfigurationView: View {
    let template: ConversationTemplate
    @State private var variableValues: [String: String] = [:]
    @State private var isStarting = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Template info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: template.icon)
                            .font(.largeTitle)
                            .foregroundColor(template.category.color)
                        
                        VStack(alignment: .leading) {
                            Text(template.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(template.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Variables
                if !template.variables.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Configure Template")
                            .font(.headline)
                        
                        ForEach(template.variables, id: \.name) { variable in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(variable.description)
                                        .font(.subheadline)
                                    if variable.required {
                                        Text("*")
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                TextField(variable.defaultValue, text: Binding(
                                    get: { variableValues[variable.name] ?? variable.defaultValue },
                                    set: { variableValues[variable.name] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
                
                // Start button
                Button(action: startConversation) {
                    if isStarting {
                        ProgressView()
                    } else {
                        Text("Start Conversation")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!allRequiredVariablesFilled)
            }
            .padding()
            .navigationTitle("Configure Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var allRequiredVariablesFilled: Bool {
        template.variables.filter { $0.required }.allSatisfy { variable in
            !(variableValues[variable.name] ?? "").isEmpty
        }
    }
    
    private func startConversation() {
        // Apply template and start conversation
        // This would integrate with your conversation manager
        dismiss()
    }
}