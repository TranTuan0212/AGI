import SwiftUI
import UIKit

public struct SettingsView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Voice Training State for J - Q - K
    @State private var selectedRankForTraining: Rank = .jack
    @State private var isTrainingRecording: Bool = false
    @State private var trainedSpokenText: String = ""
    @State private var manualCustomKeyword: String = ""
    @State private var customKeywordsVersion: Int = 0
    @State private var recordedTokens: [String] = []
    @State private var isLogCopied: Bool = false
    @State private var isShowingLicenseModal: Bool = false
    @ObservedObject var licenseService = LicenseService.shared
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("🛡️ Bản Quyền Giọng Nói")) {
                    HStack {
                        Text("Thiết bị")
                        Spacer()
                        Text(DeviceIdentityService.shared.getDeviceModelName())
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Trạng thái")
                        Spacer()
                        if licenseService.isVoiceUnlocked {
                            Text("ĐANG HOẠT ĐỘNG")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        } else {
                            Text(licenseService.remainingTimeText.contains("hết hạn") ? "ĐÃ HẾT HẠN" : "CHƯA KÍCH HOẠT")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                        }
                    }

                    if let exp = licenseService.expiresAtDate {
                        HStack {
                            Text("Hết hạn")
                            Spacer()
                            Text(licenseService.isLifetime ? "Vĩnh viễn" : licenseService.formatDate(exp))
                                .font(.subheadline.bold())
                                .foregroundColor(licenseService.isVoiceUnlocked ? .secondary : .red)
                        }
                    }

                    HStack {
                        Text("Thời gian còn lại")
                        Spacer()
                        Text(licenseService.remainingTimeText)
                            .font(.subheadline.bold())
                            .foregroundColor(licenseService.isVoiceUnlocked ? .green : .red)
                    }

                    Button(action: {
                        isShowingLicenseModal = true
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Quản Lý & Gia Hạn Bản Quyền")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.blue)
                    }
                }

                Section(header: Text("Chế Độ Giọng Nói (Voice Mode)")) {
                    Toggle("Chế độ chuyên giọng nói (Ẩn bàn phím)", isOn: $viewModel.isVoiceMode)
                    
                    HStack {
                        Text("Thiết bị thu âm")
                        Spacer()

                        Text(viewModel.voiceService.currentInputDeviceName)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Khi bật, toàn bộ bàn phím chọn lá bài sẽ được ẩn đi. Ứng dụng chỉ hiển thị icon micro to bản cùng các thao tác liên quan, giúp nhập bài bằng giọng nói nhanh chóng và rộng rãi.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("🎙️ Bộ Lọc & Huấn Luyện Âm Đọc (J - Q - K)")) {
                    Picker("Chọn lá bài", selection: $selectedRankForTraining) {
                        Text("J (Bồi / 11)").tag(Rank.jack)
                        Text("Q (Đầm / 12)").tag(Rank.queen)
                        Text("K (Già / 13)").tag(Rank.king)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 2)
                    
                    // Danh sách từ khóa đã học
                    if !currentLearnedKeywords.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Từ khóa riêng của bạn cho \(selectedRankForTraining.displaySymbol):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(currentLearnedKeywords, id: \.self) { word in
                                        HStack(spacing: 4) {
                                            Text(word)
                                                .font(.subheadline.bold())
                                            Button(action: {
                                                VietnameseCardVoiceParser.removeCustomKeyword(word, for: selectedRankForTraining)
                                                customKeywordsVersion += 1
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.blue.opacity(0.12))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    } else {
                        Text("Chưa có từ khóa riêng nào cho \(selectedRankForTraining.displaySymbol). Hãy thu âm phát âm của bạn hoặc gõ từ bên dưới.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Khu vực thu âm huấn luyện
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: {
                                toggleTrainingRecording()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isTrainingRecording ? "stop.circle.fill" : "mic.fill")
                                        .foregroundColor(isTrainingRecording ? .red : .blue)
                                    Text(isTrainingRecording ? "DỪNG THU" : "🎙️ Bấm & Đọc Thử")
                                        .font(.subheadline.bold())
                                        .foregroundColor(isTrainingRecording ? .red : .blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isTrainingRecording ? Color.red.opacity(0.12) : Color.blue.opacity(0.12))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            if !recordedTokens.isEmpty {
                                Button("Xóa gợi ý") {
                                    recordedTokens.removeAll()
                                    trainedSpokenText = ""
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        
                        if !trainedSpokenText.isEmpty {
                            HStack {
                                Text("Mic nghe:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\"\(trainedSpokenText)\"")
                                    .font(.caption.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Hiển thị từng chữ/từ riêng biệt để người dùng chạm 1 cái là thêm ngay
                        if !recordedTokens.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Chạm vào từ để thêm vào \(selectedRankForTraining.displaySymbol):")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recordedTokens, id: \.self) { token in
                                            Button(action: {
                                                saveTrainedWord(token)
                                            }) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .foregroundColor(.green)
                                                    Text(token)
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.primary)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.green.opacity(0.15))
                                                .cornerRadius(10)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        
                        // Hoặc gõ chữ trực tiếp
                        HStack {
                            TextField("Hoặc gõ từ (vd: zi, dây, kiu...)", text: $manualCustomKeyword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if !manualCustomKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button("Thêm") {
                                    saveTrainedWord(manualCustomKeyword)
                                    manualCustomKeyword = ""
                                }
                                .buttonStyle(BorderedProminentButtonStyle())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Tùy Chọn Bàn Phím Số A➔K (Liêng / Xì Dách / Sâm Lốc / Chắn TQ)")) {
                    Toggle("Chế độ không so chất (Bàn phím A➔K)", isOn: $viewModel.isRankOnlyMode)
                    
                    Text("Khi bật, Liêng, Xì Dách, Sâm Lốc và Chắn TQ sẽ dùng bàn phím số A➔K to bản, một lá có thể chọn nhiều lần (không khóa phím), không phân biệt chất bài.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Quy Ước So Chất Bài (Khi Chơi 52 Lá)")) {
                    Picker("Hệ Thống Chất", selection: $viewModel.suitPreset) {
                        ForEach(SuitRulePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                }
                
                Section(header: Text("Luật Chơi Hiện Tại")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.gameType.rawValue)
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.gameType.descriptionVN)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("📋 Nhật Ký Lời Nói Thực Tế (Voice Log & Timestamps)")) {
                    HStack {
                        Button(action: {
                            let text = viewModel.getVoiceLogText()
                            UIPasteboard.general.string = text
                            isLogCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                isLogCopied = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isLogCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                Text(isLogCopied ? "ĐÃ SAO CHÉP!" : "Sao Chép Nhật Ký")
                            }
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isLogCopied ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        if !viewModel.voiceService.voiceLogs.isEmpty {
                            Button("Xóa Nhật Ký") {
                                viewModel.clearVoiceLogs()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                    
                    if viewModel.voiceService.voiceLogs.isEmpty {
                        Text("Chưa có bản ghi âm lời nói nào. Hãy bật mic đọc bài để tự động lưu lại toàn bộ nhật ký từng chữ kèm timestamp (trước & sau khi Apple sửa) để gửi báo cáo.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(viewModel.getVoiceLogText())
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 250)
                    }
                }
                
                Section(header: Text("Hướng Dẫn Cơ Chế Chia Bài")) {
                    Text("• Chia Tuần Tự (Round-Robin): Khi bấm lá bài trên lưới 52 lá, lá bài sẽ tự động chia xoay vòng: Lá 1 vào A, Lá 2 vào B, Lá 3 vào C, Lá 4 vào A... đúng như ngoài đời thực.")
                        .font(.caption)
                    Text("• Chọn Thủ Công: Bấm chọn trực tiếp một nhóm để nạp đầy đủ bài cho nhóm đó trước khi chuyển sang nhóm tiếp theo.")
                        .font(.caption)
                    Text("• Chạm lại lá bài đã chia để hoàn tác (Undo) hoặc bấm nút Hoàn Tác trên thanh công cụ.")
                        .font(.caption)
                }
            }
            .navigationTitle("Cài Đặt & Luật Bài")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        if isTrainingRecording {
                            viewModel.voiceService.stopRecording(callEndAudio: false)
                            isTrainingRecording = false
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onDisappear {
                if isTrainingRecording {
                    viewModel.voiceService.stopRecording(callEndAudio: false)
                    isTrainingRecording = false
                }
            }
            .sheet(isPresented: $isShowingLicenseModal) {
                VoiceLicenseModalView()
            }
        }

    }
    
    private var currentLearnedKeywords: [String] {
        _ = customKeywordsVersion
        return VietnameseCardVoiceParser.getCustomKeywords(for: selectedRankForTraining)
    }
    
    private func toggleTrainingRecording() {
        if isTrainingRecording {
            viewModel.voiceService.stopRecording(callEndAudio: false)
            isTrainingRecording = false
        } else {
            trainedSpokenText = ""
            recordedTokens.removeAll()
            viewModel.voiceService.startRecording(
                onResult: { text, _ in
                    DispatchQueue.main.async {
                        self.trainedSpokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        let words = VietnameseCardVoiceParser.extractTrainingWords(text)
                        for w in words {
                            if !self.recordedTokens.contains(w) {
                                self.recordedTokens.append(w)
                            }
                        }
                    }
                },
                onError: { _ in
                    DispatchQueue.main.async {
                        self.isTrainingRecording = false
                    }
                }
            )
            isTrainingRecording = true
        }
    }
    
    private func saveTrainedWord(_ rawWord: String) {
        let clean = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return }
        VietnameseCardVoiceParser.addCustomKeyword(clean, for: selectedRankForTraining)
        recordedTokens.removeAll { $0 == clean }
        customKeywordsVersion += 1
    }
}
