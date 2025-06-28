import SwiftUI
import DeepSeekKit

// Build a math tutor with reasoning - Detailed implementation
struct DetailedMathTutorView: View {
    @StateObject private var tutor = DetailedMathTutor()
    @State private var studentLevel: StudentLevel = .intermediate
    @State private var subject: MathSubject = .algebra
    @State private var sessionMode: SessionMode = .practice
    
    enum StudentLevel: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
        
        var description: String {
            switch self {
            case .beginner: return "Learning fundamentals"
            case .intermediate: return "Building proficiency"
            case .advanced: return "Mastering concepts"
            case .expert: return "Challenging problems"
            }
        }
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .blue
            case .advanced: return .purple
            case .expert: return .red
            }
        }
    }
    
    enum MathSubject: String, CaseIterable {
        case algebra = "Algebra"
        case geometry = "Geometry"
        case calculus = "Calculus"
        case statistics = "Statistics"
        case numberTheory = "Number Theory"
        case linearAlgebra = "Linear Algebra"
        
        var topics: [String] {
            switch self {
            case .algebra:
                return ["Equations", "Inequalities", "Functions", "Polynomials"]
            case .geometry:
                return ["Triangles", "Circles", "Proofs", "Transformations"]
            case .calculus:
                return ["Limits", "Derivatives", "Integrals", "Applications"]
            case .statistics:
                return ["Probability", "Distributions", "Hypothesis Testing", "Regression"]
            case .numberTheory:
                return ["Prime Numbers", "Modular Arithmetic", "Divisibility", "Congruences"]
            case .linearAlgebra:
                return ["Vectors", "Matrices", "Eigenvalues", "Linear Transformations"]
            }
        }
    }
    
    enum SessionMode: String, CaseIterable {
        case practice = "Practice"
        case learn = "Learn"
        case test = "Test"
        case review = "Review"
        
        var icon: String {
            switch self {
            case .practice: return "pencil.circle"
            case .learn: return "book.circle"
            case .test: return "checkmark.circle"
            case .review: return "arrow.clockwise.circle"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Student profile
                StudentProfileSection(
                    level: $studentLevel,
                    tutor: tutor
                )
                
                // Subject and mode selection
                SubjectModeSection(
                    subject: $subject,
                    mode: $sessionMode,
                    onSubjectChange: { tutor.currentSubject = $0 },
                    onModeChange: { tutor.sessionMode = $0 }
                )
                
                // Active session
                if let session = tutor.activeSession {
                    ActiveSessionView(
                        session: session,
                        tutor: tutor
                    )
                } else {
                    SessionStarterView(
                        onStart: startNewSession
                    )
                }
                
                // Learning progress
                if !tutor.learningProgress.isEmpty {
                    LearningProgressSection(
                        progress: tutor.learningProgress
                    )
                }
                
                // Concept map
                if let conceptMap = tutor.conceptMap {
                    ConceptMapView(conceptMap: conceptMap)
                }
            }
            .padding()
        }
        .navigationTitle("Math Tutor")
    }
    
    private func startNewSession() {
        Task {
            await tutor.startSession(
                level: studentLevel,
                subject: subject,
                mode: sessionMode
            )
        }
    }
}

// MARK: - Detailed Math Tutor Engine

class DetailedMathTutor: ObservableObject {
    @Published var activeSession: TutoringSession?
    @Published var learningProgress: [LearningProgress] = []
    @Published var conceptMap: ConceptMap?
    @Published var studentProfile: StudentProfile?
    @Published var isProcessing = false
    
    var currentSubject: DetailedMathTutorView.MathSubject = .algebra
    var sessionMode: DetailedMathTutorView.SessionMode = .practice
    
    private let client: DeepSeekClient
    
    // MARK: - Models
    
    struct TutoringSession {
        let id = UUID()
        let subject: DetailedMathTutorView.MathSubject
        let topic: String
        let level: DetailedMathTutorView.StudentLevel
        let mode: DetailedMathTutorView.SessionMode
        let startTime: Date
        var currentProblem: MathProblem?
        var interactions: [Interaction] = []
        var score: SessionScore
        
        struct MathProblem {
            let statement: String
            let difficulty: Difficulty
            let concepts: [String]
            let hints: [Hint]
            let solution: Solution
            let learningObjectives: [String]
            
            enum Difficulty: Int {
                case easy = 1
                case medium = 2
                case hard = 3
                case challenge = 4
                
                var color: Color {
                    switch self {
                    case .easy: return .green
                    case .medium: return .blue
                    case .hard: return .purple
                    case .challenge: return .red
                    }
                }
            }
            
            struct Hint {
                let level: Int
                let content: String
                let concept: String
                let visual: VisualAid?
                
                struct VisualAid {
                    let type: String // "graph", "diagram", "equation"
                    let description: String
                }
            }
            
            struct Solution {
                let steps: [SolutionStep]
                let finalAnswer: String
                let alternativeMethods: [AlternativeMethod]
                let commonMistakes: [String]
                
                struct SolutionStep {
                    let number: Int
                    let action: String
                    let expression: String
                    let explanation: String
                    let reasoning: String
                }
                
                struct AlternativeMethod {
                    let name: String
                    let description: String
                    let when: String // When to use this method
                }
            }
        }
        
        struct Interaction {
            let timestamp: Date
            let type: InteractionType
            let studentInput: String?
            let tutorResponse: String
            let reasoning: String?
            let feedback: Feedback?
            
            enum InteractionType {
                case attempt, hint, question, explanation, encouragement
            }
            
            struct Feedback {
                let isCorrect: Bool
                let understanding: UnderstandingLevel
                let suggestions: [String]
                
                enum UnderstandingLevel {
                    case full, partial, minimal, none
                    
                    var score: Double {
                        switch self {
                        case .full: return 1.0
                        case .partial: return 0.7
                        case .minimal: return 0.4
                        case .none: return 0.0
                        }
                    }
                }
            }
        }
        
        struct SessionScore {
            var correctAttempts: Int = 0
            var totalAttempts: Int = 0
            var hintsUsed: Int = 0
            var conceptsMastered: Set<String> = []
            var timeSpent: TimeInterval = 0
            
            var accuracy: Double {
                totalAttempts > 0 ? Double(correctAttempts) / Double(totalAttempts) : 0
            }
            
            var efficiency: Double {
                let hintPenalty = Double(hintsUsed) * 0.1
                return max(0, accuracy - hintPenalty)
            }
        }
    }
    
    struct LearningProgress {
        let subject: DetailedMathTutorView.MathSubject
        let topic: String
        let mastery: Double // 0-1
        let lastPracticed: Date
        let totalProblems: Int
        let successRate: Double
        let conceptsLearned: [String]
        let strugglingAreas: [String]
    }
    
    struct ConceptMap {
        let subject: DetailedMathTutorView.MathSubject
        let nodes: [ConceptNode]
        let connections: [Connection]
        
        struct ConceptNode {
            let id: String
            let name: String
            let mastery: Double
            let prerequisites: [String]
            let applications: [String]
        }
        
        struct Connection {
            let from: String
            let to: String
            let strength: Double
            let type: ConnectionType
            
            enum ConnectionType {
                case prerequisite, related, application
            }
        }
    }
    
    struct StudentProfile {
        let id: UUID
        var level: DetailedMathTutorView.StudentLevel
        var strengths: [String]
        var weaknesses: [String]
        var learningStyle: LearningStyle
        var goals: [String]
        var achievements: [Achievement]
        
        enum LearningStyle {
            case visual, auditory, kinesthetic, readingWriting
        }
        
        struct Achievement {
            let title: String
            let description: String
            let date: Date
            let icon: String
        }
    }
    
    init(apiKey: String = "your-api-key") {
        self.client = DeepSeekClient(apiKey: apiKey)
        loadStudentProfile()
        loadLearningProgress()
    }
    
    // MARK: - Session Management
    
    @MainActor
    func startSession(
        level: DetailedMathTutorView.StudentLevel,
        subject: DetailedMathTutorView.MathSubject,
        mode: DetailedMathTutorView.SessionMode
    ) async {
        isProcessing = true
        
        // Select appropriate topic
        let topic = selectTopic(for: subject, level: level, mode: mode)
        
        // Generate problem
        let problem = await generateProblem(
            subject: subject,
            topic: topic,
            level: level,
            mode: mode
        )
        
        // Create session
        activeSession = TutoringSession(
            subject: subject,
            topic: topic,
            level: level,
            mode: mode,
            startTime: Date(),
            currentProblem: problem,
            score: TutoringSession.SessionScore()
        )
        
        // Update concept map
        await updateConceptMap(for: subject)
        
        isProcessing = false
    }
    
    private func selectTopic(
        for subject: DetailedMathTutorView.MathSubject,
        level: DetailedMathTutorView.StudentLevel,
        mode: DetailedMathTutorView.SessionMode
    ) -> String {
        // Smart topic selection based on progress and mode
        let topics = subject.topics
        
        switch mode {
        case .practice:
            // Focus on topics needing practice
            return topics.randomElement() ?? topics[0]
        case .learn:
            // New topics
            return topics.first ?? "Introduction"
        case .test:
            // Mix of topics
            return "Mixed Practice"
        case .review:
            // Previously learned topics
            return topics.last ?? "Review"
        }
    }
    
    // MARK: - Problem Generation
    
    private func generateProblem(
        subject: DetailedMathTutorView.MathSubject,
        topic: String,
        level: DetailedMathTutorView.StudentLevel,
        mode: DetailedMathTutorView.SessionMode
    ) async -> TutoringSession.MathProblem {
        let prompt = createProblemPrompt(
            subject: subject,
            topic: topic,
            level: level,
            mode: mode
        )
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are an expert math tutor. Create educational problems that:
                    1. Match the student's level
                    2. Build understanding step by step
                    3. Include clear learning objectives
                    4. Provide helpful hints without giving away the answer
                    5. Explain common mistakes to avoid
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.7
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                return parseProblem(
                    from: choice.message.content,
                    reasoning: choice.message.reasoningContent,
                    level: level
                )
            }
        } catch {
            print("Problem generation error: \(error)")
        }
        
        // Fallback problem
        return createFallbackProblem(subject: subject, level: level)
    }
    
    private func createProblemPrompt(
        subject: DetailedMathTutorView.MathSubject,
        topic: String,
        level: DetailedMathTutorView.StudentLevel,
        mode: DetailedMathTutorView.SessionMode
    ) -> String {
        """
        Create a \(level.rawValue) level \(subject.rawValue) problem on the topic: \(topic)
        
        Session mode: \(mode.rawValue)
        
        Include:
        1. Clear problem statement
        2. 3-4 progressive hints
        3. Detailed step-by-step solution with reasoning
        4. Alternative solution methods if applicable
        5. Common mistakes students make
        6. Learning objectives
        
        Make it engaging and educational!
        """
    }
    
    // MARK: - Student Interactions
    
    @MainActor
    func submitAnswer(_ answer: String) async {
        guard var session = activeSession else { return }
        isProcessing = true
        
        let result = await checkAnswer(
            answer: answer,
            problem: session.currentProblem!,
            session: session
        )
        
        // Create interaction
        let interaction = TutoringSession.Interaction(
            timestamp: Date(),
            type: .attempt,
            studentInput: answer,
            tutorResponse: result.response,
            reasoning: result.reasoning,
            feedback: result.feedback
        )
        
        session.interactions.append(interaction)
        
        // Update score
        session.score.totalAttempts += 1
        if result.feedback?.isCorrect == true {
            session.score.correctAttempts += 1
            
            // Move to next problem
            if let nextProblem = await generateNextProblem(session: session) {
                session.currentProblem = nextProblem
            } else {
                // Session complete
                completeSession(session)
            }
        }
        
        activeSession = session
        isProcessing = false
    }
    
    @MainActor
    func requestHint() async {
        guard var session = activeSession,
              let problem = session.currentProblem else { return }
        
        isProcessing = true
        
        let hintLevel = session.score.hintsUsed + 1
        let hint = problem.hints[min(hintLevel - 1, problem.hints.count - 1)]
        
        let response = await generateHintResponse(
            hint: hint,
            problem: problem,
            previousInteractions: session.interactions
        )
        
        let interaction = TutoringSession.Interaction(
            timestamp: Date(),
            type: .hint,
            studentInput: nil,
            tutorResponse: response,
            reasoning: nil,
            feedback: nil
        )
        
        session.interactions.append(interaction)
        session.score.hintsUsed += 1
        
        activeSession = session
        isProcessing = false
    }
    
    @MainActor
    func askQuestion(_ question: String) async {
        guard var session = activeSession else { return }
        
        isProcessing = true
        
        let response = await generateQuestionResponse(
            question: question,
            problem: session.currentProblem!,
            session: session
        )
        
        let interaction = TutoringSession.Interaction(
            timestamp: Date(),
            type: .question,
            studentInput: question,
            tutorResponse: response.answer,
            reasoning: response.reasoning,
            feedback: nil
        )
        
        session.interactions.append(interaction)
        activeSession = session
        
        isProcessing = false
    }
    
    // MARK: - Answer Checking
    
    private func checkAnswer(
        answer: String,
        problem: TutoringSession.MathProblem,
        session: TutoringSession
    ) async -> (response: String, reasoning: String?, feedback: TutoringSession.Interaction.Feedback) {
        let prompt = """
        Problem: \(problem.statement)
        Correct answer: \(problem.solution.finalAnswer)
        Student's answer: \(answer)
        
        Previous attempts: \(session.score.totalAttempts)
        
        Analyze the student's answer:
        1. Is it correct?
        2. What's their understanding level?
        3. If wrong, identify the error without revealing the answer
        4. Provide encouraging, educational feedback
        5. Suggest next steps
        """
        
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are a patient, encouraging math tutor. Provide constructive feedback
                    that helps students learn from their mistakes.
                    """),
                    Message(role: .user, content: prompt)
                ],
                temperature: 0.5
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                return parseAnswerCheck(
                    content: choice.message.content,
                    reasoning: choice.message.reasoningContent,
                    correctAnswer: problem.solution.finalAnswer,
                    studentAnswer: answer
                )
            }
        } catch {
            print("Answer check error: \(error)")
        }
        
        // Fallback
        let isCorrect = answer.lowercased() == problem.solution.finalAnswer.lowercased()
        return (
            response: isCorrect ? "Correct! Well done!" : "Not quite right. Let's think about this step by step.",
            reasoning: nil,
            feedback: TutoringSession.Interaction.Feedback(
                isCorrect: isCorrect,
                understanding: isCorrect ? .full : .partial,
                suggestions: ["Review the problem statement", "Try breaking it down into smaller steps"]
            )
        )
    }
    
    // MARK: - Progress Tracking
    
    private func updateLearningProgress(from session: TutoringSession) {
        let progress = LearningProgress(
            subject: session.subject,
            topic: session.topic,
            mastery: calculateMastery(from: session),
            lastPracticed: Date(),
            totalProblems: session.score.totalAttempts,
            successRate: session.score.accuracy,
            conceptsLearned: Array(session.score.conceptsMastered),
            strugglingAreas: identifyStrugglingAreas(from: session)
        )
        
        // Update or add progress
        if let index = learningProgress.firstIndex(where: {
            $0.subject == session.subject && $0.topic == session.topic
        }) {
            learningProgress[index] = progress
        } else {
            learningProgress.append(progress)
        }
    }
    
    private func calculateMastery(from session: TutoringSession) -> Double {
        let accuracy = session.score.accuracy
        let efficiency = session.score.efficiency
        let conceptRatio = Double(session.score.conceptsMastered.count) / 
                          Double(max(session.currentProblem?.concepts.count ?? 1, 1))
        
        return (accuracy + efficiency + conceptRatio) / 3
    }
    
    private func identifyStrugglingAreas(from session: TutoringSession) -> [String] {
        var areas: [String] = []
        
        // Analyze incorrect attempts
        let incorrectAttempts = session.interactions.filter {
            $0.type == .attempt && $0.feedback?.isCorrect == false
        }
        
        // Extract patterns from errors
        // Simplified implementation
        if session.score.accuracy < 0.5 {
            areas.append(session.topic)
        }
        
        if session.score.hintsUsed > 2 {
            areas.append("Problem solving strategy")
        }
        
        return areas
    }
    
    // MARK: - Concept Map
    
    private func updateConceptMap(for subject: DetailedMathTutorView.MathSubject) async {
        // Generate or update concept map
        let nodes = createConceptNodes(for: subject)
        let connections = createConnections(between: nodes)
        
        conceptMap = ConceptMap(
            subject: subject,
            nodes: nodes,
            connections: connections
        )
    }
    
    private func createConceptNodes(for subject: DetailedMathTutorView.MathSubject) -> [ConceptMap.ConceptNode] {
        // Create nodes based on subject topics
        subject.topics.enumerated().map { index, topic in
            ConceptMap.ConceptNode(
                id: "\(subject.rawValue)_\(index)",
                name: topic,
                mastery: calculateTopicMastery(subject: subject, topic: topic),
                prerequisites: index > 0 ? ["\(subject.rawValue)_\(index - 1)"] : [],
                applications: ["Real-world applications", "Advanced topics"]
            )
        }
    }
    
    private func createConnections(between nodes: [ConceptMap.ConceptNode]) -> [ConceptMap.Connection] {
        var connections: [ConceptMap.Connection] = []
        
        // Create prerequisite connections
        for node in nodes {
            for prereq in node.prerequisites {
                connections.append(ConceptMap.Connection(
                    from: prereq,
                    to: node.id,
                    strength: 1.0,
                    type: .prerequisite
                ))
            }
        }
        
        return connections
    }
    
    private func calculateTopicMastery(subject: DetailedMathTutorView.MathSubject, topic: String) -> Double {
        if let progress = learningProgress.first(where: {
            $0.subject == subject && $0.topic == topic
        }) {
            return progress.mastery
        }
        return 0.0
    }
    
    // MARK: - Helper Methods
    
    private func parseProblem(
        from content: String,
        reasoning: String?,
        level: DetailedMathTutorView.StudentLevel
    ) -> TutoringSession.MathProblem {
        // Parse AI response into structured problem
        // Simplified implementation
        
        let difficulty: TutoringSession.MathProblem.Difficulty = {
            switch level {
            case .beginner: return .easy
            case .intermediate: return .medium
            case .advanced: return .hard
            case .expert: return .challenge
            }
        }()
        
        return TutoringSession.MathProblem(
            statement: extractProblemStatement(from: content),
            difficulty: difficulty,
            concepts: extractConcepts(from: content),
            hints: extractHints(from: content),
            solution: extractSolution(from: content),
            learningObjectives: extractObjectives(from: content)
        )
    }
    
    private func extractProblemStatement(from content: String) -> String {
        // Extract problem statement from response
        if let range = content.range(of: "Problem:") {
            let afterProblem = content[range.upperBound...]
            if let endRange = afterProblem.firstIndex(of: "\n\n") {
                return String(afterProblem[..<endRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "Solve for x: 2x + 5 = 13"
    }
    
    private func extractConcepts(from content: String) -> [String] {
        // Extract mathematical concepts
        ["Linear equations", "Algebraic manipulation", "Inverse operations"]
    }
    
    private func extractHints(from content: String) -> [TutoringSession.MathProblem.Hint] {
        // Extract hints from response
        [
            TutoringSession.MathProblem.Hint(
                level: 1,
                content: "What operation would isolate the term with x?",
                concept: "Inverse operations",
                visual: nil
            ),
            TutoringSession.MathProblem.Hint(
                level: 2,
                content: "Try subtracting 5 from both sides first",
                concept: "Equation balance",
                visual: nil
            ),
            TutoringSession.MathProblem.Hint(
                level: 3,
                content: "After subtracting 5, you'll have 2x = 8. What's next?",
                concept: "Division",
                visual: nil
            )
        ]
    }
    
    private func extractSolution(from content: String) -> TutoringSession.MathProblem.Solution {
        // Extract solution steps
        TutoringSession.MathProblem.Solution(
            steps: [
                TutoringSession.MathProblem.Solution.SolutionStep(
                    number: 1,
                    action: "Subtract 5 from both sides",
                    expression: "2x + 5 - 5 = 13 - 5",
                    explanation: "To isolate the term with x",
                    reasoning: "Using inverse operations to maintain equation balance"
                ),
                TutoringSession.MathProblem.Solution.SolutionStep(
                    number: 2,
                    action: "Simplify",
                    expression: "2x = 8",
                    explanation: "Combining like terms",
                    reasoning: "5 - 5 = 0, and 13 - 5 = 8"
                ),
                TutoringSession.MathProblem.Solution.SolutionStep(
                    number: 3,
                    action: "Divide both sides by 2",
                    expression: "2x/2 = 8/2",
                    explanation: "To solve for x",
                    reasoning: "Dividing by the coefficient of x"
                ),
                TutoringSession.MathProblem.Solution.SolutionStep(
                    number: 4,
                    action: "Simplify to get the answer",
                    expression: "x = 4",
                    explanation: "Final answer",
                    reasoning: "2x/2 = x, and 8/2 = 4"
                )
            ],
            finalAnswer: "x = 4",
            alternativeMethods: [
                TutoringSession.MathProblem.Solution.AlternativeMethod(
                    name: "Mental math",
                    description: "Recognize that 2×4 + 5 = 13",
                    when: "When numbers are simple"
                )
            ],
            commonMistakes: [
                "Forgetting to apply operations to both sides",
                "Making arithmetic errors",
                "Not checking the answer"
            ]
        )
    }
    
    private func extractObjectives(from content: String) -> [String] {
        [
            "Understand equation balance",
            "Apply inverse operations",
            "Solve linear equations",
            "Verify solutions"
        ]
    }
    
    private func createFallbackProblem(
        subject: DetailedMathTutorView.MathSubject,
        level: DetailedMathTutorView.StudentLevel
    ) -> TutoringSession.MathProblem {
        // Create a simple fallback problem
        TutoringSession.MathProblem(
            statement: "Solve: 3x - 7 = 14",
            difficulty: .medium,
            concepts: ["Linear equations"],
            hints: [
                TutoringSession.MathProblem.Hint(
                    level: 1,
                    content: "Start by adding 7 to both sides",
                    concept: "Inverse operations",
                    visual: nil
                )
            ],
            solution: TutoringSession.MathProblem.Solution(
                steps: [],
                finalAnswer: "x = 7",
                alternativeMethods: [],
                commonMistakes: []
            ),
            learningObjectives: ["Solve linear equations"]
        )
    }
    
    private func parseAnswerCheck(
        content: String,
        reasoning: String?,
        correctAnswer: String,
        studentAnswer: String
    ) -> (response: String, reasoning: String?, feedback: TutoringSession.Interaction.Feedback) {
        let isCorrect = content.lowercased().contains("correct")
        
        let understanding: TutoringSession.Interaction.Feedback.UnderstandingLevel = {
            if isCorrect { return .full }
            if content.lowercased().contains("close") { return .partial }
            if content.lowercased().contains("confused") { return .minimal }
            return .partial
        }()
        
        let suggestions = [
            "Check your arithmetic",
            "Review the problem statement",
            "Think about what the question is asking"
        ].filter { _ in !isCorrect }
        
        return (
            response: content,
            reasoning: reasoning,
            feedback: TutoringSession.Interaction.Feedback(
                isCorrect: isCorrect,
                understanding: understanding,
                suggestions: suggestions
            )
        )
    }
    
    private func generateHintResponse(
        hint: TutoringSession.MathProblem.Hint,
        problem: TutoringSession.MathProblem,
        previousInteractions: [TutoringSession.Interaction]
    ) async -> String {
        // Generate contextual hint response
        """
        Here's a hint: \(hint.content)
        
        This relates to the concept of \(hint.concept).
        Take your time and think about how this applies to the problem.
        """
    }
    
    private func generateQuestionResponse(
        question: String,
        problem: TutoringSession.MathProblem,
        session: TutoringSession
    ) async -> (answer: String, reasoning: String?) {
        // Generate response to student question
        do {
            let request = ChatCompletionRequest(
                model: .deepSeekReasoner,
                messages: [
                    Message(role: .system, content: """
                    You are a helpful math tutor. Answer the student's question
                    in a way that guides them toward understanding without
                    giving away the answer directly.
                    """),
                    Message(role: .user, content: """
                    Problem: \(problem.statement)
                    Student's question: \(question)
                    
                    Provide a helpful response that encourages learning.
                    """)
                ],
                temperature: 0.5
            )
            
            let response = try await client.chat.completions(request)
            
            if let choice = response.choices.first {
                return (choice.message.content, choice.message.reasoningContent)
            }
        } catch {
            print("Question response error: \(error)")
        }
        
        return ("That's a great question! Let me help you think through it...", nil)
    }
    
    private func generateNextProblem(session: TutoringSession) async -> TutoringSession.MathProblem? {
        // Generate next problem based on performance
        if session.score.accuracy > 0.8 {
            // Increase difficulty
            return await generateProblem(
                subject: session.subject,
                topic: session.topic,
                level: session.level,
                mode: session.mode
            )
        } else if session.score.accuracy < 0.5 {
            // Provide easier problem
            return await generateProblem(
                subject: session.subject,
                topic: session.topic,
                level: .beginner,
                mode: .practice
            )
        }
        
        return nil
    }
    
    private func completeSession(_ session: TutoringSession) {
        // Update progress
        updateLearningProgress(from: session)
        
        // Clear active session
        activeSession = nil
        
        // Save progress
        saveLearningProgress()
    }
    
    // MARK: - Persistence
    
    private func loadStudentProfile() {
        // Load from storage
    }
    
    private func loadLearningProgress() {
        // Load from storage
    }
    
    private func saveLearningProgress() {
        // Save to storage
    }
}

// MARK: - UI Components

struct StudentProfileSection: View {
    @Binding var level: DetailedMathTutorView.StudentLevel
    let tutor: DetailedMathTutor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Student Profile")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Circle()
                            .fill(level.color)
                            .frame(width: 12, height: 12)
                        
                        Text(level.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(level.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Level selector
                Menu {
                    ForEach(DetailedMathTutorView.StudentLevel.allCases, id: \.self) { lvl in
                        Button(action: { level = lvl }) {
                            Label(lvl.rawValue, systemImage: "star.fill")
                        }
                    }
                } label: {
                    Label("Change", systemImage: "chevron.down.circle")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct SubjectModeSection: View {
    @Binding var subject: DetailedMathTutorView.MathSubject
    @Binding var mode: DetailedMathTutorView.SessionMode
    let onSubjectChange: (DetailedMathTutorView.MathSubject) -> Void
    let onModeChange: (DetailedMathTutorView.SessionMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subject selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Subject")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DetailedMathTutorView.MathSubject.allCases, id: \.self) { subj in
                            SubjectChip(
                                subject: subj,
                                isSelected: subject == subj,
                                action: {
                                    subject = subj
                                    onSubjectChange(subj)
                                }
                            )
                        }
                    }
                }
            }
            
            // Mode selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Mode")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(DetailedMathTutorView.SessionMode.allCases, id: \.self) { m in
                        ModeButton(
                            mode: m,
                            isSelected: mode == m,
                            action: {
                                mode = m
                                onModeChange(m)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct SubjectChip: View {
    let subject: DetailedMathTutorView.MathSubject
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(subject.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ModeButton: View {
    let mode: DetailedMathTutorView.SessionMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .secondary)
                
                Text(mode.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct SessionStarterView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 50))
                .foregroundColor(.purple)
            
            Text("Ready to Learn Math?")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a personalized tutoring session tailored to your level and learning goals")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onStart) {
                Label("Start Session", systemImage: "play.fill")
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

struct ActiveSessionView: View {
    let session: DetailedMathTutor.TutoringSession
    let tutor: DetailedMathTutor
    @State private var studentAnswer = ""
    @State private var studentQuestion = ""
    @State private var showingHints = false
    @State private var showingSolution = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Session header
            SessionHeaderView(session: session)
            
            // Problem
            if let problem = session.currentProblem {
                ProblemView(
                    problem: problem,
                    showingHints: $showingHints,
                    showingSolution: $showingSolution
                )
                
                // Interactions
                if !session.interactions.isEmpty {
                    InteractionsView(interactions: session.interactions)
                }
                
                // Input area
                StudentInputView(
                    answer: $studentAnswer,
                    question: $studentQuestion,
                    onSubmitAnswer: {
                        Task {
                            await tutor.submitAnswer(studentAnswer)
                            studentAnswer = ""
                        }
                    },
                    onRequestHint: {
                        Task {
                            await tutor.requestHint()
                            showingHints = true
                        }
                    },
                    onAskQuestion: {
                        Task {
                            await tutor.askQuestion(studentQuestion)
                            studentQuestion = ""
                        }
                    },
                    isProcessing: tutor.isProcessing
                )
            }
        }
    }
}

struct SessionHeaderView: View {
    let session: DetailedMathTutor.TutoringSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.subject.rawValue)
                        .font(.headline)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(session.topic)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Label("\(session.score.correctAttempts)/\(session.score.totalAttempts)", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Label("\(session.score.hintsUsed) hints", systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Label(session.mode.rawValue, systemImage: session.mode.icon)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Timer
            Text(session.startTime, style: .timer)
                .font(.caption)
                .padding(6)
                .background(Color(.systemGray5))
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ProblemView: View {
    let problem: DetailedMathTutor.TutoringSession.MathProblem
    @Binding var showingHints: Bool
    @Binding var showingSolution: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Problem statement
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Problem", systemImage: "questionmark.circle")
                        .font(.headline)
                    
                    Spacer()
                    
                    DifficultyBadge(difficulty: problem.difficulty)
                }
                
                Text(problem.statement)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Learning objectives
            if !problem.learningObjectives.isEmpty {
                DisclosureGroup("Learning Objectives") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(problem.learningObjectives, id: \.self) { objective in
                            HStack {
                                Image(systemName: "target")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(objective)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.subheadline)
            }
            
            // Concepts
            if !problem.concepts.isEmpty {
                HStack {
                    Text("Concepts:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(problem.concepts, id: \.self) { concept in
                        Text(concept)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
}

struct DifficultyBadge: View {
    let difficulty: DetailedMathTutor.TutoringSession.MathProblem.Difficulty
    
    var text: String {
        switch difficulty {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .challenge: return "Challenge"
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                Image(systemName: level <= difficulty.rawValue ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(difficulty.color)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(difficulty.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(difficulty.color.opacity(0.2))
        .cornerRadius(12)
    }
}

struct InteractionsView: View {
    let interactions: [DetailedMathTutor.TutoringSession.Interaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(interactions.indices, id: \.self) { index in
                        InteractionRow(interaction: interactions[index])
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
}

struct InteractionRow: View {
    let interaction: DetailedMathTutor.TutoringSession.Interaction
    
    var icon: String {
        switch interaction.type {
        case .attempt: return "pencil.circle"
        case .hint: return "lightbulb"
        case .question: return "questionmark.bubble"
        case .explanation: return "text.bubble"
        case .encouragement: return "star"
        }
    }
    
    var color: Color {
        switch interaction.type {
        case .attempt:
            return interaction.feedback?.isCorrect == true ? .green : .red
        case .hint: return .orange
        case .question: return .blue
        case .explanation: return .purple
        case .encouragement: return .yellow
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                if let input = interaction.studentInput {
                    Text("You: \(input)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Text(interaction.tutorResponse)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let feedback = interaction.feedback {
                    HStack {
                        if feedback.isCorrect {
                            Label("Correct!", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        
                        Text("Understanding: \(Int(feedback.understanding.score * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(interaction.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.tertiary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct StudentInputView: View {
    @Binding var answer: String
    @Binding var question: String
    let onSubmitAnswer: () -> Void
    let onRequestHint: () -> Void
    let onAskQuestion: () -> Void
    let isProcessing: Bool
    
    @State private var inputMode: InputMode = .answer
    
    enum InputMode {
        case answer, question
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Mode selector
            Picker("Input Mode", selection: $inputMode) {
                Text("Answer").tag(InputMode.answer)
                Text("Question").tag(InputMode.question)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Input field
            HStack {
                switch inputMode {
                case .answer:
                    TextField("Enter your answer", text: $answer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit(onSubmitAnswer)
                    
                    Button(action: onSubmitAnswer) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(answer.isEmpty || isProcessing)
                    
                case .question:
                    TextField("Ask a question", text: $question)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit(onAskQuestion)
                    
                    Button(action: onAskQuestion) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Ask")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(question.isEmpty || isProcessing)
                }
            }
            
            // Helper buttons
            HStack {
                Button(action: onRequestHint) {
                    Label("Get Hint", systemImage: "lightbulb")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
                
                Spacer()
                
                Button(action: {}) {
                    Label("Show Solution", systemImage: "eye")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
        }
    }
}

struct LearningProgressSection: View {
    let progress: [DetailedMathTutor.LearningProgress]
    @State private var selectedSubject: DetailedMathTutorView.MathSubject?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learning Progress")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(progress, id: \.topic) { prog in
                        ProgressCard(
                            progress: prog,
                            isSelected: selectedSubject == prog.subject,
                            onTap: { selectedSubject = prog.subject }
                        )
                    }
                }
            }
            
            if let subject = selectedSubject,
               let subjectProgress = progress.filter({ $0.subject == subject }) {
                SubjectProgressDetail(progress: subjectProgress)
            }
        }
    }
}

struct ProgressCard: View {
    let progress: DetailedMathTutor.LearningProgress
    let isSelected: Bool
    let onTap: () -> Void
    
    var masteryColor: Color {
        if progress.mastery >= 0.8 { return .green }
        if progress.mastery >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(progress.topic)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    CircularProgressView(
                        progress: progress.mastery,
                        color: masteryColor,
                        lineWidth: 4
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("\(Int(progress.mastery * 100))")
                            .font(.caption2)
                            .fontWeight(.bold)
                    )
                }
                
                HStack {
                    Label("\(progress.totalProblems)", systemImage: "doc.text")
                        .font(.caption)
                    
                    Spacer()
                    
                    Label("\(Int(progress.successRate * 100))%", systemImage: "percent")
                        .font(.caption)
                        .foregroundColor(masteryColor)
                }
                
                Text(progress.lastPracticed, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 180)
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

struct SubjectProgressDetail: View {
    let progress: [DetailedMathTutor.LearningProgress]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Concepts learned
            if let concepts = progress.flatMap({ $0.conceptsLearned }).unique() {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Concepts Mastered", systemImage: "checkmark.seal")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(concepts, id: \.self) { concept in
                            Text(concept)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Struggling areas
            if let areas = progress.flatMap({ $0.strugglingAreas }).unique() {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Areas for Improvement", systemImage: "arrow.up.circle")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    ForEach(areas, id: \.self) { area in
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 4, height: 4)
                            Text(area)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ConceptMapView: View {
    let conceptMap: DetailedMathTutor.ConceptMap
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept Map")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                ConceptMapVisualization(conceptMap: conceptMap)
                    .frame(height: 200)
            }
        }
    }
}

struct ConceptMapVisualization: View {
    let conceptMap: DetailedMathTutor.ConceptMap
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw connections
                ForEach(conceptMap.connections, id: \.from) { connection in
                    if let fromNode = conceptMap.nodes.first(where: { $0.id == connection.from }),
                       let toNode = conceptMap.nodes.first(where: { $0.id == connection.to }) {
                        Path { path in
                            let fromPos = nodePosition(for: fromNode, in: geometry.size)
                            let toPos = nodePosition(for: toNode, in: geometry.size)
                            path.move(to: fromPos)
                            path.addLine(to: toPos)
                        }
                        .stroke(
                            connection.type == .prerequisite ? Color.blue : Color.gray,
                            lineWidth: CGFloat(connection.strength * 2)
                        )
                    }
                }
                
                // Draw nodes
                ForEach(conceptMap.nodes, id: \.id) { node in
                    ConceptNodeView(node: node)
                        .position(nodePosition(for: node, in: geometry.size))
                }
            }
        }
    }
    
    private func nodePosition(for node: DetailedMathTutor.ConceptMap.ConceptNode, in size: CGSize) -> CGPoint {
        // Simple linear layout
        if let index = conceptMap.nodes.firstIndex(where: { $0.id == node.id }) {
            let spacing = size.width / CGFloat(conceptMap.nodes.count + 1)
            let x = spacing * CGFloat(index + 1)
            let y = size.height / 2
            return CGPoint(x: x, y: y)
        }
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

struct ConceptNodeView: View {
    let node: DetailedMathTutor.ConceptMap.ConceptNode
    
    var masteryColor: Color {
        if node.mastery >= 0.8 { return .green }
        if node.mastery >= 0.5 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: node.mastery)
                    .stroke(masteryColor, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(node.mastery * 100))")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            
            Text(node.name)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
    }
}

// MARK: - Helper Extensions

extension Array where Element: Hashable {
    func unique() -> [Element] {
        Array(Set(self))
    }
}

extension CircularProgressView {
    init(progress: Double, color: Color, lineWidth: CGFloat) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }
    
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.5), color]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Demo

struct DetailedMathTutorDemo: View {
    var body: some View {
        DetailedMathTutorView()
    }
}