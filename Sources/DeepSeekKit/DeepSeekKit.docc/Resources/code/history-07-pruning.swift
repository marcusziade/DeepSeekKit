import SwiftUI
import DeepSeekKit

class SmartPruningManager: ObservableObject {
    @Published var messages: [Message] = []
    
    // Message metadata for smart pruning
    struct MessageMetadata {
        let message: Message
        let timestamp: Date
        var importance: Double
        var references: Set<Int> // Indices of related messages
    }
    
    private var metadata: [MessageMetadata] = []
    private let maxTokens: Int = 28_000 // Leave room for response
    
    init() {
        addSystemMessage("You are a helpful AI assistant.")
    }
    
    func addMessage(_ message: Message, importance: Double = 0.5) {
        let meta = MessageMetadata(
            message: message,
            timestamp: Date(),
            importance: calculateImportance(message, baseImportance: importance),
            references: findReferences(in: message.content)
        )
        
        messages.append(message)
        metadata.append(meta)
        
        // Update importance of referenced messages
        updateReferenceImportance()
        
        // Prune if needed
        if shouldPrune() {
            performSmartPruning()
        }
    }
    
    private func calculateImportance(_ message: Message, baseImportance: Double) -> Double {
        var importance = baseImportance
        
        // System messages are always important
        if message.role == .system {
            importance = 1.0
        }
        
        // Messages with questions are more important
        if message.content.contains("?") {
            importance += 0.2
        }
        
        // Messages with code are important
        if message.content.contains("```") {
            importance += 0.3
        }
        
        // Long messages might contain important context
        if message.content.count > 500 {
            importance += 0.1
        }
        
        // Messages with numbers/data are often important
        if containsImportantData(message.content) {
            importance += 0.2
        }
        
        return min(importance, 1.0)
    }
    
    private func containsImportantData(_ content: String) -> Bool {
        // Check for numbers, dates, URLs, etc.
        let patterns = [
            #"\d+"#,                    // Numbers
            #"\d{4}-\d{2}-\d{2}"#,     // Dates
            #"https?://\S+"#,           // URLs
            #"[A-Z]{2,}"#              // Acronyms
        ]
        
        for pattern in patterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func findReferences(in content: String) -> Set<Int> {
        var references: Set<Int> = []
        
        // Look for references to previous messages
        let patterns = [
            #"message (\d+)"#,
            #"#(\d+)"#,
            #"above"#,
            #"previous"#,
            #"earlier"#
        ]
        
        for (index, meta) in metadata.enumerated() {
            // Check if content references other messages
            if content.lowercased().contains(meta.message.content.prefix(20).lowercased()) {
                references.insert(index)
            }
        }
        
        return references
    }
    
    private func updateReferenceImportance() {
        for (index, meta) in metadata.enumerated() {
            for refIndex in meta.references {
                if refIndex < metadata.count {
                    metadata[refIndex].importance += 0.1
                }
            }
        }
    }
    
    private func shouldPrune() -> Bool {
        let totalTokens = estimateTotalTokens()
        return totalTokens > maxTokens
    }
    
    private func estimateTotalTokens() -> Int {
        messages.reduce(0) { $0 + ($1.content.count / 4) + 4 }
    }
    
    private func performSmartPruning() {
        // Sort messages by importance (keep order for those with same importance)
        let sortedIndices = metadata.enumerated()
            .sorted { (a, b) in
                if a.element.importance == b.element.importance {
                    return a.offset < b.offset // Preserve order
                }
                return a.element.importance > b.element.importance
            }
            .map { $0.offset }
        
        var keptIndices = Set<Int>()
        var currentTokens = 0
        
        // Keep messages by importance until we hit token limit
        for index in sortedIndices {
            let messageTokens = (metadata[index].message.content.count / 4) + 4
            
            if currentTokens + messageTokens < maxTokens {
                keptIndices.insert(index)
                currentTokens += messageTokens
                
                // Also keep referenced messages
                for refIndex in metadata[index].references {
                    if !keptIndices.contains(refIndex) && refIndex < metadata.count {
                        let refTokens = (metadata[refIndex].message.content.count / 4) + 4
                        if currentTokens + refTokens < maxTokens {
                            keptIndices.insert(refIndex)
                            currentTokens += refTokens
                        }
                    }
                }
            }
        }
        
        // Rebuild messages and metadata keeping original order
        let sortedKeptIndices = keptIndices.sorted()
        messages = sortedKeptIndices.map { metadata[$0].message }
        metadata = sortedKeptIndices.map { metadata[$0] }
    }
    
    func addSystemMessage(_ content: String) {
        addMessage(Message(role: .system, content: content), importance: 1.0)
    }
    
    func addUserMessage(_ content: String, importance: Double = 0.6) {
        addMessage(Message(role: .user, content: content), importance: importance)
    }
    
    func addAssistantMessage(_ content: String, importance: Double = 0.5) {
        addMessage(Message(role: .assistant, content: content), importance: importance)
    }
}

// Debug view to visualize pruning
struct PruningDebugView: View {
    @ObservedObject var manager: SmartPruningManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(manager.metadata.enumerated()), id: \.offset) { index, meta in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(meta.message.role.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(String(meta.message.content.prefix(50)) + "...")
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(String(format: "%.2f", meta.importance))
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            if !meta.references.isEmpty {
                                Text("Refs: \(meta.references.count)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(importanceColor(meta.importance))
                    .cornerRadius(4)
                }
            }
        }
    }
    
    private func importanceColor(_ importance: Double) -> Color {
        Color.blue.opacity(importance * 0.3)
    }
}