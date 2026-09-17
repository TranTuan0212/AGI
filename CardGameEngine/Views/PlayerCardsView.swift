import SwiftUI

public struct PlayerCardsView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var isShowingRenameDialog = false
    @State private var editingIndex: Int = 0
    @State private var editingName: String = ""
    
    public var body: some View {

        VStack(alignment: .leading, spacing: 6) {
            // Community Cards (If applicable)
            if viewModel.gameType.communityCardsCount > 0 {
                let allPlayersFull = viewModel.players.indices.allSatisfy { viewModel.players[$0].cards.count >= viewModel.targetCards(for: $0) }
                let commNeedsCards = viewModel.communityCards.count < viewModel.gameType.communityCardsCount
                let isCommSelected = commNeedsCards && !viewModel.hasCalculatedResults && (viewModel.isSelectingCommunity || allPlayersFull)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Label("Bài Chung", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        
                        if isCommSelected {
                            Text("▶ Đang chọn")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Text("\(viewModel.communityCards.count)/\(viewModel.gameType.communityCardsCount) lá")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(viewModel.communityCards) { card in
                                MiniCardView(card: card) {
                                    viewModel.removeCard(card)
                                }
                            }
                            
                            // Placeholders
                            let remaining = max(0, viewModel.gameType.communityCardsCount - viewModel.communityCards.count)
                            if remaining > 0 {
                                ForEach(0..<remaining, id: \.self) { _ in
                                    CardPlaceholderView()
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isCommSelected ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isCommSelected ? Color.green : Color.orange.opacity(0.3), lineWidth: isCommSelected ? 1.5 : 1)
                )
                .onTapGesture {
                    if viewModel.inputMode == .manual {
                        viewModel.isSelectingCommunity = true
                    }
                }
            }
            
            // Player mats
            let allPlayersFull = viewModel.players.indices.allSatisfy { viewModel.players[$0].cards.count >= viewModel.targetCards(for: $0) }
            let commNeedsCards = viewModel.gameType.communityCardsCount > 0 && viewModel.communityCards.count < viewModel.gameType.communityCardsCount
            let isCommActive = commNeedsCards && !viewModel.hasCalculatedResults && (viewModel.isSelectingCommunity || allPlayersFull)

            VStack(spacing: 5) {
                ForEach(0..<viewModel.players.count, id: \.self) { idx in
                    let player = viewModel.players[idx]
                    let target = viewModel.targetCards(for: idx)
                    let isWinner = viewModel.hasCalculatedResults && player.rankOrder == 1
                    let isCurrentRoundRobin = viewModel.inputMode == .roundRobin && viewModel.roundRobinPointer == idx && !viewModel.hasCalculatedResults && !allPlayersFull
                    let isManualSelected = viewModel.inputMode == .manual && viewModel.selectedPlayerIndex == idx && !viewModel.isSelectingCommunity && !viewModel.hasCalculatedResults && !isCommActive
                    let isHighlight = isCurrentRoundRobin || isManualSelected || isWinner
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Circle()
                                .fill(isWinner ? Color.yellow : (isHighlight ? Color.green : Color.gray.opacity(0.4)))
                                .frame(width: 8, height: 8)
                            
                            Button(action: {
                                editingIndex = idx
                                editingName = player.name
                                isShowingRenameDialog = true
                            }) {
                                HStack(spacing: 3) {
                                    Text(player.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isWinner ? .orange : (isHighlight ? .primary : .secondary))
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            if let rank = player.rankOrder {
                                let isTie = viewModel.players.filter({ $0.rankOrder == rank }).count > 1
                                let badgeText = rank == 1 ? (isTie ? "👑 Đ.Hạng 1" : "👑 Nhất") :
                                                (rank == 2 ? (isTie ? "🥈 Đ.Hạng 2" : "🥈 Nhì") :
                                                (rank == 3 ? (isTie ? "🥉 Đ.Hạng 3" : "🥉 Ba") :
                                                (isTie ? "Đ.Hạng \(rank)" : "Hạng \(rank)")))
                                HStack(spacing: 5) {
                                    Text(badgeText)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(rank == 1 ? .yellow : (rank == 2 ? .blue : .secondary))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(rank == 1 ? Color.yellow.opacity(0.25) : Color.gray.opacity(0.18))
                                        .cornerRadius(4)
                                    
                                    if !player.resultTitle.isEmpty {
                                        Text(player.resultTitle)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(isWinner ? .orange : .primary)
                                            .lineLimit(1)
                                    }
                                    
                                    if player.score != 0 {
                                        Text("\(player.score >= 0 ? "+" : "")\(player.score) chi")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(player.score > 0 ? .green : (player.score < 0 ? .red : .secondary))
                                    }
                                }
                            } else if isHighlight {
                                Text(viewModel.inputMode == .roundRobin ? "▶ Lượt" : "▶ Đang chọn")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            // Card counter
                            Text("\(player.cards.count)/\(target)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(player.cards.count == target ? .blue : .secondary)
                        }
                        
                        // Cards display
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(player.cards) { card in
                                    MiniCardView(card: card) {
                                        viewModel.removeCard(card)
                                    }
                                }
                                
                                // Placeholders (show up to 6 placeholders to save space)
                                let missing = target - player.cards.count
                                let showCount = max(0, min(missing, 6))
                                if showCount > 0 {
                                    ForEach(0..<showCount, id: \.self) { _ in
                                        CardPlaceholderView()
                                    }
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isWinner ? Color.yellow.opacity(0.12) :
                        (isHighlight ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isWinner ? Color.yellow : (isHighlight ? Color.accentColor : Color.clear), lineWidth: 1.5)
                    )
                    .onTapGesture {
                        if viewModel.inputMode == .manual {
                            viewModel.selectedPlayerIndex = idx
                            viewModel.isSelectingCommunity = false
                        }
                    }
                }
            }
        }
        .alert("Đổi Tên Người Chơi", isPresented: $isShowingRenameDialog) {
            TextField("Nhập tên mới", text: $editingName)
            Button("Lưu") {
                viewModel.renamePlayer(at: editingIndex, to: editingName)
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Nhập tên hiển thị mới cho tụ này:")
        }
    }
}

struct MiniCardView: View {
    let card: Card
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onRemove) {
            if card.isRankOnly {
                Text(card.rank.displaySymbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(card.rank == .ace ? .red : (card.rank == .jack || card.rank == .queen || card.rank == .king ? .blue : .black))
                    .frame(width: 32, height: 40)
                    .background(Color.white)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            } else {
                VStack(spacing: 0) {
                    Text(card.rank.displaySymbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                    Text(card.suit.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                }
                .frame(width: 26, height: 36)
                .background(Color.white)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CardPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2]))
            .foregroundColor(Color.gray.opacity(0.35))
            .frame(width: 28, height: 38)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 9))
                    .foregroundColor(Color.gray.opacity(0.4))
            )
    }
}
