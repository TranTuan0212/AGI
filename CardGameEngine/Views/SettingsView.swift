import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Voice Training State for J - Q - K
    @State private var selectedRankForTraining: Rank = .jack
    @State private var isTrainingRecording: Bool = false
    @State private var trainedSpokenText: String = ""
    @State private var manualCustomKeyword: String = ""
    @State private var customKeywordsVersion: Int = 0
    
    public var body: some View {
        NavigationView {
            Form {
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
                            
                            if !trainedSpokenText.isEmpty {
                                Button(action: {
                                    saveTrainedWord(trainedSpokenText)
                                }) {
                                    Text("➕ Lưu từ này")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color.green)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if !trainedSpokenText.isEmpty {
                            HStack {
                                Text("Mic nghe được:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\"\(trainedSpokenText)\"")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                            }
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
            viewModel.voiceService.startRecording(
                onResult: { text, _ in
                    DispatchQueue.main.async {
                        self.trainedSpokenText = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        trainedSpokenText = ""
        customKeywordsVersion += 1
        if isTrainingRecording {
            viewModel.voiceService.stopRecording(callEndAudio: false)
            isTrainingRecording = false
        }
    }
}
