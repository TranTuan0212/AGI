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
                            Text("• Quota: 2 máy Nhập")
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
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 2)
                .background(Color(red: 0.07, green: 0.09, blue: 0.14))
                
                // 1. TOP HEADER: Menu chọn thể loại Game & Số Tụ & Chế độ chia
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        // Menu Chọn Thể Loại Game (Đủ các loại chơi như Server 1)
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
                            HStack(spacing: 5) {
                                Image(systemName: "suit.spade.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.roseAccent)
                                
                                Text(viewModel.gameType.shortName)
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                        
                        // Stepper chọn số Tụ
                        HStack(spacing: 3) {
                            Button(action: {
                                if viewModel.numberOfPlayers > viewModel.gameType.minPlayers {
                                    viewModel.numberOfPlayers -= 1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(viewModel.numberOfPlayers > viewModel.gameType.minPlayers ? .white : .gray)
                                    .frame(width: 24, height: 24)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(5)
                            }
                            .disabled(viewModel.numberOfPlayers <= viewModel.gameType.minPlayers)
                            
                            Text("\(viewModel.numberOfPlayers) Tụ")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                .frame(minWidth: 42)
                            
                            Button(action: {
                                if viewModel.numberOfPlayers < viewModel.gameType.maxPlayers {
                                    viewModel.numberOfPlayers += 1
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(viewModel.numberOfPlayers < viewModel.gameType.maxPlayers ? .white : .gray)
                                    .frame(width: 24, height: 24)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(5)
                            }
                            .disabled(viewModel.numberOfPlayers >= viewModel.gameType.maxPlayers)
                        }
                        .padding(2)
                        .background(Color(red: 0.12, green: 0.15, blue: 0.22))
                        .cornerRadius(7)
                    }
                    
                    // Chuyển đổi chế độ chia
                    HStack(spacing: 6) {
                        Button(action: {
                            viewModel.inputMode = .roundRobin
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Chia Tuần Tự")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(viewModel.inputMode == .roundRobin ? .slateDark : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                viewModel.inputMode == .roundRobin
                                    ? Color(red: 1.0, green: 0.84, blue: 0.0)
                                    : Color.white.opacity(0.06)
                            )
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            viewModel.inputMode = .manual
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Chọn Từng Tụ")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(viewModel.inputMode == .manual ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                viewModel.inputMode == .manual
                                    ? Color.cyan
                                    : Color.white.opacity(0.06)
                            )
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .background(Color(red: 0.09, green: 0.12, blue: 0.18))
                
                // 2. BẢNG ĐỐI CHIẾU THỨ HẠNG REALTIME (Cross-Check Leaderboard)
                if !viewModel.server2LeaderboardChain.isEmpty || !viewModel.server2WinnerTitle.isEmpty {
                    VStack(spacing: 2) {
                        if !viewModel.server2WinnerTitle.isEmpty {
                            Text(viewModel.server2WinnerTitle)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.3))
                                .lineLimit(1)
                        }
                        
                        if !viewModel.server2LeaderboardChain.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    Text("BXH:")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.gray)
                                    
                                    ForEach(Array(viewModel.server2LeaderboardChain.components(separatedBy: " ").enumerated()), id: \.offset) { idx, token in
                                        if token == ">" || token == "=" {
                                            Text(token)
                                                .font(.system(size: 12, weight: .black))
                                                .foregroundColor(token == "=" ? Color.orange : Color.gray)
                                        } else {
                                            Text(token)
                                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Color.white.opacity(0.12))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.14, green: 0.17, blue: 0.25))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.white.opacity(0.1)),
                        alignment: .bottom
                    )
                }
                
                // 3. DANH SÁCH BÀI: BÀI CHUNG (POKER) & BÀI CÁC TỤ
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // KHU VỰC BÀI CHUNG (Dành cho Poker Texas Hold'em 5 lá chung)
                        if viewModel.gameType.communityCardsCount > 0 {
                            Button(action: {
                                viewModel.isSelectingCommunity.toggle()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("BÀI CHUNG (COMMUNITY CARDS)")
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(viewModel.isSelectingCommunity ? .yellow : .white)
                                        
                                        if viewModel.isSelectingCommunity {
                                            Text("● ĐANG CHỌN")
                                                .font(.system(size: 8, weight: .black))
                                                .foregroundColor(.yellow)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(viewModel.communityCards.count)/5 lá")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.yellow)
                                    }
                                    
                                    HStack(spacing: 6) {
                                        ForEach(0..<5) { cIdx in
                                            if cIdx < viewModel.communityCards.count {
                                                Server2CardItemView(card: viewModel.communityCards[cIdx])
                                            } else {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.yellow.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                                    .frame(height: 44)
                                                    .overlay(
                                                        Text(cIdx < 3 ? "Flop" : (cIdx == 3 ? "Turn" : "River"))
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(Color.yellow.opacity(0.4))
                                                    )
                                            }
                                        }
                                    }
                                }
                                .padding(8)
                                .background(
                                    viewModel.isSelectingCommunity
                                        ? Color(red: 0.22, green: 0.18, blue: 0.08)
                                        : Color(red: 0.12, green: 0.15, blue: 0.20)
                                )
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(viewModel.isSelectingCommunity ? Color.yellow : Color.yellow.opacity(0.25), lineWidth: viewModel.isSelectingCommunity ? 2 : 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // LƯỚI TỤ BÀI
                        ForEach(0..<viewModel.players.count, id: \.self) { pIdx in
                            let targetCount = viewModel.targetCards(for: pIdx)
                            Server2PlayerRowView(
                                player: viewModel.players[pIdx],
                                playerIndex: pIdx,
                                targetCardsCount: targetCount,
                                isSelected: !viewModel.isSelectingCommunity && viewModel.selectedPlayerIndex == pIdx,
                                handResult: viewModel.server2HandResults.indices.contains(pIdx) ? viewModel.server2HandResults[pIdx] : nil
                            ) {
                                viewModel.isSelectingCommunity = false
                                viewModel.selectedPlayerIndex = pIdx
                                viewModel.roundRobinPointer = pIdx
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                
                Divider()
                    .background(Color.white.opacity(0.15))
                
                // 4. BÀN PHÍM PHƯƠNG ÁN 1 Ở DƯỚI CÙNG (13 Rô + 13 Thường không cần vuốt)
                Server2KeypadView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Row hiển thị từng Tụ bài
struct Server2PlayerRowView: View {
    let player: Player
    let playerIndex: Int
    let targetCardsCount: Int
    let isSelected: Bool
    let handResult: Server2HandResult?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                // Header của tụ: Tên tụ + Thứ hạng + Kết quả điểm
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("Tụ \(playerIndex + 1)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(isSelected ? .cyan : .white)
                        
                        if isSelected {
                            Text("● ĐANG CHỌN")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(.cyan)
                        }
                    }
                    
                    Spacer()
                    
                    // Kết quả tính điểm
                    if !player.resultTitle.isEmpty {
                        Text(player.resultTitle)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(player.resultTitle.contains("♦") ? .roseAccent : .green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.10))
                            .cornerRadius(5)
                            .lineLimit(1)
                    }
                    
                    // Huy hiệu thứ hạng (Hạng 1, 2, 3...)
                    if let rank = player.rankOrder {
                        let rankInfo = Server2ThreeCardEvaluator.getRankTheme(rank: rank, isComplete: true)
                        Text(rankInfo.badgeText)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(rankInfo.primaryColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(rankInfo.backgroundColor)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(rankInfo.primaryColor.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                
                // Ô các lá bài
                if targetCardsCount <= 5 {
                    HStack(spacing: 6) {
                        ForEach(0..<targetCardsCount, id: \.self) { slotIdx in
                            if slotIdx < player.cards.count {
                                Server2CardItemView(card: player.cards[slotIdx])
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                    .frame(height: 44)
                                    .overlay(
                                        Text("\(slotIdx + 1)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color.white.opacity(0.2))
                                    )
                            }
                        }
                    }
                } else {
                    // Nếu game nhiều bài (Phỏm 9 lá, Sâm 10 lá, Binh 6/9 lá): cuộn ngang
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(0..<targetCardsCount, id: \.self) { slotIdx in
                                if slotIdx < player.cards.count {
                                    Server2CardItemView(card: player.cards[slotIdx])
                                        .frame(width: 36)
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                        .frame(width: 36, height: 44)
                                        .overlay(
                                            Text("\(slotIdx + 1)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(Color.white.opacity(0.2))
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(
                isSelected
                    ? Color(red: 0.10, green: 0.16, blue: 0.24)
                    : Color(red: 0.10, green: 0.12, blue: 0.17)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.cyan : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Color.cyan.opacity(0.25) : Color.clear, radius: 3, x: 0, y: 1)
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.28, green: 0.22, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.yellow.opacity(0.6), lineWidth: 1.5)
                    )
                Text("?")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Color.yellow)
            } else if card.isRo {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color.roseAccent, Color(red: 0.80, green: 0.10, blue: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                
                HStack(spacing: 1) {
                    Text(card.rank.displaySymbol)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("♦")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.18, green: 0.22, blue: 0.30))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                
                Text(card.rank.displaySymbol)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}

extension Color {
    static let slateDark = Color(red: 0.08, green: 0.10, blue: 0.15)
}
