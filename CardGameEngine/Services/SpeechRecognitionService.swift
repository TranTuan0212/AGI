import Foundation
import Speech
import AVFoundation

public class SpeechRecognitionService: ObservableObject {
    @Published public var isRecording: Bool = false
    @Published public var recognizedText: String = ""
    @Published public var errorMessage: String? = nil
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    // Thread synchronization lock for CoreAudio realtime tap vs Speech completion
    private let lock = NSLock()
    private var isAcceptingAudio: Bool = false
    private var activeRequest: SFSpeechAudioBufferRecognitionRequest? = nil
    
    // Tap installation state to prevent calling removeTap when no tap exists
    private var isTapInstalled: Bool = false
    
    // Unique session ID to invalidate trailing callbacks from previous sessions
    private var sessionID: UUID = UUID()
    
    public init() {}
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                default:
                    completion(false)
                }
            }
        }
    }
    
    public func startRecording(onResult: @escaping (String) -> Void) {
        // Cancel and clean up any previous task safely
        stopRecording()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.errorMessage = "Nhận diện giọng nói tiếng Việt hiện không khả dụng trên thiết bị."
            return
        }
        
        let newSessionID = UUID()
        self.sessionID = newSessionID
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = recognitionRequest
            recognitionRequest.shouldReportPartialResults = true
            
            // Re-instantiate fresh AVAudioEngine per recording session
            let engine = AVAudioEngine()
            self.audioEngine = engine
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            guard recordingFormat.sampleRate > 0 else {
                self.errorMessage = "Lỗi âm thanh: Không tìm thấy thiết bị thu âm hợp lệ."
                stopRecording()
                return
            }
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                // Ignore stale results from past sessions
                guard self.sessionID == newSessionID else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        guard self.sessionID == newSessionID else { return }
                        self.recognizedText = text
                        onResult(text)
                    }
                }
                
                let isFinal = result?.isFinal ?? false
                if error != nil || isFinal {
                    // IMMEDIATELY cutoff audio buffers on this thread under lock to prevent NSInvalidArgumentException
                    self.lock.lock()
                    self.isAcceptingAudio = false
                    self.activeRequest = nil
                    self.lock.unlock()
                    
                    DispatchQueue.main.async {
                        guard self.sessionID == newSessionID else { return }
                        if self.isRecording {
                            self.stopRecording()
                        }
                    }
                }
            }
            
            // Thread-safe audio tap: will never call append() after request is closed
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                self.lock.lock()
                guard self.isAcceptingAudio, let request = self.activeRequest else {
                    self.lock.unlock()
                    return
                }
                request.append(buffer)
                self.lock.unlock()
            }
            self.isTapInstalled = true
            
            engine.prepare()
            try engine.start()
            
            // Enable buffer acceptance only after engine successfully starts
            self.lock.lock()
            self.isAcceptingAudio = true
            self.activeRequest = recognitionRequest
            self.lock.unlock()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.errorMessage = nil
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Lỗi âm thanh: \(error.localizedDescription)"
                self.stopRecording()
            }
        }
    }
    
    public func stopRecording() {
        // Step 1: Immediately cut off buffer delivery under lock
        lock.lock()
        isAcceptingAudio = false
        activeRequest = nil
        lock.unlock()
        
        // Invalidate session ID so background handlers drop trailing events
        sessionID = UUID()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Step 2: Stop audio engine first so hardware stops delivering frames
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            if isTapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                isTapInstalled = false
            }
            self.audioEngine = nil
        }
        
        // Step 3: Safely end audio request now that tap is completely removed and engine is stopped
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Step 4: Deactivate audio session to return hardware to normal state
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
