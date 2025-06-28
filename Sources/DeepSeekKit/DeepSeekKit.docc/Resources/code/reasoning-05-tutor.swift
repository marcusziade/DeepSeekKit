import SwiftUI
import DeepSeekKit

// Math tutor using reasoning model
struct MathTutorView: View {
    @StateObject private var tutor = MathTutor()
    @State private var selectedTopic: MathTopic = .algebra
    @State private var difficultyLevel: DifficultyLevel = .intermediate
    @State private var currentProblem: String = ""
    @State private var studentAnswer: String = ""
    @State private var showingHint = false
    
    enum MathTopic: String, CaseIterable {
        case algebra = "Algebra"
        case geometry = "Geometry"
        case calculus = "Calculus"
        case statistics = "Statistics"
        case trigonometry = "Trigonometry"
        
        var icon: String {
            switch self {
            case .algebra: return "x.squareroot"
            case .geometry: return "square.on.circle"
            case .calculus: return "function"
            case .statistics: return "chart.bar"
            case .trigonometry: return "triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .algebra: return .blue
            case .geometry: return .green
            case .calculus: return .purple
            case .statistics: return .orange
            case .trigonometry: return .red
            }
        }
    }
    
    enum DifficultyLevel: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var multiplier: Double {
            switch self {
            case .beginner: return 1.0
            case .intermediate: return 1.5
            case .advanced: return 2.0
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Topic selector
                TopicSelector(
                    selectedTopic: $selectedTopic,
                    onTopicChange: { tutor.currentTopic = $0 }
                )
                
                // Difficulty selector
                DifficultySelector(
                    selectedLevel: $difficultyLevel,
                    onLevelChange: { tutor.difficultyLevel = $0 }
                )
                
                // Current problem
                if let session = tutor.currentSession {
                    ProblemCard(
                        session: session,
                        studentAnswer: $studentAnswer,
                        showingHint: $showingHint,
                        onSubmit: submitAnswer,
                        onHint: requestHint,
                        onNewProblem: generateNewProblem
                    )
                } else {
                    StartSessionCard(onStart: startSession)
                }
                
                // Progress tracker
                if !tutor.sessionHistory.isEmpty {
                    ProgressSection(history: tutor.sessionHistory)
                }
                
                // Concept explanations
                if !tutor.conceptExplanations.isEmpty {
                    ConceptExplanationsSection(
                        explanations: tutor.conceptExplanations
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Math Tutor")
    }
    
    private func startSession() {
        Task {
            await tutor.startSession(topic: selectedTopic, difficulty: difficultyLevel)
        }
    }
    
    private func submitAnswer() {
        Task {
            await tutor.checkAnswer(studentAnswer)
            studentAnswer = ""
        }
    }
    
    private func requestHint() {
        Task {
            await tutor.provideHint()
            showingHint = true
        }
    }
    
    private func generateNewProblem() {
        Task {
            await tutor.generateNewProblem()
            showingHint = false
        }
    }
}

// MARK: - Math Tutor Engine

class MathTutor: ObservableObject {
    @Published var currentSession: TutorSession?
    @Published var sessionHistory: [SessionSummary] = []
    @Published var conceptExplanations: [ConceptExplanation] = []
    @Published var isProcessing = false
    
    var currentTopic: MathTutorView.MathTopic = .algebra
    var difficultyLevel: MathTutorView.DifficultyLevel = .intermediate
    
    private let client: DeepSeekClient
    
    // MARK: - Models
    
    struct TutorSession {
        let id = UUID()
        let topic: MathTutorView.MathTopic
        let difficulty: MathTutorView.DifficultyLevel
        let problem: Problem
        var attempts: [Attempt] = []
        var hints: [Hint] = []
        var solution: Solution?
        let startTime: Date
        var endTime: Date?
        
        struct Problem {
            let statement: String
            let concepts: [String]
            let difficulty: Double
            let expectedSteps: Int
        }
        
        struct Attempt {
            let answer: String
            let timestamp: Date
            let isCorrect: Bool
            let feedback: String
            let reasoning: String?
        }
        
        struct Hint {
            let level: Int
            let content: String
            let relatedConcept: String?
        }
        
        struct Solution {
            let steps: [SolutionStep]
            let finalAnswer: String
            let explanation: String
            let reasoning: String
            
            struct SolutionStep {
                let number: Int
                let description: String
                let expression: String?
                let explanation: String
            }
        }
    }
    
    struct SessionSummary {
        let topic: MathTutorView.MathTopic
        let problemsSolved: Int
        let accuracy: Double
        let averageAttempts: Double
        let duration: TimeInterval
        let date: Date
        let strengths: [String]
        let areasToImprove: [String]
    }
    
    struct ConceptExplanation {
        let concept: String
        let explanation: String
        let examples: [Example]
        let relatedProblems: [String]
        
        struct Example {
            let description: String
            let solution: String
        }
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
        loadSessionHistory()
    }
    
    // MARK: - Session Management
    
    @MainActor
    func startSession(topic: MathTutorView.MathTopic, difficulty: MathTutorView.DifficultyLevel) async {
        isProcessing = true
        
        let problem = await generateProblem(topic: topic, difficulty: difficulty)
        
        currentSession = TutorSession(
            topic: topic,
            difficulty: difficulty,
            problem: problem,
            startTime: Date()
        )
        
        isProcessing = false
    }
    
    @MainActor
    func generateNewProblem() async {
        guard let session = currentSession else { return }
        isProcessing = true
        
        let problem = await generateProblem(topic: session.topic, difficulty: session.difficulty)
        
        // Save current session to history
        if !session.attempts.isEmpty {
            addToHistory(session)
        }
        
        // Start new session with same settings
        currentSession = TutorSession(
            topic: session.topic,
            difficulty: session.difficulty,
            problem: problem,
            startTime: Date()
        )
        
        isProcessing = false
    }
    
    private func generateProblem(topic: MathTutorView.MathTopic, difficulty: MathTutorView.DifficultyLevel) async -> TutorSession.Problem {
        let prompt = """
        Generate a \(difficulty.rawValue) level \(topic.rawValue) problem for a student.
        
        Requirements:
        1. Make it appropriate for the difficulty level
        2. Include all necessary information to solve it
        3. Be clear and unambiguous
        4. Focus on understanding, not just computation
        
        Format your response as:
        Problem: [problem statement]
        Concepts: [comma-separated list of mathematical concepts involved]
        Expected Steps: [number of major steps to solve]
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .system, content: "You are an expert math tutor. Create engaging and educational math problems."),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            
            if let content = response.choices.first?.message.content {
                return parseProblem(from: content, topic: topic, difficulty: difficulty)
            }
        } catch {
            print("Error generating problem: \(error)")
        }
        
        // Fallback problem
        return TutorSession.Problem(
            statement: "Solve for x: 2x + 5 = 13",
            concepts: ["linear equations", "algebraic manipulation"],
            difficulty: 1.0,
            expectedSteps: 3
        )
    }
    
    // MARK: - Answer Checking
    
    @MainActor
    func checkAnswer(_ answer: String) async {
        guard var session = currentSession else { return }
        isProcessing = true
        
        let prompt = """
        A student is solving this problem:
        \(session.problem.statement)
        
        The student's answer is: \(answer)
        
        Please:
        1. Check if the answer is correct
        2. If incorrect, identify the error without giving away the answer
        3. Provide constructive feedback
        4. Show your reasoning process for checking the answer
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are a patient math tutor. Check the student's work carefully and provide 
                    helpful feedback. Don't give away the answer if they're wrong.
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                let (isCorrect, feedback) = parseAnswerCheck(choice.message.content)
                
                let attempt = TutorSession.Attempt(
                    answer: answer,
                    timestamp: Date(),
                    isCorrect: isCorrect,
                    feedback: feedback,
                    reasoning: choice.message.reasoningContent
                )
                
                session.attempts.append(attempt)
                
                if isCorrect {
                    // Generate full solution
                    session.solution = await generateSolution(for: session.problem)
                    session.endTime = Date()
                    addToHistory(session)
                }
                
                currentSession = session
            }
        } catch {
            print("Error checking answer: \(error)")
        }
        
        isProcessing = false
    }
    
    // MARK: - Hints
    
    @MainActor
    func provideHint() async {
        guard var session = currentSession else { return }
        isProcessing = true
        
        let hintLevel = session.hints.count + 1
        
        let prompt = """
        Problem: \(session.problem.statement)
        
        The student has made \(session.attempts.count) attempts and needs hint #\(hintLevel).
        
        Provide a hint that:
        1. Guides without giving away the answer
        2. Builds on previous hints: \(session.hints.map { $0.content }.joined(separator: "\n"))
        3. Focuses on understanding the concept
        4. Gets progressively more specific with each hint level
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: "You are a helpful math tutor providing graduated hints."),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.5
            )
            
            let response = try await client.chat.completions(request)
            
            if let content = response.choices.first?.message.content {
                let hint = TutorSession.Hint(
                    level: hintLevel,
                    content: content,
                    relatedConcept: session.problem.concepts.first
                )
                
                session.hints.append(hint)
                currentSession = session
            }
        } catch {
            print("Error generating hint: \(error)")
        }
        
        isProcessing = false
    }
    
    // MARK: - Solution Generation
    
    private func generateSolution(for problem: TutorSession.Problem) async -> TutorSession.Solution? {
        let prompt = """
        Provide a detailed step-by-step solution for:
        \(problem.statement)
        
        Format each step clearly with:
        1. What we're doing
        2. The mathematical expression or calculation
        3. Why we're doing it
        
        Show all reasoning and explain each concept used.
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: "You are an expert math tutor providing clear, educational solutions."),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.3
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                return parseSolution(
                    from: choice.message.content,
                    reasoning: choice.message.reasoningContent ?? ""
                )
            }
        } catch {
            print("Error generating solution: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Concept Explanations
    
    @MainActor
    func explainConcept(_ concept: String) async {
        isProcessing = true
        
        let prompt = """
        Explain the mathematical concept: \(concept)
        
        Include:
        1. Clear definition
        2. Why it's important
        3. 2-3 simple examples
        4. Common mistakes to avoid
        5. Related concepts
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekChat,
                messages: [
                    Message(role: .system, content: "You are an expert math educator. Explain concepts clearly and engagingly."),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.5
            )
            
            let response = try await client.chat.completions(request)
            
            if let content = response.choices.first?.message.content {
                let explanation = parseConceptExplanation(concept: concept, from: content)
                conceptExplanations.append(explanation)
            }
        } catch {
            print("Error explaining concept: \(error)")
        }
        
        isProcessing = false
    }
    
    // MARK: - Parsing Helpers
    
    private func parseProblem(from content: String, topic: MathTutorView.MathTopic, difficulty: MathTutorView.DifficultyLevel) -> TutorSession.Problem {
        // Extract problem components from response
        var statement = ""
        var concepts: [String] = []
        var expectedSteps = 3
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if line.starts(with: "Problem:") {
                statement = line.replacingOccurrences(of: "Problem:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "Concepts:") {
                let conceptString = line.replacingOccurrences(of: "Concepts:", with: "").trimmingCharacters(in: .whitespaces)
                concepts = conceptString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            } else if line.starts(with: "Expected Steps:") {
                let stepsString = line.replacingOccurrences(of: "Expected Steps:", with: "").trimmingCharacters(in: .whitespaces)
                expectedSteps = Int(stepsString) ?? 3
            }
        }
        
        // Ensure we have valid data
        if statement.isEmpty {
            statement = generateDefaultProblem(for: topic, difficulty: difficulty)
        }
        
        if concepts.isEmpty {
            concepts = getDefaultConcepts(for: topic)
        }
        
        return TutorSession.Problem(
            statement: statement,
            concepts: concepts,
            difficulty: difficulty.multiplier,
            expectedSteps: expectedSteps
        )
    }
    
    private func parseAnswerCheck(_ content: String) -> (isCorrect: Bool, feedback: String) {
        let isCorrect = content.lowercased().contains("correct") && !content.lowercased().contains("incorrect")
        return (isCorrect, content)
    }
    
    private func parseSolution(from content: String, reasoning: String) -> TutorSession.Solution {
        var steps: [TutorSession.Solution.SolutionStep] = []
        var finalAnswer = ""
        
        // Parse steps from content
        let lines = content.components(separatedBy: .newlines)
        var currentStep = 1
        var stepDescription = ""
        var stepExpression: String?
        var stepExplanation = ""
        
        for line in lines {
            if line.starts(with: "Step") || line.contains("step \(currentStep)") {
                if !stepDescription.isEmpty {
                    steps.append(TutorSession.Solution.SolutionStep(
                        number: currentStep - 1,
                        description: stepDescription,
                        expression: stepExpression,
                        explanation: stepExplanation
                    ))
                }
                
                currentStep += 1
                stepDescription = line
                stepExpression = nil
                stepExplanation = ""
            } else if line.contains("=") || line.contains("→") {
                stepExpression = line.trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().contains("answer:") || line.lowercased().contains("final") {
                finalAnswer = line
            } else if !line.isEmpty {
                stepExplanation += line + " "
            }
        }
        
        // Add last step
        if !stepDescription.isEmpty {
            steps.append(TutorSession.Solution.SolutionStep(
                number: currentStep - 1,
                description: stepDescription,
                expression: stepExpression,
                explanation: stepExplanation
            ))
        }
        
        return TutorSession.Solution(
            steps: steps,
            finalAnswer: finalAnswer,
            explanation: content,
            reasoning: reasoning
        )
    }
    
    private func parseConceptExplanation(concept: String, from content: String) -> ConceptExplanation {
        // Simplified parsing
        let examples = [
            ConceptExplanation.Example(
                description: "Basic example",
                solution: "Step-by-step solution"
            )
        ]
        
        return ConceptExplanation(
            concept: concept,
            explanation: content,
            examples: examples,
            relatedProblems: []
        )
    }
    
    // MARK: - History Management
    
    private func addToHistory(_ session: TutorSession) {
        let summary = SessionSummary(
            topic: session.topic,
            problemsSolved: 1,
            accuracy: Double(session.attempts.filter { $0.isCorrect }.count) / Double(max(session.attempts.count, 1)),
            averageAttempts: Double(session.attempts.count),
            duration: session.endTime?.timeIntervalSince(session.startTime) ?? 0,
            date: Date(),
            strengths: identifyStrengths(from: session),
            areasToImprove: identifyAreasToImprove(from: session)
        )
        
        sessionHistory.insert(summary, at: 0)
        
        // Keep only last 20 sessions
        if sessionHistory.count > 20 {
            sessionHistory.removeLast()
        }
        
        saveSessionHistory()
    }
    
    private func identifyStrengths(from session: TutorSession) -> [String] {
        var strengths: [String] = []
        
        if session.attempts.count == 1 {
            strengths.append("Solved on first attempt")
        }
        
        if session.hints.isEmpty {
            strengths.append("No hints needed")
        }
        
        return strengths
    }
    
    private func identifyAreasToImprove(from session: TutorSession) -> [String] {
        var areas: [String] = []
        
        if session.attempts.count > 3 {
            areas.append("Consider reviewing \(session.problem.concepts.first ?? "this concept")")
        }
        
        if session.hints.count > 2 {
            areas.append("Practice similar problems")
        }
        
        return areas
    }
    
    private func loadSessionHistory() {
        // Load from UserDefaults or persistent storage
    }
    
    private func saveSessionHistory() {
        // Save to UserDefaults or persistent storage
    }
    
    // MARK: - Default Generators
    
    private func generateDefaultProblem(for topic: MathTutorView.MathTopic, difficulty: MathTutorView.DifficultyLevel) -> String {
        switch topic {
        case .algebra:
            return "Solve for x: 3x + 7 = 22"
        case .geometry:
            return "Find the area of a triangle with base 10 cm and height 6 cm"
        case .calculus:
            return "Find the derivative of f(x) = x² + 3x - 5"
        case .statistics:
            return "Find the mean of the dataset: 12, 15, 18, 20, 22"
        case .trigonometry:
            return "Find sin(30°)"
        }
    }
    
    private func getDefaultConcepts(for topic: MathTutorView.MathTopic) -> [String] {
        switch topic {
        case .algebra:
            return ["equations", "variables", "algebraic manipulation"]
        case .geometry:
            return ["shapes", "area", "perimeter"]
        case .calculus:
            return ["derivatives", "limits", "functions"]
        case .statistics:
            return ["mean", "median", "mode", "data analysis"]
        case .trigonometry:
            return ["angles", "sine", "cosine", "unit circle"]
        }
    }
}

// MARK: - UI Components

struct TopicSelector: View {
    @Binding var selectedTopic: MathTutorView.MathTopic
    let onTopicChange: (MathTutorView.MathTopic) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Topic")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MathTutorView.MathTopic.allCases, id: \.self) { topic in
                        TopicCard(
                            topic: topic,
                            isSelected: selectedTopic == topic,
                            action: {
                                selectedTopic = topic
                                onTopicChange(topic)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct TopicCard: View {
    let topic: MathTutorView.MathTopic
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: topic.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : topic.color)
                
                Text(topic.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? topic.color : Color(.systemGray6))
            )
        }
    }
}

struct DifficultySelector: View {
    @Binding var selectedLevel: MathTutorView.DifficultyLevel
    let onLevelChange: (MathTutorView.DifficultyLevel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty Level")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(MathTutorView.DifficultyLevel.allCases, id: \.self) { level in
                    DifficultyButton(
                        level: level,
                        isSelected: selectedLevel == level,
                        action: {
                            selectedLevel = level
                            onLevelChange(level)
                        }
                    )
                }
            }
        }
    }
}

struct DifficultyButton: View {
    let level: MathTutorView.DifficultyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var starCount: Int {
        switch level {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < starCount ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(isSelected ? .white : .yellow)
                    }
                }
                
                Text(level.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
        }
    }
}

struct StartSessionCard: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 50))
                .foregroundColor(.purple)
            
            Text("Ready to Learn?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a topic and difficulty level, then start solving problems!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onStart) {
                Label("Start Learning", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProblemCard: View {
    let session: MathTutor.TutorSession
    @Binding var studentAnswer: String
    @Binding var showingHint: Bool
    let onSubmit: () -> Void
    let onHint: () -> Void
    let onNewProblem: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Problem header
            HStack {
                Label("Problem", systemImage: "questionmark.circle")
                    .font(.headline)
                
                Spacer()
                
                if !session.problem.concepts.isEmpty {
                    ConceptTags(concepts: session.problem.concepts)
                }
            }
            
            // Problem statement
            Text(session.problem.statement)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            
            // Hints section
            if !session.hints.isEmpty && showingHint {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Hints", systemImage: "lightbulb")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    ForEach(session.hints.indices, id: \.self) { index in
                        HintCard(hint: session.hints[index])
                    }
                }
            }
            
            // Attempts feedback
            if let lastAttempt = session.attempts.last {
                AttemptFeedback(attempt: lastAttempt)
            }
            
            // Answer input
            if session.solution == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Answer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Enter your answer", text: $studentAnswer)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: onSubmit) {
                            Text("Submit")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(studentAnswer.isEmpty)
                    }
                    
                    HStack {
                        Button(action: onHint) {
                            Label("Get Hint", systemImage: "lightbulb")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text("Attempt \(session.attempts.count + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Solution display
                SolutionDisplay(solution: session.solution!)
                
                Button(action: onNewProblem) {
                    Label("Next Problem", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ConceptTags: View {
    let concepts: [String]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(concepts.prefix(2), id: \.self) { concept in
                Text(concept)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(12)
            }
        }
    }
}

struct HintCard: View {
    let hint: MathTutor.TutorSession.Hint
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(hint.level)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.orange))
            
            Text(hint.content)
                .font(.caption)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct AttemptFeedback: View {
    let attempt: MathTutor.TutorSession.Attempt
    @State private var showingReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: attempt.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(attempt.isCorrect ? .green : .red)
                
                Text(attempt.isCorrect ? "Correct!" : "Not quite right")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if attempt.reasoning != nil {
                    Button(action: { showingReasoning.toggle() }) {
                        Text(showingReasoning ? "Hide Reasoning" : "Show Reasoning")
                            .font(.caption)
                    }
                }
            }
            
            Text(attempt.feedback)
                .font(.caption)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(attempt.isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(8)
            
            if showingReasoning, let reasoning = attempt.reasoning {
                ScrollView {
                    Text(reasoning)
                        .font(.caption2)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

struct SolutionDisplay: View {
    let solution: MathTutor.TutorSession.Solution
    @State private var showingReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Solution", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button(action: { showingReasoning.toggle() }) {
                    Text(showingReasoning ? "Hide Reasoning" : "Show Reasoning")
                        .font(.caption)
                }
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 8) {
                ForEach(solution.steps, id: \.number) { step in
                    SolutionStepView(step: step)
                }
            }
            
            // Final answer
            HStack {
                Text("Final Answer:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(solution.finalAnswer)
                    .font(.body)
                    .foregroundColor(.green)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            // Reasoning
            if showingReasoning {
                ScrollView {
                    Text(solution.reasoning)
                        .font(.caption)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct SolutionStepView: View {
    let step: MathTutor.TutorSession.Solution.SolutionStep
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(step.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let expression = step.expression {
                    Text(expression)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
                
                if !step.explanation.isEmpty {
                    Text(step.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ProgressSection: View {
    let history: [MathTutor.SessionSummary]
    @State private var selectedSummary: MathTutor.SessionSummary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Progress")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(history.prefix(5), id: \.date) { summary in
                        ProgressCard(
                            summary: summary,
                            isSelected: selectedSummary?.date == summary.date,
                            action: { selectedSummary = summary }
                        )
                    }
                }
            }
            
            if let summary = selectedSummary {
                ProgressDetail(summary: summary)
            }
        }
    }
}

struct ProgressCard: View {
    let summary: MathTutor.SessionSummary
    let isSelected: Bool
    let action: () -> Void
    
    var accuracyColor: Color {
        if summary.accuracy >= 0.8 { return .green }
        if summary.accuracy >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: summary.topic.icon)
                        .font(.caption)
                        .foregroundColor(summary.topic.color)
                    
                    Text(summary.topic.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label("\(Int(summary.accuracy * 100))%", systemImage: "target")
                        .font(.caption2)
                        .foregroundColor(accuracyColor)
                    
                    Spacer()
                    
                    Text(summary.date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("\(summary.problemsSolved) solved")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 150)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

struct ProgressDetail: View {
    let summary: MathTutor.SessionSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats
            HStack(spacing: 20) {
                StatItem(
                    label: "Accuracy",
                    value: "\(Int(summary.accuracy * 100))%",
                    icon: "target"
                )
                
                StatItem(
                    label: "Avg Attempts",
                    value: String(format: "%.1f", summary.averageAttempts),
                    icon: "arrow.triangle.2.circlepath"
                )
                
                StatItem(
                    label: "Duration",
                    value: formatDuration(summary.duration),
                    icon: "timer"
                )
            }
            
            // Strengths
            if !summary.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Strengths", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    ForEach(summary.strengths, id: \.self) { strength in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                            Text(strength)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            // Areas to improve
            if !summary.areasToImprove.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Areas to Improve", systemImage: "arrow.up.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    ForEach(summary.areasToImprove, id: \.self) { area in
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 4, height: 4)
                            Text(area)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConceptExplanationsSection: View {
    let explanations: [MathTutor.ConceptExplanation]
    @State private var expandedConcept: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept Explanations")
                .font(.headline)
            
            ForEach(explanations, id: \.concept) { explanation in
                ConceptExplanationCard(
                    explanation: explanation,
                    isExpanded: expandedConcept == explanation.concept,
                    onToggle: {
                        expandedConcept = expandedConcept == explanation.concept ? nil : explanation.concept
                    }
                )
            }
        }
    }
}

struct ConceptExplanationCard: View {
    let explanation: MathTutor.ConceptExplanation
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Label(explanation.concept, systemImage: "book")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(explanation.explanation)
                        .font(.caption)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    if !explanation.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Examples")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            ForEach(explanation.examples, id: \.description) { example in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(example.description)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Text(example.solution)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Demo

struct MathTutorDemo: View {
    let apiKey: String
    
    var body: some View {
        MathTutorView()
    }
}