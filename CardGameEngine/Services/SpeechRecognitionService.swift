import Foundation
import Speech
import AVFoundation

public class SpeechRecognitionService: ObservableObject {
    @Published public var isRecording: Bool = false
    @Published public var recognizedText: String = ""
    @Published public var errorMessage: String? = nil
    
    @Published public var currentInputDeviceName: String = "📱 Micro thân máy"
    @Published public var isBluetoothInput: Bool = false
    
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
    
    // Unique task ID to invalidate callbacks from superseded recognition tasks
    private var currentTaskID: UUID = UUID()
    
    // Incremental segment ID per recognition task to notify ViewModel on phrase/task resets
    private var segmentID: Int = 0
    private var currentOnResult: ((String, Int) -> Void)? = nil
    
    public static func getContextualStrings() -> [String] {
        var list = [
            "Át", "Xì", "Át cơ", "Át rô", "Át tép", "Át chuồn", "Át bích", "át", "xì", "át cơ", "át rô", "át tép", "át chuồn", "át bích",
            "K", "Già", "Ka", "Ca", "Cây", "Da", "Dà", "k", "già", "ka", "ca", "cây", "da", "dà",
            "Q", "Đầm", "Quy", "Qui", "Kiu", "Huy", "q", "đầm", "quy", "qui", "kiu", "huy",
            "J", "Bồi", "Ri", "Dây", "Day", "Chây", "Bồi cơ", "Bồi rô", "Bồi tép", "Bồi chuồn", "Bồi bích", "Con bồi", "Lá bồi",
            "j", "bồi", "ri", "dây", "day", "chây", "bồi cơ", "bồi rô", "bồi tép", "bồi chuồn", "bồi bích",
            "Đôi", "Sám", "Tứ quý", "đôi", "sám", "tứ quý",
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13",
            "Mười ba", "Mười hai", "Mười một", "Một một", "mười ba", "mười hai", "mười một", "một một",
            "Mười", "Chín", "Tám", "Bảy", "Sáu", "Năm", "Bốn", "Ba", "Hai", "Heo", "Một",
            "mười", "chín", "tám", "bảy", "sáu", "năm", "bốn", "ba", "hai", "heo", "một",
            "Cơ", "Rô", "Tép", "Chuồn", "Bích", "cơ", "rô", "tép", "chuồn", "bích",
            "Bỏ", "Bỏ bài", "Bỏ qua", "Bài ẩn", "bỏ", "bỏ bài", "bỏ qua", "bài ẩn"
        ]
        let customWords = VietnameseCardVoiceParser.getAllCustomKeywords()
        for word in customWords {
            if !list.contains(word) {
                list.append(word)
            }
        }
        return list
    }
    
    private var routeChangeObserver: NSObjectProtocol?
    
    public init() {
        updateAudioInputDevice()
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAudioInputDevice()
        }
    }
    
    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func updateAudioInputDevice() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentInputs = audioSession.currentRoute.inputs
        if let primary = currentInputs.first {
            let portType = primary.portType
            let isBT = (portType == .bluetoothHFP || portType == .bluetoothA2DP || portType == .bluetoothLE)
            let icon = isBT ? "🎧" : "📱"
            DispatchQueue.main.async {
                self.isBluetoothInput = isBT
                self.currentInputDeviceName = "\(icon) \(primary.portName)"
            }
        } else if let available = audioSession.availableInputs?.first {
            let portType = available.portType
            let isBT = (portType == .bluetoothHFP || portType == .bluetoothA2DP || portType == .bluetoothLE)
            let icon = isBT ? "🎧" : "📱"
            DispatchQueue.main.async {
                self.isBluetoothInput = isBT
                self.currentInputDeviceName = "\(icon) \(available.portName)"
            }
        } else {
            DispatchQueue.main.async {
                self.isBluetoothInput = false
                self.currentInputDeviceName = "📱 Micro thân máy"
            }
        }
    }
    
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
        startRecording(onResult: { text, _ in onResult(text) }, onError: onError)
    }
    
    public func startRecording(onResult: @escaping (String, Int) -> Void, onError: ((String) -> Void)? = nil) {
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
        let initialTaskID = UUID()
        self.currentTaskID = initialTaskID
        self.segmentID = 1
        let initialSegmentID = self.segmentID
        self.currentOnResult = onResult
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            
            // Prefer Bluetooth microphone if connected
            if let availableInputs = audioSession.availableInputs {
                let bluetoothInput = availableInputs.first(where: {
                    $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE
                })
                if let bluetoothInput = bluetoothInput {
                    try? audioSession.setPreferredInput(bluetoothInput)
                }
            }
            
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            self.updateAudioInputDevice()
            
            let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest = recognitionRequest
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.taskHint = .search
            if #available(iOS 16, *) {
                recognitionRequest.addsPunctuation = false
            }
            recognitionRequest.contextualStrings = Self.getContextualStrings()
            
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
                    
                    // Ignore stale results from past sessions or superseded tasks
                    guard self.sessionID == newSessionID, self.currentTaskID == initialTaskID else { return }
                    
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            guard self.sessionID == newSessionID else { return }
                            self.recognizedText = text
                            onResult(text, initialSegmentID)
                        }
                    }
                    
                    let isFinal = result?.isFinal ?? false
                    let transientCodes: Set<Int> = [216, 203, 1110, 1100, 1101, 1107]
                    if let error = error {
                        let nsError = error as NSError
                        // Non-fatal transient completion or silent segment error
                        if self.sessionID == newSessionID && self.isRecording && transientCodes.contains(nsError.code) {
                            self.restartRecognitionTask(newSessionID: newSessionID, onResult: onResult)
                            return
                        }
                        
                        // Task aborted or fatal failure
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
                            self.stopRecording(callEndAudio: false)
                        }
                    } else if isFinal {
                        // Natural phrase completion: seamlessly continue listening for next cards!
                        DispatchQueue.main.async {
                            guard self.sessionID == newSessionID, self.isRecording else { return }
                            self.restartRecognitionTask(newSessionID: newSessionID, onResult: onResult)
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
    
    private func restartRecognitionTask(newSessionID: UUID, onResult: @escaping (String, Int) -> Void) {
        guard self.sessionID == newSessionID && self.isRecording else { return }
        guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else { return }
        
        // Step 1: Cleanly finish old request & cancel old task
        self.lock.lock()
        self.activeRequest = nil
        self.lock.unlock()
        self.recognitionRequest?.endAudio()
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest = nil
        
        let newTaskID = UUID()
        self.currentTaskID = newTaskID
        
        self.segmentID += 1
        let currentSegmentID = self.segmentID
        
        // Wait 80ms for Apple XPC connection to release clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self = self, self.sessionID == newSessionID, self.currentTaskID == newTaskID, self.isRecording else { return }
            guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else { return }
            
            let newRequest = SFSpeechAudioBufferRecognitionRequest()
            newRequest.shouldReportPartialResults = true
            newRequest.taskHint = .search
            if #available(iOS 16, *) {
                newRequest.addsPunctuation = false
            }
            newRequest.contextualStrings = Self.getContextualStrings()
            
            self.recognitionRequest = newRequest
            
            self.lock.lock()
            self.activeRequest = newRequest
            self.lock.unlock()
            
            var createdTask: SFSpeechRecognitionTask? = nil
            _ = ObjcTryCatch({
                createdTask = speechRecognizer.recognitionTask(with: newRequest) { [weak self] result, error in
                    guard let self = self, self.sessionID == newSessionID, self.currentTaskID == newTaskID, self.isRecording else { return }
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                        DispatchQueue.main.async {
                            guard self.sessionID == newSessionID, self.isRecording else { return }
                            self.recognizedText = text
                            onResult(text, currentSegmentID)
                        }
                    }
                    let isFinal = result?.isFinal ?? false
                    let transientCodes: Set<Int> = [216, 203, 1110, 1100, 1101, 1107]
                    if let error = error {
                        let nsError = error as NSError
                        if self.sessionID == newSessionID && self.currentTaskID == newTaskID && self.isRecording && transientCodes.contains(nsError.code) {
                            self.restartRecognitionTask(newSessionID: newSessionID, onResult: onResult)
                        }
                    } else if isFinal {
                        DispatchQueue.main.async {
                            guard self.sessionID == newSessionID, self.currentTaskID == newTaskID, self.isRecording else { return }
                            self.restartRecognitionTask(newSessionID: newSessionID, onResult: onResult)
                        }
                    }
                }
            }, nil)
            self.recognitionTask = createdTask
        }
    }
    
    public func commitCurrentSegment() {
        guard self.isRecording, let onResult = self.currentOnResult else { return }
        self.restartRecognitionTask(newSessionID: self.sessionID, onResult: onResult)
    }
    
    public func stopRecording(callEndAudio: Bool = true) {
        self.currentOnResult = nil
        // Step 1: Immediately cut off buffer delivery under lock
        lock.lock()
        isAcceptingAudio = false
        let requestToClean = activeRequest
        activeRequest = nil
        lock.unlock()
        
        // Invalidate session ID so background handlers drop trailing events
        sessionID = UUID()
        
        // Instant 0ms UI update on main thread
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        let engineToStop = self.audioEngine
        let wasTapInstalled = self.isTapInstalled
        let taskToCancel = self.recognitionTask
        let req = self.recognitionRequest ?? requestToClean
        
        self.audioEngine = nil
        self.isTapInstalled = false
        self.recognitionRequest = nil
        self.recognitionTask = nil
        
        // Perform hardware teardown on background queue to ensure 0ms UI latency
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 2: Remove tap first while engine is still valid, then stop engine
            if let engine = engineToStop {
                if wasTapInstalled {
                    _ = ObjcTryCatch({
                        engine.inputNode.removeTap(onBus: 0)
                    }, nil)
                }
                if engine.isRunning {
                    engine.stop()
                }
            }
            
            // Step 3: Only call endAudio() if stopping normally (NOT when task already errored or completed)
            if callEndAudio {
                _ = ObjcTryCatch({
                    req?.endAudio()
                }, nil)
            }
            
            // Step 4: Safely cancel recognition task if still active
            _ = ObjcTryCatch({
                taskToCancel?.cancel()
            }, nil)
            
            // Step 5: Deactivate audio session to return hardware to normal state
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
