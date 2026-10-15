import Foundation
import AVFoundation
#if canImport(SherpaOnnx)
import SherpaOnnx
#endif

/// SherpaSpeechRecognitionService: Nhận diện giọng nói tiếng Việt OFFLINE 100%
/// Sử dụng mô hình Zipformer INT8 qua Sherpa-ONNX.
/// Hoàn toàn KHÔNG phụ thuộc Apple Speech, KHÔNG bị iOS ép tự sửa từ trong quá khứ,
/// hoạt động liên tục không giới hạn 60 giây và có độ trễ cực thấp (~20-40ms).
public class SherpaSpeechRecognitionService: ObservableObject {
    public static let shared = SherpaSpeechRecognitionService()
    
    @Published public var isRecording: Bool = false
    @Published public var recognizedText: String = ""
    @Published public var audioLevel: Float = 0.0
    @Published public var clarityStatus: String = "Sẵn sàng"
    @Published public var clarityColor: String = "gray"
    @Published public var errorMessage: String? = nil
    @Published public var isModelLoaded: Bool = false
    @Published public var engineName: String = "Sherpa-ONNX Zipformer (Offline AI)"
    
    private var audioEngine: AVAudioEngine?
    private var audioConverter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    
    #if canImport(SherpaOnnx)
    private var recognizer: SherpaOnnxRecognizer?
    #endif
    
    private let processingQueue = DispatchQueue(label: "com.trantuan.cardgame.sherpa.audio", qos: .userInteractive)
    private var lastResultText: String = ""
    private var segmentCounter: Int = 0
    private var lastRmsUpdateTime: Double = 0
    
    public init() {
        targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        initModelAsync()
    }
    
    /// Tìm file mô hình trong App Bundle
    private func findModelFile(name: String, ext: String) -> String? {
        let bundle = Bundle.main
        // 1. Tìm trong thư mục con SherpaModel
        if let path = bundle.path(forResource: name, ofType: ext, inDirectory: "SherpaModel") {
            return path
        }
        // 2. Tìm ở thư mục gốc bundle
        if let path = bundle.path(forResource: name, ofType: ext) {
            return path
        }
        // 3. Tìm qua resourceURL
        if let resUrl = bundle.resourceURL {
            let directUrl = resUrl.appendingPathComponent("SherpaModel").appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: directUrl.path) {
                return directUrl.path
            }
            let subUrl = resUrl.appendingPathComponent("Resources/SherpaModel").appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: subUrl.path) {
                return subUrl.path
            }
        }
        return nil
    }
    
    /// Nạp mô hình Zipformer INT8 tiếng Việt trong nền
    public func initModelAsync() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            #if canImport(SherpaOnnx)
            guard let encoder = self.findModelFile(name: "encoder.int8", ext: "onnx"),
                  let decoder = self.findModelFile(name: "decoder", ext: "onnx"),
                  let joiner = self.findModelFile(name: "joiner.int8", ext: "onnx"),
                  let tokens = self.findModelFile(name: "tokens", ext: "txt") else {
                print("[SherpaASR] ⚠️ Chưa tìm thấy file mô hình SherpaModel trong Bundle.")
                DispatchQueue.main.async {
                    self.isModelLoaded = false
                    self.clarityStatus = "Chưa có file model AI"
                }
                return
            }
            
            let transducerConfig = sherpaOnnxOnlineTransducerModelConfig(
                encoder: encoder,
                decoder: decoder,
                joiner: joiner
            )
            
            let modelConfig = sherpaOnnxOnlineModelConfig(
                tokens: tokens,
                transducer: transducerConfig,
                numThreads: 2,
                provider: "cpu"
            )
            
            let featConfig = sherpaOnnxFeatureConfig(sampleRate: 16000, featureDim: 80)
            
            // Danh sách từ khóa ưu tiên (Hotwords) trong game bài
            let hotwordsList = [
                "át", "xì", "bồi", "đầm", "già", "k", "q", "j",
                "cơ", "rô", "tép", "chuồn", "bích",
                "mười", "chín", "tám", "bảy", "sáu", "năm", "bốn", "ba", "hai", "một",
                "úp", "bỏ", "xóa", "chia"
            ].joined(separator: "\n")
            
            var recognizerConfig = sherpaOnnxOnlineRecognizerConfig(
                featConfig: featConfig,
                modelConfig: modelConfig,
                enableEndpoint: true,
                rule1MinTrailingSilence: 0.8,
                rule2MinTrailingSilence: 0.35,
                rule3MinUtteranceLength: 20.0,
                decodingMethod: "greedy_search",
                maxActivePaths: 4,
                hotwordsScore: 1.8,
                hotwordsBuf: hotwordsList,
                hotwordsBufSize: hotwordsList.utf8.count
            )
            
            self.recognizer = SherpaOnnxRecognizer(config: &recognizerConfig)
            DispatchQueue.main.async {
                self.isModelLoaded = true
                self.clarityStatus = "🟢 Mô hình AI Zipformer sẵn sàng"
                print("[SherpaASR] ✅ Đã khởi tạo thành công Sherpa-ONNX Zipformer tiếng Việt!")
            }
            #else
            DispatchQueue.main.async {
                self.isModelLoaded = false
                print("[SherpaASR] SherpaOnnx module chưa được link trong target hiện tại.")
            }
            #endif
        }
    }
    
    /// Bắt đầu lắng nghe liên tục không bị ngắt quãng
    public func startRecording(
        onResult: @escaping (_ text: String, _ segmentID: Int) -> Void,
        onError: ((_ message: String) -> Void)? = nil
    ) {
        guard !isRecording else { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            let msg = "Lỗi kích hoạt AudioSession: \(error.localizedDescription)"
            self.errorMessage = msg
            onError?(msg)
            return
        }
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0, let targetFmt = self.targetFormat else {
            let msg = "Không tìm thấy định dạng micro hợp lệ."
            self.errorMessage = msg
            onError?(msg)
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFmt) else {
            let msg = "Không thể tạo bộ chuyển đổi âm thanh 16kHz."
            self.errorMessage = msg
            onError?(msg)
            return
        }
        self.audioConverter = converter
        
        segmentCounter += 1
        let currentSegment = segmentCounter
        lastResultText = ""
        
        #if canImport(SherpaOnnx)
        recognizer?.reset()
        #endif
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }
            
            // Tính toán mức âm thanh RMS trực tiếp
            let now = CACurrentMediaTime()
            if now - self.lastRmsUpdateTime > 0.08, let channelData = buffer.floatChannelData?[0] {
                self.lastRmsUpdateTime = now
                let frameCount = Int(buffer.frameLength)
                if frameCount > 0 {
                    var sum: Float = 0.0
                    for i in 0..<frameCount {
                        let s = channelData[i]
                        sum += s * s
                    }
                    let rms = sqrt(sum / Float(frameCount))
                    DispatchQueue.main.async {
                        self.audioLevel = rms
                        if rms > 0.08 {
                            self.clarityStatus = "🟢 Nghe rất rõ ▂▃▅"
                            self.clarityColor = "green"
                        } else if rms > 0.02 {
                            self.clarityStatus = "🟡 Hơi nhỏ ▂_ _"
                            self.clarityColor = "yellow"
                        } else {
                            self.clarityStatus = "⚪ Đang chờ tiếng..."
                            self.clarityColor = "gray"
                        }
                    }
                }
            }
            
            // Chuyển đổi âm thanh sang chuẩn 16kHz Float32 mono cho AI model
            self.processingQueue.async {
                self.processAudioBuffer(buffer, converter: converter, onResult: onResult, segmentID: currentSegment)
            }
        }
        
        do {
            try engine.start()
            isRecording = true
            clarityStatus = "🎙️ Đang nghe (AI Offline)..."
            errorMessage = nil
        } catch {
            let msg = "Không thể bật micro thu âm: \(error.localizedDescription)"
            errorMessage = msg
            onError?(msg)
            stopRecording()
        }
    }
    
    /// Xử lý chunk âm thanh và truyền vào Sherpa-ONNX
    private func processAudioBuffer(
        _ inputBuffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        onResult: @escaping (_ text: String, _ segmentID: Int) -> Void,
        segmentID: Int
    ) {
        #if canImport(SherpaOnnx)
        guard let recognizer = self.recognizer, isRecording else { return }
        
        guard let targetFmt = self.targetFormat else { return }
        let ratio = Float(16000) / Float(inputBuffer.format.sampleRate)
        let outputFrameCapacity = AVAudioFrameCount(ceil(Float(inputBuffer.frameLength) * ratio)) + 64
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: outputFrameCapacity) else { return }
        
        var error: NSError?
        var hasSuppliedInput = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if !hasSuppliedInput {
                outStatus.pointee = .haveData
                hasSuppliedInput = true
                return inputBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
        guard error == nil, outputBuffer.frameLength > 0, let floatData = outputBuffer.floatChannelData?[0] else {
            return
        }
        
        let frameLength = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatData, count: frameLength))
        
        recognizer.acceptWaveform(samples: samples, sampleRate: 16000)
        while recognizer.isReady() {
            recognizer.decode()
        }
        
        let isEndpoint = recognizer.isEndpoint()
        let result = recognizer.getResult()
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !text.isEmpty && text != self.lastResultText {
            self.lastResultText = text
            DispatchQueue.main.async {
                self.recognizedText = text
                onResult(text, segmentID)
            }
        }
        
        // Khi người dùng ngắt câu (Endpoint), reset stream để câu tiếp theo không bị dính vào câu cũ
        if isEndpoint {
            recognizer.reset()
            self.lastResultText = ""
        }
        #endif
    }
    
    /// Dừng thu âm
    public func stopRecording() {
        audioEngine?.stop()
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        audioConverter = nil
        
        #if canImport(SherpaOnnx)
        recognizer?.reset()
        #endif
        
        isRecording = false
        audioLevel = 0.0
        clarityStatus = "Đã dừng"
        clarityColor = "gray"
    }
}
