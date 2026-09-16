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
                            
                            Text("\(viewModel.numberOfPlayers) Nhóm")
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
                    // Action Buttons Row
                    HStack(spacing: 6) {
                        Button(action: { viewModel.undoLastAction() }) {
                            Label("Hoàn tác", systemImage: "arrow.uturn.backward")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(6)
                        }
                        
                        Button(action: { viewModel.isShowingHistory = true }) {
                            Label("Lịch sử", systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.purple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Button(action: { viewModel.resetTable() }) {
                            Label("Xóa", systemImage: "trash")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        Button(action: { viewModel.calculateResults() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                Text("So Bài")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.isReadyToCalculate ?
                                LinearGradient(colors: [Color.blue, Color.purple], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.gray, Color.gray.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(6)
                        }
                        .disabled(!viewModel.isReadyToCalculate)
                    }
                    .padding(.horizontal)
                    
                    // 52-Card Deck Grid (Fixed at the bottom like a keyboard)
                    Deck52GridView(viewModel: viewModel)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                }
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: -2)
            }
            .navigationTitle("Trợ Lý Bài 52 Lá")

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
