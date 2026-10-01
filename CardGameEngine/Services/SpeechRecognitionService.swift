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
    
    public func startRecording(onResult: @escaping (String) -> Void, onError: ((String) -> Void)? = nil) {
        // Cancel and clean up any previous task safely
        stopRecording()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            let msg = "Nhận diện giọng nói tiếng Việt hiện không khả dụng trên thiết bị."
            self.errorMessage = msg
            onError?(msg)
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
            recognitionRequest.contextualStrings = [
                "Át", "Xì", "Át cơ", "Át rô", "Át tép", "Át chuồn", "Át bích",
                "K", "Già", "Ka", "Ca", "Q", "Đầm", "Quy", "J", "Bồi", "Ri",
                "Đôi", "Sám", "Tứ quý",
                "Mười", "Chín", "Tám", "Bảy", "Sáu", "Năm", "Bốn", "Ba", "Hai",
                "Cơ", "Rô", "Tép", "Chuồn", "Bích"
            ]
            
            // Re-instantiate fresh AVAudioEngine per recording session
            let engine = AVAudioEngine()
            self.audioEngine = engine
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            guard recordingFormat.sampleRate > 0 else {
                let msg = "Lỗi âm thanh: Không tìm thấy thiết bị thu âm hợp lệ."
                self.errorMessage = msg
                onError?(msg)
                stopRecording()
                return
            }
            
            var recognitionTaskError: NSError? = nil
            var createdTask: SFSpeechRecognitionTask? = nil
            
            let success = ObjcTryCatch({
                createdTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
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
                    if let error = error {
                        // Task aborted or failed (e.g. on-device model not compiled or offline)
                        self.lock.lock()
                        self.isAcceptingAudio = false
                        self.activeRequest = nil
                        self.lock.unlock()
                        
                        let localized = error.localizedDescription
                        let friendlyMsg: String
                        if localized.contains("Asset") || localized.contains("model") || localized.contains("cache") {
                            friendlyMsg = "⚠️ iOS chưa hoàn tất biên dịch model tiếng Việt. Vui lòng thử lại sau."
                        } else {
                            friendlyMsg = "⚠️ Giọng nói gián đoạn: \(localized)"
                        }
                        
                        DispatchQueue.main.async {
                            guard self.sessionID == newSessionID else { return }
                            self.errorMessage = friendlyMsg
                            onError?(friendlyMsg)
                            // Crucial: do NOT call endAudio() when Apple already aborted the request
                            self.stopRecording(callEndAudio: false)
                        }
                    } else if isFinal {
                        // Natural completion
                        self.lock.lock()
                        self.isAcceptingAudio = false
                        self.activeRequest = nil
                        self.lock.unlock()
                        
                        DispatchQueue.main.async {
                            guard self.sessionID == newSessionID else { return }
                            if self.isRecording {
                                self.stopRecording(callEndAudio: false)
                            }
                        }
                    }
                }
            }, &recognitionTaskError)
            
            guard success, let task = createdTask else {
                let reason = recognitionTaskError?.localizedDescription ?? "Hệ thống nhận diện giọng nói không khởi động được (model on-device chưa sẵn sàng)."
                let msg = "⚠️ \(reason)"
                DispatchQueue.main.async {
                    self.errorMessage = msg
                    onError?(msg)
                }
                stopRecording(callEndAudio: false)
                return
            }
            self.recognitionTask = task

            // Thread-safe audio tap: wrapped in ObjcTryCatch to prevent crash on late buffer delivery
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                self.lock.lock()
                guard self.isAcceptingAudio, let request = self.activeRequest else {
                    self.lock.unlock()
                    return
                }
                _ = ObjcTryCatch({
                    request.append(buffer)
                }, nil)
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
            let msg = "Lỗi âm thanh: \(error.localizedDescription)"
            DispatchQueue.main.async {
                self.errorMessage = msg
                onError?(msg)
                self.stopRecording(callEndAudio: false)
            }
        }
    }
    
    public func stopRecording(callEndAudio: Bool = true) {
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
        
        // Step 2: Remove tap first while engine is still valid, then stop engine
        if let engine = audioEngine {
            if isTapInstalled {
                _ = ObjcTryCatch({
                    engine.inputNode.removeTap(onBus: 0)
                }, nil)
                isTapInstalled = false
            }
            if engine.isRunning {
                engine.stop()
            }
            self.audioEngine = nil
        }
        
        // Step 3: Only call endAudio() if stopping normally (NOT when task already errored or completed)
        if callEndAudio {
            _ = ObjcTryCatch({ [weak self] in
                self?.recognitionRequest?.endAudio()
            }, nil)
        }
        recognitionRequest = nil
        
        // Step 4: Safely cancel recognition task if still active
        _ = ObjcTryCatch({ [weak self] in
            self?.recognitionTask?.cancel()
        }, nil)
        recognitionTask = nil
        
        // Step 5: Deactivate audio session to return hardware to normal state
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
