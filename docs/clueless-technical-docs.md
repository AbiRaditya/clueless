# Technical Documentation

## ClueLess - AI Desktop Assistant for macOS

**Version:** 1.0  
**Date:** October 2025  
**Status:** Technical Specification

---

## 1. System Architecture Overview

### 1.1 High-Level Architecture

ClueLess follows a modular, event-driven architecture designed for real-time performance and privacy protection. The system consists of five primary layers:

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface Layer                 │
│  (Invisible Overlay, Settings Panel, Quick Actions)    │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                   Application Layer                     │
│    (Main App, Window Manager, Event Coordinator)       │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    Service Layer                        │
│ (Screen Analyzer, Audio Processor, AI Engine, KB Mgr)  │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    Integration Layer                    │
│    (macOS APIs, External APIs, Local AI Models)        │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                     Data Layer                          │
│  (Local Storage, Vector DB, Configuration, Cache)      │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Core Components

#### Screen Analysis Engine

- **Technology**: Vision Framework + Custom OCR Pipeline
- **Function**: Real-time text extraction and content analysis
- **Performance**: <100ms processing latency, 95%+ accuracy
- **Privacy**: All processing occurs locally, no data transmitted

#### Audio Intelligence System

- **Technology**: Speech Framework + BlackHole Audio Driver
- **Function**: System audio capture and real-time transcription
- **Performance**: <3s transcription delay, 90%+ accuracy
- **Privacy**: No network transmission, local speech models

#### AI Response Engine

- **Technology**: Modular LLM integration with local fallback
- **Function**: Context-aware response generation
- **Performance**: <2s response time, intelligent caching
- **Privacy**: Local model option, encrypted API communications

#### Invisible Overlay System

- **Technology**: Custom NSWindow with CGWindowLevel manipulation
- **Function**: Undetectable screen overlay rendering
- **Performance**: Hardware-accelerated rendering, minimal CPU impact
- **Privacy**: Invisible to screen capture APIs and recording software

---

## 2. macOS Integration Details

### 2.1 System Permissions Required

#### Screen Recording Permission

```swift
// Request screen recording permission
func requestScreenRecordingPermission() {
    let options: [CFString: Any] = [
        kCGWindowListExcludeDesktopElements: true,
        kCGWindowListOptionOnScreenOnly: true
    ]

    let windowList = CGWindowListCopyWindowInfo(
        CGWindowListOption(rawValue: 0),
        kCGNullWindowID
    )

    // Permission automatically granted if list contains windows
}
```

#### Accessibility Permission (Optional)

```swift
// For enhanced screen analysis capabilities
func requestAccessibilityPermission() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    return trusted
}
```

#### Microphone Permission (Optional)

```swift
// For voice command features
func requestMicrophonePermission() async -> Bool {
    return await AVAudioSession.sharedInstance().requestRecordPermission()
}
```

### 2.2 Invisible Window Implementation

#### Window Level Configuration

```swift
class InvisibleOverlayWindow: NSWindow {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask,
                  backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless],
                   backing: backing, defer: flag)

        // Critical: Set window level above everything but below menu bar
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Prevent window from appearing in mission control, dock, etc.
        self.isExcludedFromWindowsMenu = true
        self.sharingType = .none
    }
}
```

#### Screen Capture Invisibility

```swift
extension InvisibleOverlayWindow {
    func makeInvisibleToScreenCapture() {
        // Use private API to exclude from screen recordings
        let windowNumber = self.windowNumber

        // This prevents the window from appearing in screen captures
        CGSSetWindowProperty(CGSMainConnectionID(),
                           CGWindowID(windowNumber),
                           kCGSWindowProperty,
                           kCGSWindowPropertyExcludeFromScreenshots)
    }
}
```

### 2.3 Screen Capture and OCR Pipeline

#### Real-time Screen Monitoring

```swift
class ScreenAnalyzer {
    private var displayTimer: Timer?
    private let ocrQueue = DispatchQueue(label: "com.clueless.ocr", qos: .userInteractive)

    func startMonitoring() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.captureAndAnalyzeScreen()
        }
    }

    private func captureAndAnalyzeScreen() {
        ocrQueue.async {
            let image = self.captureScreen()
            let text = self.performOCR(on: image)
            let analysis = self.analyzeContent(text)

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .screenContentUpdated,
                    object: analysis
                )
            }
        }
    }
}
```

#### OCR Implementation with Vision Framework

```swift
import Vision

extension ScreenAnalyzer {
    func performOCR(on image: CGImage) -> String {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: " ")

            self?.processRecognizedText(recognizedText)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }
}
```

### 2.4 Audio Capture System

#### BlackHole Audio Driver Integration

```swift
import AVFoundation

class AudioCaptureManager {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    func setupAudioCapture() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        inputNode = audioEngine.inputNode
        let inputFormat = inputNode?.outputFormat(forBus: 0)

        // Install tap to capture system audio
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        try? audioEngine.start()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert to text using Speech framework
        speechRecognizer.transcribe(buffer) { [weak self] result in
            self?.handleTranscriptionResult(result)
        }
    }
}
```

#### Speech Recognition Integration

```swift
import Speech

class SpeechTranscriptionManager {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startTranscription() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Privacy-first

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) {
            [weak self] result, error in
            self?.handleSpeechResult(result, error: error)
        }
    }
}
```

---

## 3. AI Integration Architecture

### 3.1 Multi-Provider AI System

#### AI Provider Interface

```swift
protocol AIProvider {
    func generateResponse(
        prompt: String,
        context: AIContext,
        completion: @escaping (Result<AIResponse, Error>) -> Void
    )
    var isAvailable: Bool { get }
    var responseTime: TimeInterval { get }
    var costPerToken: Decimal { get }
}
```

#### OpenAI Integration

```swift
class OpenAIProvider: AIProvider {
    private let apiKey: String
    private let client: OpenAIClient

    func generateResponse(prompt: String, context: AIContext,
                         completion: @escaping (Result<AIResponse, Error>) -> Void) {
        let messages = buildMessages(from: prompt, context: context)

        client.chat.completions.create(
            model: .gpt4o,
            messages: messages,
            maxTokens: 500,
            temperature: 0.3
        ) { result in
            switch result {
            case .success(let response):
                let aiResponse = AIResponse(
                    text: response.choices.first?.message.content ?? "",
                    confidence: 0.9,
                    metadata: response.usage
                )
                completion(.success(aiResponse))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
```

#### Local AI Model Integration

```swift
class LocalAIProvider: AIProvider {
    private let model: LLamaModel

    func generateResponse(prompt: String, context: AIContext,
                         completion: @escaping (Result<AIResponse, Error>) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let response = try self.model.generate(
                    prompt: self.buildPrompt(prompt, context: context),
                    maxTokens: 500
                )

                let aiResponse = AIResponse(
                    text: response.text,
                    confidence: response.confidence,
                    metadata: ["local": true]
                )

                DispatchQueue.main.async {
                    completion(.success(aiResponse))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
```

### 3.2 Context Management System

#### Context Builder

```swift
struct AIContext {
    let screenContent: String
    let audioTranscript: String
    let applicationContext: String
    let userIntent: UserIntent
    let conversationHistory: [ConversationTurn]
    let knowledgeBase: [KnowledgeItem]
    let timestamp: Date
}

class ContextBuilder {
    func buildContext(
        screenContent: String,
        audioTranscript: String,
        userQuery: String?
    ) -> AIContext {
        return AIContext(
            screenContent: preprocessScreenContent(screenContent),
            audioTranscript: preprocessAudioTranscript(audioTranscript),
            applicationContext: detectApplicationContext(),
            userIntent: classifyUserIntent(userQuery),
            conversationHistory: getRecentHistory(),
            knowledgeBase: searchRelevantKnowledge(screenContent, audioTranscript),
            timestamp: Date()
        )
    }

    private func preprocessScreenContent(_ content: String) -> String {
        // Remove UI noise, normalize formatting, extract key information
        return content
            .removingUIElements()
            .normalizingWhitespace()
            .extractingKeyInformation()
    }
}
```

---

## 4. Data Storage & Security

### 4.1 Local Storage Architecture

#### Core Data Model

```swift
import CoreData

@objc(ConversationEntity)
public class ConversationEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var userQuery: String
    @NSManaged public var aiResponse: String
    @NSManaged public var context: Data // Encrypted JSON
    @NSManaged public var feedback: Int16
}

@objc(KnowledgeItemEntity)
public class KnowledgeItemEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: Data // Encrypted
    @NSManaged public var embedding: Data // Vector embedding
    @NSManaged public var source: String
    @NSManaged public var lastAccessed: Date
}
```

#### Encryption Implementation

```swift
import CryptoKit

class DataEncryption {
    private let key: SymmetricKey

    init() {
        // Generate or retrieve key from Keychain
        self.key = SymmetricKey(size: .bits256)
        storeKeyInKeychain()
    }

    func encrypt<T: Codable>(_ object: T) throws -> Data {
        let data = try JSONEncoder().encode(object)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decrypt<T: Codable>(_ data: Data, as type: T.Type) throws -> T {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(type, from: decryptedData)
    }
}
```

### 4.2 Vector Database for Knowledge Retrieval

#### Embedding Generation

```swift
import NaturalLanguage

class EmbeddingGenerator {
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    func generateEmbedding(for text: String) -> [Float]? {
        return embedding?.vector(for: text)
    }

    func findSimilar(to query: String, in documents: [KnowledgeItem],
                    limit: Int = 5) -> [KnowledgeItem] {
        guard let queryEmbedding = generateEmbedding(for: query) else { return [] }

        let similarities = documents.map { doc in
            (doc, cosineSimilarity(queryEmbedding, doc.embedding))
        }

        return similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
}
```

---

## 5. Performance Optimization

### 5.1 Memory Management

```swift
class PerformanceManager {
    private let memoryPressureDispatchSource: DispatchSourceMemoryPressure

    init() {
        memoryPressureDispatchSource = DispatchSource.makeMemoryPressureSource(
            eventMask: .all,
            queue: .main
        )

        memoryPressureDispatchSource.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }

        memoryPressureDispatchSource.resume()
    }

    private func handleMemoryPressure() {
        // Clear caches, reduce background processing
        CacheManager.shared.clearNonEssentialCache()
        ScreenAnalyzer.shared.reduceProcessingFrequency()
        AIEngine.shared.clearResponseCache()
    }
}
```

### 5.2 Background Processing

```swift
class BackgroundTaskManager {
    private let backgroundQueue = DispatchQueue(
        label: "com.clueless.background",
        qos: .background
    )

    func performBackgroundIndexing() {
        backgroundQueue.async {
            // Index new knowledge base items
            // Update embeddings
            // Cleanup old data
        }
    }
}
```

---

## 6. Testing Strategy

### 6.1 Invisibility Testing

```swift
class InvisibilityTests: XCTestCase {
    func testScreenCaptureInvisibility() {
        let overlay = InvisibleOverlayWindow()
        overlay.makeKeyAndOrderFront(nil)

        // Capture screen using multiple methods
        let quickTimeCapture = captureWithQuickTime()
        let obsCapture = captureWithOBS()
        let zoomCapture = captureWithZoomScreenShare()

        // Verify overlay is not visible in any capture
        XCTAssertFalse(quickTimeCapture.containsOverlay())
        XCTAssertFalse(obsCapture.containsOverlay())
        XCTAssertFalse(zoomCapture.containsOverlay())
    }
}
```

### 6.2 Performance Testing

```swift
class PerformanceTests: XCTestCase {
    func testOCRProcessingTime() {
        let analyzer = ScreenAnalyzer()
        let testImage = generateTestImage()

        let startTime = CFAbsoluteTimeGetCurrent()
        analyzer.performOCR(on: testImage)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertLessThan(processingTime, 0.1) // <100ms requirement
    }
}
```

---

## 7. Deployment & Distribution

### 7.1 Code Signing & Notarization

```bash
# Build and sign application
xcodebuild -project ClueLess.xcodeproj \
           -scheme ClueLess \
           -configuration Release \
           -archivePath ClueLess.xcarchive \
           archive

# Export for distribution
xcodebuild -exportArchive \
           -archivePath ClueLess.xcarchive \
           -exportPath ./dist \
           -exportOptionsPlist ExportOptions.plist

# Notarize with Apple
xcrun notarytool submit ClueLess.zip \
                      --keychain-profile "ClueLess-Notary" \
                      --wait
```

### 7.2 Installation Requirements

- macOS 12.0 (Monterey) or later
- 8GB RAM minimum (16GB recommended)
- 2GB available storage
- Screen Recording permission
- Optional: Accessibility permission for enhanced features

---

## 8. Security Considerations

### 8.1 Privacy Protection

- All AI processing occurs locally when possible
- No telemetry or usage analytics without explicit consent
- Encrypted local storage for all user data
- No network transmission of screen content or audio

### 8.2 Anti-Detection Measures

- Window level manipulation to avoid screen capture
- Custom drawing contexts that bypass recording APIs
- Memory-only storage for sensitive operations
- Randomized timing to avoid pattern detection

### 8.3 Secure Communication

```swift
class SecureAPIClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        self.session = URLSession(configuration: configuration)
    }

    func makeSecureRequest<T: Codable>(
        to endpoint: String,
        payload: T,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        // Certificate pinning, request encryption, etc.
    }
}
```

---

## 9. Monitoring & Analytics

### 9.1 Performance Monitoring

```swift
class PerformanceMonitor {
    func trackResponseTime(_ duration: TimeInterval, for operation: String) {
        let metrics = [
            "operation": operation,
            "duration": duration,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Store locally, optionally sync with analytics service
        MetricsStore.shared.record(metrics)
    }
}
```

### 9.2 Error Tracking

```swift
class ErrorTracker {
    func trackError(_ error: Error, context: [String: Any] = [:]) {
        let errorInfo = [
            "error": error.localizedDescription,
            "context": context,
            "timestamp": Date().timeIntervalSince1970,
            "version": Bundle.main.appVersion
        ]

        // Store for local debugging, optionally report to crash service
        ErrorStore.shared.record(errorInfo)
    }
}
```
