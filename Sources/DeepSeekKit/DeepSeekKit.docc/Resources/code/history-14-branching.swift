import SwiftUI
import DeepSeekKit

// Conversation tree structure for branching
class ConversationTree: ObservableObject {
    @Published var root: ConversationNode
    @Published var currentPath: [UUID] = []
    
    private let client: DeepSeekClient
    
    class ConversationNode: Identifiable, ObservableObject {
        let id = UUID()
        let message: Message
        let timestamp = Date()
        @Published var children: [ConversationNode] = []
        weak var parent: ConversationNode?
        
        init(message: Message, parent: ConversationNode? = nil) {
            self.message = message
            self.parent = parent
        }
        
        func addChild(_ message: Message) -> ConversationNode {
            let child = ConversationNode(message: message, parent: self)
            children.append(child)
            return child
        }
        
        func removeChild(_ node: ConversationNode) {
            children.removeAll { $0.id == node.id }
        }
        
        var depth: Int {
            var count = 0
            var current = parent
            while current != nil {
                count += 1
                current = current?.parent
            }
            return count
        }
        
        var path: [ConversationNode] {
            var nodes: [ConversationNode] = [self]
            var current = parent
            while let node = current {
                nodes.insert(node, at: 0)
                current = node.parent
            }
            return nodes
        }
    }
    
    init(apiKey: String) {
        self.client = DeepSeekClient(apiKey: apiKey)
        
        // Initialize with system message
        let systemMessage = Message(
            role: .system,
            content: "You are a helpful AI assistant. This conversation supports branching - users can explore different conversation paths."
        )
        self.root = ConversationNode(message: systemMessage)
        self.currentPath = [root.id]
    }
    
    // MARK: - Navigation
    
    var currentNode: ConversationNode? {
        findNode(with: currentPath.last ?? UUID())
    }
    
    var currentMessages: [Message] {
        guard let node = currentNode else { return [] }
        return node.path.map { $0.message }
    }
    
    func navigateToNode(_ node: ConversationNode) {
        currentPath = node.path.map { $0.id }
    }
    
    private func findNode(with id: UUID, in node: ConversationNode? = nil) -> ConversationNode? {
        let searchNode = node ?? root
        
        if searchNode.id == id {
            return searchNode
        }
        
        for child in searchNode.children {
            if let found = findNode(with: id, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    // MARK: - Branching
    
    func createBranch(from node: ConversationNode, with message: String) async -> ConversationNode? {
        // Add user message as new branch
        let userMessage = Message(role: .user, content: message)
        let userNode = node.addChild(userMessage)
        
        // Generate AI response
        do {
            let messages = userNode.path.map { $0.message }
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: messages,
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            if let content = response.choices.first?.message.content {
                let assistantMessage = Message(role: .assistant, content: content)
                let assistantNode = userNode.addChild(assistantMessage)
                
                // Navigate to new branch
                navigateToNode(assistantNode)
                return assistantNode
            }
        } catch {
            print("Branch creation error: \(error)")
            // Remove failed branch
            node.removeChild(userNode)
        }
        
        return nil
    }
    
    // MARK: - Analysis
    
    func getAllPaths() -> [[ConversationNode]] {
        var paths: [[ConversationNode]] = []
        
        func traverse(node: ConversationNode, currentPath: [ConversationNode]) {
            let newPath = currentPath + [node]
            
            if node.children.isEmpty {
                paths.append(newPath)
            } else {
                for child in node.children {
                    traverse(node: child, currentPath: newPath)
                }
            }
        }
        
        traverse(node: root, currentPath: [])
        return paths
    }
    
    var totalBranches: Int {
        getAllPaths().count
    }
    
    var averageBranchLength: Double {
        let paths = getAllPaths()
        guard !paths.isEmpty else { return 0 }
        
        let totalLength = paths.reduce(0) { $0 + $1.count }
        return Double(totalLength) / Double(paths.count)
    }
}

// MARK: - Visualization

struct ConversationTreeView: View {
    @StateObject private var tree: ConversationTree
    @State private var showingBranchCreator = false
    @State private var selectedNodeForBranching: ConversationTree.ConversationNode?
    
    init(apiKey: String) {
        _tree = StateObject(wrappedValue: ConversationTree(apiKey: apiKey))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Tree visualization
                ScrollView {
                    TreeNodeView(node: tree.root, tree: tree) { node in
                        selectedNodeForBranching = node
                        showingBranchCreator = true
                    }
                    .padding()
                }
                
                Divider()
                
                // Current path view
                CurrentPathView(tree: tree)
            }
            .navigationTitle("Branching Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {}) {
                            Label("Branches: \(tree.totalBranches)", systemImage: "arrow.triangle.branch")
                        }
                        .disabled(true)
                        
                        Button(action: {}) {
                            Label(String(format: "Avg Length: %.1f", tree.averageBranchLength), 
                                  systemImage: "ruler")
                        }
                        .disabled(true)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingBranchCreator) {
                if let node = selectedNodeForBranching {
                    BranchCreatorView(tree: tree, parentNode: node)
                }
            }
        }
    }
}

struct TreeNodeView: View {
    let node: ConversationTree.ConversationNode
    @ObservedObject var tree: ConversationTree
    let onBranch: (ConversationTree.ConversationNode) -> Void
    
    @State private var isExpanded = true
    
    var isCurrentPath: Bool {
        tree.currentPath.contains(node.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Node content
            HStack {
                // Indentation
                ForEach(0..<node.depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .padding(.leading, 20)
                }
                
                // Node bubble
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: iconForRole(node.message.role))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(node.message.role.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if node.children.count > 1 {
                            Label("\(node.children.count)", systemImage: "arrow.triangle.branch")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Text(node.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(String(node.message.content.prefix(100)) + (node.message.content.count > 100 ? "..." : ""))
                        .font(.body)
                        .lineLimit(3)
                }
                .padding()
                .background(isCurrentPath ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCurrentPath ? Color.blue : Color.clear, lineWidth: 2)
                )
                .onTapGesture {
                    tree.navigateToNode(node)
                }
                .contextMenu {
                    Button(action: { tree.navigateToNode(node) }) {
                        Label("Navigate Here", systemImage: "arrow.right.circle")
                    }
                    
                    Button(action: { onBranch(node) }) {
                        Label("Create Branch", systemImage: "arrow.triangle.branch")
                    }
                    
                    Button(action: { UIPasteboard.general.string = node.message.content }) {
                        Label("Copy", systemImage: "doc.on.clipboard")
                    }
                }
                
                Spacer()
            }
            
            // Children
            if !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(node.children) { child in
                        TreeNodeView(node: child, tree: tree, onBranch: onBranch)
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
    
    private func iconForRole(_ role: MessageRole) -> String {
        switch role {
        case .system: return "gear"
        case .user: return "person.fill"
        case .assistant: return "cpu"
        case .function: return "function"
        }
    }
}

struct CurrentPathView: View {
    @ObservedObject var tree: ConversationTree
    @State private var inputText = ""
    @State private var isGenerating = false
    
    var body: some View {
        VStack {
            // Path indicator
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(tree.currentPath.enumerated()), id: \.offset) { index, nodeId in
                        if let node = tree.findNode(with: nodeId) {
                            PathSegment(node: node, isLast: index == tree.currentPath.count - 1)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 30)
            
            // Input
            HStack {
                TextField("Continue this branch...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isGenerating)
                
                Button(action: sendMessage) {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(inputText.isEmpty || isGenerating)
            }
            .padding()
        }
    }
    
    private func sendMessage() {
        guard let currentNode = tree.currentNode else { return }
        
        let message = inputText
        inputText = ""
        isGenerating = true
        
        Task {
            _ = await tree.createBranch(from: currentNode, with: message)
            isGenerating = false
        }
    }
}

struct PathSegment: View {
    let node: ConversationTree.ConversationNode
    let isLast: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Text(node.message.role.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(isLast ? 0.3 : 0.1))
                .cornerRadius(8)
            
            if !isLast {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BranchCreatorView: View {
    let tree: ConversationTree
    let parentNode: ConversationTree.ConversationNode
    
    @State private var branchPrompt = ""
    @State private var isCreating = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Context
                VStack(alignment: .leading, spacing: 8) {
                    Text("Branching from:")
                        .font(.headline)
                    
                    Text(parentNode.message.content)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // New branch input
                VStack(alignment: .leading, spacing: 8) {
                    Text("New branch message:")
                        .font(.headline)
                    
                    TextEditor(text: $branchPrompt)
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                // Create button
                Button(action: createBranch) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Create Branch")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(branchPrompt.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(branchPrompt.isEmpty || isCreating)
            }
            .padding()
            .navigationTitle("Create Branch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createBranch() {
        isCreating = true
        
        Task {
            _ = await tree.createBranch(from: parentNode, with: branchPrompt)
            dismiss()
        }
    }
}