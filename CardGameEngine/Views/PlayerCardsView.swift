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
                let isCommSelected = viewModel.inputMode == .manual && viewModel.isSelectingCommunity && !viewModel.hasCalculatedResults
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
                            let remaining = viewModel.gameType.communityCardsCount - viewModel.communityCards.count
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
            VStack(spacing: 5) {
                ForEach(0..<viewModel.players.count, id: \.self) { idx in
                    let player = viewModel.players[idx]
                    let isWinner = viewModel.hasCalculatedResults && player.rankOrder == 1
                    let isCurrentRoundRobin = viewModel.inputMode == .roundRobin && viewModel.roundRobinPointer == idx && !viewModel.hasCalculatedResults
                    let isManualSelected = viewModel.inputMode == .manual && viewModel.selectedPlayerIndex == idx && !viewModel.hasCalculatedResults
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
                                                (isTie ? "Đ.Hạng \(rank)" : "Bét")))
                                HStack(spacing: 4) {
                                    Text(badgeText)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(rank == 1 ? .yellow : (rank == 2 ? .blue : .secondary))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(rank == 1 ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.15))
                                        .cornerRadius(4)
                                    
                                    Text("\(player.score >= 0 ? "+" : "")\(player.score) chi")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(player.score > 0 ? .green : (player.score < 0 ? .red : .secondary))
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
                            
                            // Result hand title OR Card counter
                            if let _ = player.rankOrder, !player.resultTitle.isEmpty {
                                Text(player.resultTitle)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isWinner ? .orange : .primary)
                                    .lineLimit(1)
                            } else {
                                Text("\(player.cards.count)/\(viewModel.gameType.cardsPerPlayer)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(player.cards.count == viewModel.gameType.cardsPerPlayer ? .blue : .secondary)
                            }
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
                                let missing = viewModel.gameType.cardsPerPlayer - player.cards.count
                                let showCount = min(missing, 6)
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
            Text("Nhập tên hiển thị mới cho nhóm này:")
        }
    }
}

struct MiniCardView: View {
    let card: Card
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onRemove) {
            VStack(spacing: 0) {
                Text(card.rank.displaySymbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(card.suit.isRed ? .red : .black)
                Text(card.suit.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(card.suit.isRed ? .red : .black)
            }
            .frame(width: 28, height: 38)
            .background(Color.white)
            .cornerRadius(4)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
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
