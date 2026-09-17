import SwiftUI

public struct Deck52GridView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // 4 Suits in logical display order
    let suits: [Suit] = [.hearts, .diamonds, .clubs, .spades]
    let ranks: [Rank] = Rank.allCases // 2 to Ace
    
    public var body: some View {
        if viewModel.isRankOnlyActive {
            RankOnlyGridView(viewModel: viewModel)
        } else {
            VStack(spacing: 3) {
                ForEach(suits) { suit in
                    HStack(spacing: 3) {
                        // 13 ranks for this suit (no suit header to maximize card width)
                        ForEach(ranks) { rank in
                            let card = Card(rank: rank, suit: suit)
                            let owner = viewModel.cardOwner(card)
                            
                            CardButton(card: card, owner: owner) {
                                viewModel.onCardTapped(card)
                            }
                        }
                    }
                }
            }
            .padding(4)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - Rank-Only Keypad (A -> K for 3 Cây & 2 Lá)
public struct RankOnlyGridView: View {
    @ObservedObject var viewModel: GameViewModel
    
    let row1: [Rank] = [.ace, .two, .three, .four, .five]
    let row2: [Rank] = [.six, .seven, .eight, .nine, .ten]
    let row3: [Rank] = [.jack, .queen, .king]
    
    public var body: some View {
        VStack(spacing: 6) {
            // Row 1: A, 2, 3, 4, 5
            HStack(spacing: 6) {
                ForEach(row1) { rank in
                    RankButton(rank: rank) {
                        viewModel.onRankTapped(rank)
                    }
                }
            }
            
            // Row 2: 6, 7, 8, 9, 10
            HStack(spacing: 6) {
                ForEach(row2) { rank in
                    RankButton(rank: rank) {
                        viewModel.onRankTapped(rank)
                    }
                }
            }
            
            // Row 3: J, Q, K
            HStack(spacing: 6) {
                ForEach(row3) { rank in
                    RankButton(rank: rank) {
                        viewModel.onRankTapped(rank)
                    }
                }
            }
        }
        .padding(6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct RankButton: View {
    let rank: Rank
    let action: () -> Void
    
    var textColor: Color {
        if rank == .ace { return .red }
        if rank == .jack || rank == .queen || rank == .king { return .blue }
        return .primary
    }
    
    var body: some View {
        Button(action: action) {
            Text(rank.displaySymbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CardButton: View {
    let card: Card
    let owner: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 1) {
                    Text(card.rank.displaySymbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                    
                    Text(card.suit.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(owner != nil ? Color.gray.opacity(0.2) : Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(owner != nil ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: owner != nil ? 1.5 : 1)
                )
                .opacity(owner != nil ? 0.6 : 1.0)
                
                // Badge of current owner (Tụ 1, Tụ 2, Bài chung...)
                if let owner = owner {
                    Text(shortOwner(owner))
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .offset(x: 2, y: -4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(owner != nil) // Locked when already chosen! Tap card on mat to remove
    }
    
    private func shortOwner(_ name: String) -> String {
        if name.contains("Tụ ") {
            return name.replacingOccurrences(of: "Tụ ", with: "")
        }
        if name.contains("Nhóm ") {
            return name.replacingOccurrences(of: "Nhóm ", with: "")
        }
        if name == "Bài chung" { return "BC" }
        return String(name.prefix(2))
    }
}
