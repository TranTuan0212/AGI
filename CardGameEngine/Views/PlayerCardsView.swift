import SwiftUI

public struct PlayerCardsView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var isShowingRenameDialog = false
    @State private var editingIndex: Int = 0
    @State private var editingName: String = ""
    
    public var body: some View {

        VStack(alignment: .leading, spacing: 10) {
            // Community Cards (If applicable)
            if viewModel.gameType.communityCardsCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Bài Chung (Board)", systemImage: "rectangle.stack.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Text("\(viewModel.communityCards.count)/\(viewModel.gameType.communityCardsCount) lá")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
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
                        .padding(.vertical, 4)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Player mats
            VStack(spacing: 8) {
                ForEach(0..<viewModel.players.count, id: \.self) { idx in
                    let player = viewModel.players[idx]
                    let isCurrentRoundRobin = viewModel.inputMode == .roundRobin && viewModel.roundRobinPointer == idx
                    let isManualSelected = viewModel.inputMode == .manual && viewModel.selectedPlayerIndex == idx
                    let isHighlight = isCurrentRoundRobin || isManualSelected
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(isHighlight ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 10, height: 10)
                            
                            Button(action: {
                                editingIndex = idx
                                editingName = player.name
                                isShowingRenameDialog = true
                            }) {
                                HStack(spacing: 4) {
                                    Text(player.name)
                                        .font(.headline)
                                        .foregroundColor(isHighlight ? .primary : .secondary)
                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            
                            if isHighlight {
                                Text(viewModel.inputMode == .roundRobin ? "▶ Lượt nhận" : "▶ Đang chọn")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            // Card counter
                            Text("\(player.cards.count)/\(viewModel.gameType.cardsPerPlayer) lá")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(player.cards.count == viewModel.gameType.cardsPerPlayer ? .blue : .secondary)
                        }
                        
                        // Cards display
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(player.cards) { card in
                                    MiniCardView(card: card) {
                                        viewModel.removeCard(card)
                                    }
                                }
                                
                                // Placeholders
                                let missing = viewModel.gameType.cardsPerPlayer - player.cards.count
                                if missing > 0 {
                                    ForEach(0..<missing, id: \.self) { _ in
                                        CardPlaceholderView()
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isHighlight ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHighlight ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                    .onTapGesture {
                        if viewModel.inputMode == .manual {
                            viewModel.selectedPlayerIndex = idx
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(card.suit.isRed ? .red : .black)
                Text(card.suit.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(card.suit.isRed ? .red : .black)
            }
            .frame(width: 32, height: 44)
            .background(Color.white)
            .cornerRadius(5)
            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CardPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
            .foregroundColor(Color.gray.opacity(0.35))
            .frame(width: 32, height: 44)
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundColor(Color.gray.opacity(0.4))
            )
    }
}
