import SwiftUI

public struct ResultModalView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Winner Banner
                            VStack(spacing: 8) {
                                Text(viewModel.showdownSummary)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Text(viewModel.gameType.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(14)
                            .padding(.horizontal)
                            
                            // Rankings List
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Bảng Xếp Hạng & Đánh Giá Bài")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                ForEach(sortedPlayers) { player in
                                    let isUnknown = player.rankOrder == nil || player.resultTitle == "???" || player.cards.contains(where: { $0.isHidden })
                                    let isTie = !isUnknown && player.rankOrder != nil && viewModel.players.filter({ $0.rankOrder == player.rankOrder }).count > 1
                                    
                                    HStack(alignment: .top, spacing: 12) {
                                        // Medal / Rank badge
                                        if isUnknown {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 36, height: 36)
                                                Text("?")
                                                    .font(.headline)
                                                    .fontWeight(.black)
                                                    .foregroundColor(.white)
                                            }
                                        } else {
                                            ZStack {
                                                Circle()
                                                    .fill(rankBadgeColor(player.rankOrder ?? 0))
                                                    .frame(width: 36, height: 36)
                                                
                                                Text("\(player.rankOrder ?? 0)")
                                                    .font(.headline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(player.name)
                                                    .font(.headline)
                                                
                                                if isUnknown {
                                                    Text("LOẠI KHỎI BXH")
                                                        .font(.caption2)
                                                        .fontWeight(.black)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.red)
                                                        .cornerRadius(4)
                                                } else if isTie {
                                                    Text("ĐỒNG HẠNG")
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.orange)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.orange.opacity(0.15))
                                                        .cornerRadius(4)
                                                }
                                                
                                                if player.isLung {
                                                    Text("LỦNG")
                                                        .font(.caption2)
                                                        .fontWeight(.black)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.red)
                                                        .cornerRadius(4)
                                                }
                                                
                                                Spacer()
                                            }
                                            
                                            Text(player.resultTitle)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(isUnknown ? .red : .blue)
                                            
                                            Text(player.resultDetail)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer().frame(height: 70) // Khoảng trống cuộn tránh che khuất bởi nút nổi
                        }
                        .padding(.vertical)
                    }
                    
                    // Nút Đóng Thứ 2 (Floating Close Button)
                    if viewModel.isFloatingCloseButtonEnabled {
                        let btnX = geo.size.width * viewModel.floatingCloseButtonRatioX
                        let btnY = geo.size.height * viewModel.floatingCloseButtonRatioY
                        let btnSize = viewModel.floatingCloseButtonSize
                        
                        Button(action: {
                            viewModel.isShowResultModal = false
                            if viewModel.isVoiceMode {
                                viewModel.resetTable()
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "xmark")
                                    .font(.system(size: btnSize * 0.36, weight: .black))
                                if btnSize >= 50 {
                                    Text("ĐÓNG")
                                        .font(.system(size: max(8, btnSize * 0.18), weight: .black))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: btnSize, height: btnSize)
                            .background(
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color.red, Color(red: 0.9, green: 0.2, blue: 0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .position(x: btnX, y: btnY)
                    }
                }
            }
            .navigationTitle("Kết Quả So Bài")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.isShowResultModal = false
                        if viewModel.isVoiceMode {
                            viewModel.resetTable()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text("Đóng")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var sortedPlayers: [Player] {
        viewModel.players.sorted { ($0.rankOrder ?? 999) < ($1.rankOrder ?? 999) }
    }

    private func rankBadgeColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.brown
        default: return Color.blue.opacity(0.6)
        }
    }
}
