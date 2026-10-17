import SwiftUI

public struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @ObservedObject private var authManager = AppAuthManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dark Casino Slate Background
            Color(red: 0.06, green: 0.08, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 0. User Status Bar (Tài khoản & Đăng xuất)
                HStack {
                    if let user = authManager.currentUsername {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11, weight: .bold))
                            Text(user)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                            Text("• Máy Nhập (Quota: 2 máy)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("Chế độ Nhập Server 2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        authManager.logout()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "power")
                                .font(.system(size: 10, weight: .bold))
                            Text("Đăng xuất")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.red.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .background(Color(red: 0.07, green: 0.09, blue: 0.14))
                
                // 1. TOP HEADER: Tiêu đề & Điều khiển số Tụ / Chế độ nhập
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text("♦")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.roseAccent)
                            Text("NHẬP 3 LÁ")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("SERVER 2")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.roseAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.roseAccent.opacity(0.18))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.roseAccent.opacity(0.35), lineWidth: 1)
                                )
                        }
                        
                        Spacer()
                        
                        // Stepper chọn số Tụ (2 -> 10)
                        HStack(spacing: 4) {
                            Button(action: {
                                if viewModel.numberOfPlayers > 2 {
                                    viewModel.numberOfPlayers -= 1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(viewModel.numberOfPlayers > 2 ? .white : .gray)
                                    .frame(width: 26, height: 26)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .disabled(viewModel.numberOfPlayers <= 2)
                            
                            Text("\(viewModel.numberOfPlayers) Tụ")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0)) // Vàng kim
                                .frame(minWidth: 46)
                            
                            Button(action: {
                                if viewModel.numberOfPlayers < 10 {
                                    viewModel.numberOfPlayers += 1
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(viewModel.numberOfPlayers < 10 ? .white : .gray)
                                    .frame(width: 26, height: 26)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .disabled(viewModel.numberOfPlayers >= 10)
                        }
                        .padding(3)
                        .background(Color(red: 0.12, green: 0.15, blue: 0.22))
                        .cornerRadius(8)
                    }
                    
                    // Chuyển đổi chế độ chia: Chia tuần tự vs Chọn từng tụ
                    HStack(spacing: 6) {
                        Button(action: {
                            viewModel.inputMode = .roundRobin
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Chia Tuần Tự (Vòng tròn)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(viewModel.inputMode == .roundRobin ? .slateDark : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.inputMode == .roundRobin
                                    ? Color(red: 1.0, green: 0.84, blue: 0.0)
                                    : Color.white.opacity(0.06)
                            )
                            .cornerRadius(7)
                        }
                        
                        Button(action: {
                            viewModel.inputMode = .manual
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Chọn Thủ Công Từng Tụ")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(viewModel.inputMode == .manual ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.inputMode == .manual
                                    ? Color.cyan
                                    : Color.white.opacity(0.06)
                            )
                            .cornerRadius(7)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(Color(red: 0.09, green: 0.12, blue: 0.18))
                
                // 2. BẢNG ĐỐI CHIẾU THỨ HẠNG REALTIME (Cross-Check Leaderboard)
                if !viewModel.server2LeaderboardChain.isEmpty || !viewModel.server2WinnerTitle.isEmpty {
                    VStack(spacing: 3) {
                        if !viewModel.server2WinnerTitle.isEmpty {
                            Text(viewModel.server2WinnerTitle)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.3))
                                .lineLimit(1)
                        }
                        
                        // Chuỗi so sánh thứ hạng: Tụ 1 > Tụ 3 = Tụ 2
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                Text("BXH:")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.gray)
                                
                                ForEach(Array(viewModel.server2LeaderboardChain.components(separatedBy: " ").enumerated()), id: \.offset) { idx, token in
                                    if token == ">" || token == "=" {
                                        Text(token)
                                            .font(.system(size: 13, weight: .black))
                                            .foregroundColor(token == "=" ? Color.orange : Color.gray)
                                    } else {
                                        Text(token)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.12))
                                            .cornerRadius(5)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.14, green: 0.17, blue: 0.25))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.white.opacity(0.1)),
                        alignment: .bottom
                    )
                }
                
                // 3. DANH SÁCH CÁC TỤ BÀI (Player Mats)
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(0..<viewModel.players.count, id: \.self) { pIdx in
                            Server2PlayerRowView(
                                player: viewModel.players[pIdx],
                                playerIndex: pIdx,
                                isSelected: viewModel.selectedPlayerIndex == pIdx,
                                handResult: viewModel.server2HandResults.indices.contains(pIdx) ? viewModel.server2HandResults[pIdx] : nil
                            ) {
                                viewModel.selectedPlayerIndex = pIdx
                                viewModel.roundRobinPointer = pIdx
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // 4. BÀN PHÍM SỐ CỐ ĐỊNH Ở DƯỚI CÙNG (Fixed Keypad)
                Server2KeypadView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Row hiển thị từng Tụ bài
struct Server2PlayerRowView: View {
    let player: Player
    let playerIndex: Int
    let isSelected: Bool
    let handResult: Server2HandResult?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Header của tụ: Tên tụ + Thứ hạng + Kết quả điểm
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Tụ \(playerIndex + 1)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(isSelected ? .cyan : .white)
                        
                        if isSelected {
                            Text("● ĐANG CHỌN")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                    Spacer()
                    
                    // Kết quả tính điểm
                    if let res = handResult, res.type != .empty {
                        Text(res.label)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(res.hasRo ? .roseAccent : (res.score >= 800 ? .green : .yellow))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                (res.hasRo ? Color.roseAccent : Color.white).opacity(0.12)
                            )
                            .cornerRadius(6)
                    }
                    
                    // Huy hiệu thứ hạng (Hạng 1, 2, 3...)
                    if let rank = player.rankOrder {
                        let rankInfo = Server2ThreeCardEvaluator.getRankTheme(rank: rank, isComplete: (handResult?.isComplete ?? false))
                        Text(rankInfo.badgeText)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(rankInfo.primaryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rankInfo.backgroundColor)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(rankInfo.primaryColor.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                
                // 3 ô lá bài (Cards Slots)
                HStack(spacing: 8) {
                    ForEach(0..<3) { slotIdx in
                        if slotIdx < player.cards.count {
                            let card = player.cards[slotIdx]
                            Server2CardItemView(card: card)
                        } else {
                            // Ô trống chờ nhập bài
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .frame(height: 52)
                                .overlay(
                                    Text("\(slotIdx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.2))
                                )
                        }
                    }
                }
            }
            .padding(10)
            .background(
                isSelected
                    ? Color(red: 0.10, green: 0.16, blue: 0.24)
                    : Color(red: 0.10, green: 0.12, blue: 0.17)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.cyan : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Color.cyan.opacity(0.25) : Color.clear, radius: 4, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Hiển thị 1 lá bài riêng lẻ
struct Server2CardItemView: View {
    let card: Card
    
    var body: some View {
        ZStack {
            if card.isHidden {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.28, green: 0.22, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
                    )
                Text("?")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Color.yellow)
            } else if card.isRo {
                // Lá chất Rô: Nền gradient đỏ hồng nổi bật kèm ký hiệu ♦
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.roseAccent, Color(red: 0.80, green: 0.10, blue: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                
                HStack(spacing: 2) {
                    Text(card.rank.displaySymbol)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("♦")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                }
            } else {
                // Lá số thường
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.18, green: 0.22, blue: 0.30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                
                Text(card.rank.displaySymbol)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    static let slateDark = Color(red: 0.08, green: 0.10, blue: 0.15)
}
