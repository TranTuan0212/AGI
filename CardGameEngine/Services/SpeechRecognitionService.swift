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
    private let audioEngine = AVAudioEngine()
    
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
        // Cancel any previous task safely
        stopRecording()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.errorMessage = "Nhận diện giọng nói tiếng Việt hiện không khả dụng trên thiết bị."
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord with defaultToSpeaker and allowBluetooth for high compatibility and stability
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                self.errorMessage = "Không thể khởi tạo bộ nhận diện âm thanh."
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            
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
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0 else {
                self.errorMessage = "Lỗi phần cứng âm thanh: Không nhận diện được tần số lấy mẫu."
                stopRecording()
                return
            }
            
            // Clean any prior tap before installing
            inputNode.removeTap(onBus: 0)
            
            // Safe tap callback: guards against appending after endAudio has been called
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self, self.isRecording, !self.isAudioEnding, let request = self.recognitionRequest else {
                    return
                }
                request.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
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
        
        // Step 2: Stop audio engine and remove tap FIRST
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Step 3: Now safely end audio request without buffer collisions
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isAudioEnding = false
        
        // Step 4: Deactivate audio session to return hardware to normal state
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
