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
                    // Action Buttons: 1 Balanced Row (Hoàn tác [Left] - KHÔNG THẤY [Center Large] - Làm mới [Right])
                    HStack(spacing: 8) {
                        // Nút phụ bên trái: Hoàn tác
                        Button(action: { viewModel.undoLastAction() }) {
                            VStack(spacing: 2) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Hoàn tác")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: 72, minHeight: 44)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(9)
                        }
                        
                        // Nút chính ở giữa: KHÔNG THẤY (BÀI ẨN) / VÁN MỚI (To bản, nổi bật nhất)
                        Group {
                            if viewModel.hasCalculatedResults {
                                Button(action: { viewModel.startNewRound() }) {
                                    HStack(spacing: 7) {
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.system(size: 18, weight: .black))
                                        Text("VÁN MỚI")
                                            .font(.system(size: 15, weight: .black))
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
                                    HStack(spacing: 7) {
                                        Image(systemName: "questionmark.circle.fill")
                                            .font(.system(size: 18, weight: .black))
                                        Text("KHÔNG THẤY")
                                            .font(.system(size: 15, weight: .black))
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
                                    .font(.system(size: 14, weight: .bold))
                                Text("Làm mới")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: 72, minHeight: 44)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(9)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    
                    // 52-Card Deck Grid (Fixed at the bottom like a keyboard)
                    Deck52GridView(viewModel: viewModel)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
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
