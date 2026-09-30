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
    
    // Tap installation state to prevent calling removeTap when no tap exists
    private var isTapInstalled: Bool = false
    
    // Safety flag to prevent appending audio buffer after endAudio has been called
    private var isAudioEnding: Bool = false
    
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
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // .playAndRecord with mode .default is fully valid and compatible with .defaultToSpeaker and .allowBluetooth
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = recognitionRequest
            recognitionRequest.shouldReportPartialResults = true
            
            // Re-instantiate fresh AVAudioEngine per recording session to avoid stale graph state
            let engine = AVAudioEngine()
            self.audioEngine = engine
            
            let inputNode = engine.inputNode
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.recognizedText = text
                        onResult(text)
                    }
                }
                
                // If error or finished, clean up on the main thread safely
                if error != nil || (result?.isFinal ?? false) {
                    DispatchQueue.main.async {
                        if self.isRecording {
                            self.stopRecording()
                        }
                    }
                }
            }
            
            // Format check: Use native inputFormat or nil fallback for maximum hardware compatibility
            let hwFormat = inputNode.outputFormat(forBus: 0)
            let tapFormat = hwFormat.sampleRate > 0 ? hwFormat : nil
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
                guard let self = self, self.isRecording, !self.isAudioEnding else {
                    return
                }
                self.recognitionRequest?.append(buffer)
            }
            self.isTapInstalled = true
            
            engine.prepare()
            try engine.start()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.isAudioEnding = false
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
        // Step 1: Immediately flag that audio is ending so no more buffers are appended
        isAudioEnding = true
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Step 2: Remove tap FIRST while engine is still bound, avoiding RemoveTap exception
        if isTapInstalled, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        // Step 3: Stop and clear audio engine instance
        if let engine = audioEngine {
            if engine.isRunning {
                engine.stop()
            }
            self.audioEngine = nil
        }
        
        // Step 4: Safely end audio request now that tap is completely removed
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isAudioEnding = false
        
        // Step 5: Deactivate audio session to return hardware to normal state
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
