#!/usr/bin/env swift

import Foundation

let indexHTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DeepSeekKit - Swift SDK for DeepSeek AI</title>
    <meta name="description" content="A modern Swift SDK for integrating DeepSeek's powerful AI models into your applications. Build intelligent apps with streaming, function calling, and reasoning capabilities.">
    <meta property="og:title" content="DeepSeekKit - Swift SDK for DeepSeek AI">
    <meta property="og:description" content="Build AI-powered Swift apps with DeepSeekKit. Native support for all Apple platforms and Linux.">
    <meta property="og:image" content="https://raw.githubusercontent.com/marcusziade/DeepSeekKit/main/assets/social-preview.png">
    <meta property="og:url" content="https://marcusziade.github.io/DeepSeekKit/">
    <meta name="twitter:card" content="summary_large_image">
    <link rel="icon" type="image/png" href="favicon.png">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #1d1d1f;
            background: #000;
            overflow-x: hidden;
        }
        
        .hero {
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%);
            background-size: 400% 400%;
            animation: gradientShift 15s ease infinite;
        }
        
        @keyframes gradientShift {
            0% { background-position: 0% 50%; }
            50% { background-position: 100% 50%; }
            100% { background-position: 0% 50%; }
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 24px;
            position: relative;
            z-index: 1;
        }
        
        .hero-content {
            text-align: center;
            color: white;
        }
        
        .logo {
            width: 120px;
            height: 120px;
            margin: 0 auto 32px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 30px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 60px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        h1 {
            font-size: clamp(48px, 8vw, 72px);
            font-weight: 700;
            margin-bottom: 24px;
            letter-spacing: -0.02em;
            text-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }
        
        .subtitle {
            font-size: clamp(20px, 3vw, 24px);
            font-weight: 400;
            margin-bottom: 48px;
            opacity: 0.95;
            max-width: 600px;
            margin-left: auto;
            margin-right: auto;
        }
        
        .buttons {
            display: flex;
            gap: 16px;
            justify-content: center;
            flex-wrap: wrap;
        }
        
        .button {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 16px 32px;
            font-size: 18px;
            font-weight: 600;
            text-decoration: none;
            border-radius: 12px;
            transition: all 0.3s ease;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }
        
        .button-primary {
            background: white;
            color: #667eea;
        }
        
        .button-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
        }
        
        .button-secondary {
            background: rgba(255, 255, 255, 0.2);
            color: white;
            backdrop-filter: blur(10px);
            border: 2px solid rgba(255, 255, 255, 0.3);
        }
        
        .button-secondary:hover {
            background: rgba(255, 255, 255, 0.3);
            border-color: rgba(255, 255, 255, 0.5);
        }
        
        .features {
            padding: 120px 0;
            background: #f5f5f7;
        }
        
        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
            gap: 40px;
            margin-top: 64px;
        }
        
        .feature-card {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.06);
            transition: all 0.3s ease;
        }
        
        .feature-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
        }
        
        .feature-icon {
            width: 60px;
            height: 60px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 28px;
            margin-bottom: 24px;
        }
        
        .feature-title {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 12px;
            color: #1d1d1f;
        }
        
        .feature-description {
            color: #86868b;
            line-height: 1.6;
        }
        
        .section-title {
            font-size: clamp(36px, 5vw, 48px);
            font-weight: 700;
            text-align: center;
            margin-bottom: 24px;
            color: #1d1d1f;
        }
        
        .section-subtitle {
            font-size: 20px;
            text-align: center;
            color: #86868b;
            max-width: 600px;
            margin: 0 auto;
        }
        
        .platforms {
            padding: 80px 0;
            background: white;
        }
        
        .platform-icons {
            display: flex;
            justify-content: center;
            gap: 40px;
            flex-wrap: wrap;
            margin-top: 48px;
        }
        
        .platform-icon {
            width: 80px;
            height: 80px;
            background: #f5f5f7;
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
            transition: all 0.3s ease;
        }
        
        .platform-icon:hover {
            background: linear-gradient(135deg, #667eea, #764ba2);
            transform: scale(1.1);
        }
        
        @media (max-width: 768px) {
            .buttons {
                flex-direction: column;
                align-items: center;
            }
            
            .button {
                width: 100%;
                max-width: 280px;
                justify-content: center;
            }
        }
        
        .gradient-text {
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .code-example {
            background: #1d1d1f;
            color: #f5f5f7;
            padding: 32px;
            border-radius: 16px;
            margin: 64px 0;
            overflow-x: auto;
            font-family: 'SF Mono', Consolas, monospace;
            font-size: 14px;
            line-height: 1.6;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .keyword { color: #fc5fa3; }
        .string { color: #fc6a5d; }
        .type { color: #5dd8ff; }
        .function { color: #a167e6; }
        .comment { color: #6c7986; }
    </style>
</head>
<body>
    <section class="hero">
        <div class="container">
            <div class="hero-content">
                <div class="logo">🤖</div>
                <h1>DeepSeekKit</h1>
                <p class="subtitle">
                    A modern Swift SDK for integrating DeepSeek's powerful AI models into your applications
                </p>
                <div class="buttons">
                    <a href="documentation/deepseekkit/" class="button button-primary">
                        <span>📖</span>
                        View Documentation
                    </a>
                    <a href="documentation/deepseekkit" class="button button-secondary">
                        <span>🎓</span>
                        Browse Tutorials
                    </a>
                </div>
            </div>
        </div>
    </section>
    
    <section class="features">
        <div class="container">
            <h2 class="section-title">Build <span class="gradient-text">Intelligent Apps</span></h2>
            <p class="section-subtitle">Everything you need to create AI-powered Swift applications</p>
            
            <div class="features-grid">
                <div class="feature-card">
                    <div class="feature-icon">🔒</div>
                    <h3 class="feature-title">Type-Safe API</h3>
                    <p class="feature-description">
                        Leverage Swift's type system for compile-time safety and better developer experience with full autocomplete support.
                    </p>
                </div>
                
                <div class="feature-card">
                    <div class="feature-icon">⚡</div>
                    <h3 class="feature-title">Native Streaming</h3>
                    <p class="feature-description">
                        Platform-optimized streaming with URLSession for Apple platforms and cURL for Linux. Real-time responses out of the box.
                    </p>
                </div>
                
                <div class="feature-card">
                    <div class="feature-icon">🧠</div>
                    <h3 class="feature-title">Reasoning Model</h3>
                    <p class="feature-description">
                        Access DeepSeek's reasoning model for transparent problem-solving with step-by-step explanations.
                    </p>
                </div>
                
                <div class="feature-card">
                    <div class="feature-icon">🛠️</div>
                    <h3 class="feature-title">Function Calling</h3>
                    <p class="feature-description">
                        Build AI agents that can interact with your code. Define tools and let the AI orchestrate complex workflows.
                    </p>
                </div>
                
                <div class="feature-card">
                    <div class="feature-icon">💻</div>
                    <h3 class="feature-title">Code Completion</h3>
                    <p class="feature-description">
                        Fill-in-Middle support for intelligent code completion with context awareness from both prefix and suffix.
                    </p>
                </div>
                
                <div class="feature-card">
                    <div class="feature-icon">📦</div>
                    <h3 class="feature-title">Zero Dependencies</h3>
                    <p class="feature-description">
                        Pure Swift implementation with no external dependencies. Clean, maintainable, and easy to integrate.
                    </p>
                </div>
            </div>
            
            <div class="code-example">
                <span class="keyword">import</span> <span class="type">DeepSeekKit</span><br><br>
                <span class="keyword">let</span> client = <span class="type">DeepSeekClient</span>(apiKey: <span class="string">"your-api-key"</span>)<br><br>
                <span class="comment">// Simple chat completion</span><br>
                <span class="keyword">let</span> response = <span class="keyword">try await</span> client.chat.<span class="function">createCompletion</span>(<br>
                &nbsp;&nbsp;&nbsp;&nbsp;<span class="type">ChatCompletionRequest</span>(<br>
                &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;model: .<span class="function">chat</span>,<br>
                &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;messages: [.<span class="function">user</span>(<span class="string">"Explain quantum computing in simple terms"</span>)]<br>
                &nbsp;&nbsp;&nbsp;&nbsp;)<br>
                )<br><br>
                <span class="comment">// Streaming responses</span><br>
                <span class="keyword">for try await</span> chunk <span class="keyword">in</span> client.chat.<span class="function">createStreamingCompletion</span>(request) {<br>
                &nbsp;&nbsp;&nbsp;&nbsp;<span class="function">print</span>(chunk.choices.first?.delta.content ?? <span class="string">""</span>)<br>
                }
            </div>
        </div>
    </section>
    
    <section class="platforms">
        <div class="container">
            <h2 class="section-title">Multi-Platform Support</h2>
            <p class="section-subtitle">Build once, deploy everywhere</p>
            
            <div class="platform-icons">
                <div class="platform-icon">📱</div>
                <div class="platform-icon">💻</div>
                <div class="platform-icon">📺</div>
                <div class="platform-icon">⌚</div>
                <div class="platform-icon">🥽</div>
                <div class="platform-icon">🐧</div>
            </div>
        </div>
    </section>
    
    <script>
        // Add smooth scroll behavior
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                document.querySelector(this.getAttribute('href')).scrollIntoView({
                    behavior: 'smooth'
                });
            });
        });
    </script>
</body>
</html>
"""

// Write the index.html file
let fileURL = URL(fileURLWithPath: "docs/index.html")
try indexHTML.write(to: fileURL, atomically: true, encoding: .utf8)
print("✅ Created docs/index.html successfully!")