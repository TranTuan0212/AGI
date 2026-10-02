import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var isShowingSettings = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. Compact Header (Game Selector & Player Count Controls)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // Game Selector Menu
                        Menu {
                            ForEach(GameType.allCases) { type in
                                Button(action: {
                                    viewModel.gameType = type
                                }) {
                                    HStack {
                                        Text(type.rawValue)
                                        if viewModel.gameType == type {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "suit.spade.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                Text(viewModel.gameType.shortName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        Spacer(minLength: 4)
                        
                        // Custom Responsive Stepper
                        HStack(spacing: 6) {
                            Button(action: {
                                if viewModel.numberOfPlayers > viewModel.gameType.minPlayers {
                                    viewModel.numberOfPlayers -= 1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(viewModel.numberOfPlayers > viewModel.gameType.minPlayers ? .blue : .gray)
                                    .frame(width: 28, height: 28)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(6)
                            }
                            .disabled(viewModel.numberOfPlayers <= viewModel.gameType.minPlayers)
                            
                            Text("\(viewModel.numberOfPlayers) Tụ")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(minWidth: 54)
                            
                            Button(action: {
                                if viewModel.numberOfPlayers < viewModel.gameType.maxPlayers {
                                    viewModel.numberOfPlayers += 1
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(viewModel.numberOfPlayers < viewModel.gameType.maxPlayers ? .blue : .gray)
                                    .frame(width: 28, height: 28)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(6)
                            }
                            .disabled(viewModel.numberOfPlayers >= viewModel.gameType.maxPlayers)
                        }
                        .padding(3)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    // Segmented Input Mode Picker (Short titles to prevent clipping on small iPhones)
                    Picker("Chế độ", selection: $viewModel.inputMode) {
                        ForEach(InputMode.allCases) { mode in
                            Text(mode.shortTitle).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                
                // 2. UPPER: Player Mats Area (Nhóm ở trên)
                ScrollView {
                    PlayerCardsView(viewModel: viewModel)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                Divider()
                
                // 3. LOWER: Pinned 52-Card Deck & Actions (Nhập ở dưới)
                VStack(spacing: 6) {
                    if viewModel.isVoiceMode {
                        VoiceOnlyControlView(viewModel: viewModel, voiceService: viewModel.voiceService)
                    } else {
                        // Voice Banner Notification
                        if let banner = viewModel.voiceBannerText {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.voiceService.isRecording ? "waveform" : "mic.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(banner)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(viewModel.voiceService.isRecording ? Color.red : Color.blue)
                            .cornerRadius(12)
                            .animation(.easeInOut, value: viewModel.voiceService.isRecording)
                        }
                        
                        // Action Buttons: Balanced Row (Hoàn tác - Giọng nói to bản - KHÔNG THẤY - Làm mới)
                        HStack(spacing: 6) {
                            // Nút Hoàn tác
                            Button(action: { viewModel.undoLastAction() }) {
                                VStack(spacing: 2) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Hoàn tác")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .frame(minWidth: 48, maxWidth: 58, minHeight: 44)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(9)
                            }
                            
                            // Nút Giọng Nói To Bản (Chạm để nói / Bấm lại để dừng)
                            Button(action: { viewModel.toggleVoiceRecognition() }) {
                                VStack(spacing: 2) {
                                    Image(systemName: viewModel.voiceService.isRecording ? "stop.circle.fill" : "mic.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(viewModel.voiceService.isRecording ? "DỪNG LẠI" : "NÓI BÀI")
                                        .font(.system(size: 10, weight: .black))
                                }
                                .foregroundColor(.white)
                                .frame(minWidth: 64, maxWidth: 80, minHeight: 44)
                                .background(
                                    viewModel.voiceService.isRecording ?
                                    LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .cornerRadius(9)
                                .shadow(color: (viewModel.voiceService.isRecording ? Color.red : Color.blue).opacity(0.35), radius: 3, y: 1.5)
                                .animation(.easeInOut(duration: 0.15), value: viewModel.voiceService.isRecording)
                            }
                            
                            // Nút chính ở giữa: KHÔNG THẤY (BÀI ẨN) / VÁN MỚI (To bản, nổi bật nhất)
                            Group {
                                if viewModel.hasCalculatedResults {
                                    Button(action: { viewModel.startNewRound() }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.clockwise.circle.fill")
                                                .font(.system(size: 17, weight: .black))
                                            Text("VÁN MỚI")
                                                .font(.system(size: 14, weight: .black))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(
                                            LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(9)
                                        .shadow(color: Color.green.opacity(0.35), radius: 3, x: 0, y: 1.5)
                                    }
                                } else {
                                    Button(action: { viewModel.onHiddenCardTapped() }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "questionmark.circle.fill")
                                                .font(.system(size: 17, weight: .black))
                                            Text("KHÔNG THẤY")
                                                .font(.system(size: 14, weight: .black))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(
                                            LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(9)
                                        .shadow(color: Color.orange.opacity(0.35), radius: 3, x: 0, y: 1.5)
                                    }
                                }
                            }
                            
                            // Nút phụ bên phải: Làm mới
                            Button(action: { viewModel.resetTable() }) {
                                VStack(spacing: 2) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Làm mới")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .frame(minWidth: 48, maxWidth: 58, minHeight: 44)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(9)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 2)
                        
                        // 52-Card Deck Grid (Fixed at the bottom like a keyboard)
                        Deck52GridView(viewModel: viewModel)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                    }
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: -2)
            }
            .navigationTitle("GiaLapSoBai")

            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.medium)
                    }
                }
            }
            .sheet(isPresented: $viewModel.isShowResultModal) {
                ResultModalView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.isShowingHistory) {
                HistoryView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }

        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Voice Only Control View (Giao diện chuyên chế độ giọng nói to bản)
struct VoiceOnlyControlView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var voiceService: SpeechRecognitionService
    
    var body: some View {
        VStack(spacing: 12) {
            // Live transcription banner
            if let banner = viewModel.voiceBannerText {
                HStack(spacing: 6) {
                    Image(systemName: voiceService.isRecording ? "waveform" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(banner)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(voiceService.isRecording ? Color.red : Color.blue)
                .cornerRadius(16)
                .shadow(color: (voiceService.isRecording ? Color.red : Color.blue).opacity(0.3), radius: 4, y: 2)
            } else {
                Text(voiceService.isRecording ? "🎙️ Đang nghe... Hãy đọc tên các lá bài" : "Chạm mic bên dưới để bắt đầu nói bài")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            // Nút Micro Tròn To Bản (Chạm để bật, chạm lại để dừng)
            Button(action: { viewModel.toggleVoiceRecognition() }) {
                VStack(spacing: 4) {
                    Image(systemName: voiceService.isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(voiceService.isRecording ? "DỪNG LẠI" : "NÓI BÀI")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(width: 82, height: 82)
                .background(
                    Circle().fill(
                        voiceService.isRecording ?
                        LinearGradient(colors: [Color.red, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 3)
                )
                .shadow(
                    color: (voiceService.isRecording ? Color.red : Color.blue).opacity(0.4),
                    radius: voiceService.isRecording ? 10 : 5,
                    x: 0,
                    y: 4
                )
                .animation(.easeInOut(duration: 0.15), value: voiceService.isRecording)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Device Input & Clarity Status Badges
            HStack(spacing: 8) {
                // Device Input Indicator Badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(voiceService.isRecording ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text("Đầu vào: \(voiceService.currentInputDeviceName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                
                // Clarity Status Badge
                if voiceService.isRecording {
                    Text(voiceService.clarityStatus)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .transition(.opacity)
                }
            }
            
            // Action Buttons Row (Hoàn tác - KHÔNG THẤY / VÁN MỚI - Làm mới)
            HStack(spacing: 8) {
                // Hoàn tác
                Button(action: { viewModel.undoLastAction() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .bold))
                        Text("Hoàn tác")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                
                // KHÔNG THẤY hoặc VÁN MỚI
                if viewModel.hasCalculatedResults {
                    Button(action: { viewModel.startNewRound() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 16, weight: .black))
                            Text("VÁN MỚI")
                                .font(.system(size: 13, weight: .black))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            LinearGradient(colors: [Color.green, Color.teal], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.green.opacity(0.3), radius: 3, y: 1.5)
                    }
                } else {
                    Button(action: { viewModel.onHiddenCardTapped() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 16, weight: .black))
                            Text("KHÔNG THẤY")
                                .font(.system(size: 13, weight: .black))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(
                            LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.orange.opacity(0.3), radius: 3, y: 1.5)
                    }
                }
                
                // Làm mới
                Button(action: { viewModel.resetTable() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                        Text("Làm mới")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .padding(.top, 4)
    }
}
