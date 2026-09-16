import SwiftUI

public struct Deck52GridView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // 4 Suits in logical display order
    let suits: [Suit] = [.hearts, .diamonds, .clubs, .spades]
    let ranks: [Rank] = Rank.allCases // 2 to Ace
    
    public var body: some View {
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
                
                // Badge of current owner (A, B, C or Board)
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
    }
    
    private func shortOwner(_ name: String) -> String {
        if name.contains("Nhóm ") {
            return name.replacingOccurrences(of: "Nhóm ", with: "")
        }
        if name == "Bài chung" { return "BC" }
        return String(name.prefix(2))
    }
}
