import SwiftUI
import DeepSeekKit

// Understanding Fill-in-Middle (FIM) structure
struct FIMStructureView: View {
    @StateObject private var demonstrator = FIMDemonstrator()
    @State private var codeExample = CodeExample.simpleFunction
    @State private var cursorPosition = 50
    
    enum CodeExample: String, CaseIterable {
        case simpleFunction = "Simple Function"
        case classMethod = "Class Method"
        case swiftUIView = "SwiftUI View"
        case completion = "Code Completion"
        
        var code: String {
            switch self {
            case .simpleFunction:
                return """
                func calculateTotal(items: [Item]) -> Double {
                    // TODO: Calculate total
                    return 0.0
                }
                """
            case .classMethod:
                return """
                class ShoppingCart {
                    private var items: [Item] = []
                    
                    func addItem(_ item: Item) {
                        // TODO: Add item
                    }
                }
                """
            case .swiftUIView:
                return """
                struct ContentView: View {
                    var body: some View {
                        VStack {
                            // TODO: Add content
                        }
                    }
                }
                """
            case .completion:
                return """
                let numbers = [1, 2, 3, 4, 5]
                let doubled = numbers.map { 
                    // TODO: Double each number
                }
                """
            }
        }
        
        var idealCursorPosition: Int {
            // Position cursor at TODO comment
            if let range = code.range(of: "TODO:") {
                return code.distance(from: code.startIndex, to: range.lowerBound)
            }
            return code.count / 2
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // FIM concept explanation
                ConceptExplanationView()
                
                // Code example selector
                CodeExampleSelector(
                    selectedExample: $codeExample,
                    onSelect: { example in
                        cursorPosition = example.idealCursorPosition
                    }
                )
                
                // Interactive FIM demonstration
                InteractiveFIMView(
                    code: codeExample.code,
                    cursorPosition: $cursorPosition,
                    demonstrator: demonstrator
                )
                
                // FIM components breakdown
                if let components = demonstrator.currentComponents {
                    FIMComponentsView(components: components)
                }
                
                // How FIM works
                HowFIMWorksView()
                
                // Best practices
                FIMBestPracticesView()
            }
            .padding()
        }
        .navigationTitle("FIM Structure")
        .onAppear {
            demonstrator.analyzeCode(codeExample.code, cursorPosition: cursorPosition)
        }
        .onChange(of: codeExample) { _ in
            demonstrator.analyzeCode(codeExample.code, cursorPosition: cursorPosition)
        }
        .onChange(of: cursorPosition) { _ in
            demonstrator.analyzeCode(codeExample.code, cursorPosition: cursorPosition)
        }
    }
}

// MARK: - FIM Demonstrator

class FIMDemonstrator: ObservableObject {
    @Published var currentComponents: FIMComponents?
    
    struct FIMComponents {
        let prefix: String
        let suffix: String
        let expectedCompletion: String
        let context: String
    }
    
    func analyzeCode(_ code: String, cursorPosition: Int) {
        let index = code.index(code.startIndex, offsetBy: min(cursorPosition, code.count))
        
        let prefix = String(code[..<index])
        let suffix = String(code[index...])
        
        // Determine expected completion based on context
        let expectedCompletion = generateExpectedCompletion(prefix: prefix, suffix: suffix)
        let context = extractContext(from: code, at: cursorPosition)
        
        currentComponents = FIMComponents(
            prefix: prefix,
            suffix: suffix,
            expectedCompletion: expectedCompletion,
            context: context
        )
    }
    
    private func generateExpectedCompletion(prefix: String, suffix: String) -> String {
        // Simple heuristic-based completion
        if prefix.contains("TODO: Calculate total") {
            return "return items.reduce(0) { $0 + $1.price }"
        } else if prefix.contains("TODO: Add item") {
            return "items.append(item)"
        } else if prefix.contains("TODO: Add content") {
            return """
            Text("Hello, World!")
                .font(.largeTitle)
            """
        } else if prefix.contains("TODO: Double each number") {
            return "$0 * 2"
        } else {
            return "// Your code here"
        }
    }
    
    private func extractContext(from code: String, at position: Int) -> String {
        // Extract meaningful context around cursor
        let lines = code.components(separatedBy: .newlines)
        var currentPos = 0
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.count + 1 // +1 for newline
            if currentPos + lineLength > position {
                // Found the line containing cursor
                let contextStart = max(0, index - 2)
                let contextEnd = min(lines.count - 1, index + 2)
                let contextLines = lines[contextStart...contextEnd]
                return contextLines.joined(separator: "\n")
            }
            currentPos += lineLength
        }
        
        return code
    }
}

// MARK: - Supporting Views

struct ConceptExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fill-in-Middle (FIM) Concept", systemImage: "arrow.left.and.right")
                .font(.headline)
            
            Text("""
            FIM is a powerful code completion technique that uses both the code before (prefix) and after (suffix) the cursor position to generate contextually accurate completions.
            """)
            .font(.subheadline)
            
            HStack(spacing: 20) {
                ConceptCard(
                    title: "Prefix",
                    description: "Code before cursor",
                    color: .blue,
                    icon: "arrow.left"
                )
                
                ConceptCard(
                    title: "Completion",
                    description: "Generated code",
                    color: .green,
                    icon: "wand.and.stars"
                )
                
                ConceptCard(
                    title: "Suffix",
                    description: "Code after cursor",
                    color: .purple,
                    icon: "arrow.right"
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ConceptCard: View {
    let title: String
    let description: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CodeExampleSelector: View {
    @Binding var selectedExample: FIMStructureView.CodeExample
    let onSelect: (FIMStructureView.CodeExample) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code Examples")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FIMStructureView.CodeExample.allCases, id: \.self) { example in
                        Button(action: {
                            selectedExample = example
                            onSelect(example)
                        }) {
                            Text(example.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedExample == example ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedExample == example ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }
}

struct InteractiveFIMView: View {
    let code: String
    @Binding var cursorPosition: Int
    @ObservedObject var demonstrator: FIMDemonstrator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Interactive Code Editor", systemImage: "cursorarrow.motionlines")
                    .font(.headline)
                
                Spacer()
                
                Text("Position: \(cursorPosition)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Code display with cursor
            CodeEditorView(
                code: code,
                cursorPosition: $cursorPosition
            )
            
            // Cursor position slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Adjust Cursor Position")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: Binding(
                    get: { Double(cursorPosition) },
                    set: { cursorPosition = Int($0) }
                ), in: 0...Double(code.count))
            }
        }
    }
}

struct CodeEditorView: View {
    let code: String
    @Binding var cursorPosition: Int
    
    var attributedCode: AttributedString {
        var result = AttributedString(code)
        
        // Highlight cursor position
        if cursorPosition >= 0 && cursorPosition <= code.count {
            let index = result.index(result.startIndex, offsetByCharacters: cursorPosition)
            
            // Add cursor indicator
            var cursor = AttributedString("|")
            cursor.foregroundColor = .red
            cursor.font = .system(.body, design: .monospaced).bold()
            
            result.insert(cursor, at: index)
        }
        
        return result
    }
    
    var body: some View {
        ScrollView {
            Text(attributedCode)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 150)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture { location in
            // Simple tap to position cursor (approximation)
            updateCursorPosition(at: location)
        }
    }
    
    private func updateCursorPosition(at location: CGPoint) {
        // This is a simplified implementation
        // In a real editor, you'd calculate exact character position
        let approximatePosition = Int(location.x / 8) // Rough character width
        cursorPosition = min(max(0, approximatePosition), code.count)
    }
}

struct FIMComponentsView: View {
    let components: FIMDemonstrator.FIMComponents
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FIM Components Breakdown")
                .font(.headline)
            
            // Prefix
            ComponentView(
                title: "Prefix",
                content: components.prefix,
                color: .blue,
                description: "Everything before the cursor"
            )
            
            // Expected completion
            ComponentView(
                title: "Expected Completion",
                content: components.expectedCompletion,
                color: .green,
                description: "What FIM would generate"
            )
            
            // Suffix
            ComponentView(
                title: "Suffix",
                content: components.suffix,
                color: .purple,
                description: "Everything after the cursor"
            )
            
            // Context
            ComponentView(
                title: "Context Window",
                content: components.context,
                color: .orange,
                description: "Surrounding code for better understanding"
            )
        }
    }
}

struct ComponentView: View {
    let title: String
    let content: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(content.isEmpty ? "(empty)" : content)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(color.opacity(0.1))
                    .cornerRadius(6)
            }
            .frame(height: 60)
        }
    }
}

struct HowFIMWorksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How FIM Works", systemImage: "gearshape.2")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                StepView(
                    number: 1,
                    title: "Context Extraction",
                    description: "Extract prefix (before cursor) and suffix (after cursor)"
                )
                
                StepView(
                    number: 2,
                    title: "Special Tokens",
                    description: "Wrap with <｜fim▁begin｜>, <｜fim▁hole｜>, <｜fim▁end｜>"
                )
                
                StepView(
                    number: 3,
                    title: "Model Processing",
                    description: "AI analyzes both contexts to generate completion"
                )
                
                StepView(
                    number: 4,
                    title: "Insertion",
                    description: "Generated code fills the 'hole' between prefix and suffix"
                )
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct FIMBestPracticesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("FIM Best Practices", systemImage: "checkmark.seal")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                PracticeItem(
                    icon: "arrow.left.and.right",
                    text: "Provide sufficient context in both prefix and suffix"
                )
                
                PracticeItem(
                    icon: "doc.text",
                    text: "Include relevant imports and class definitions"
                )
                
                PracticeItem(
                    icon: "curlybraces",
                    text: "Maintain proper syntax structure around the completion point"
                )
                
                PracticeItem(
                    icon: "text.alignleft",
                    text: "Consider indentation and formatting in context"
                )
                
                PracticeItem(
                    icon: "arrow.up.arrow.down",
                    text: "Balance prefix/suffix length for optimal results"
                )
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

struct PracticeItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - App

struct FIMStructureApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                FIMStructureView()
            }
        }
    }
}