import Foundation

public class OmahaEvaluator {
    
    // Evaluates Omaha hand: strictly 2 cards from holeCards (4) + 3 cards from boardCards (5)
    public static func evaluateOmaha(holeCards: [Card], boardCards: [Card]) -> PokerHandScore {
        guard holeCards.count >= 2 && boardCards.count >= 3 else {
            return PokerHandScore(
                handType: .highCard,
                tieBreakers: [0],
                cards: [],
                descriptionVN: "Không đủ bài Omaha (cần tối thiểu 2 tẩy và 3 chung)"
            )
        }
        
        let holePairs = PokerEvaluator.combinations(of: holeCards, k: 2)
        let boardTriplets = PokerEvaluator.combinations(of: boardCards, k: 3)
        
        var bestHand: PokerHandScore? = nil
        
        for hPair in holePairs {
            for bTrip in boardTriplets {
                let fiveCardHand = hPair + bTrip
                let handScore = PokerEvaluator.evaluate5Cards(fiveCardHand)
                if bestHand == nil || handScore > bestHand! {
                    bestHand = handScore
                }
            }
        }
        
        return bestHand!
    }
}
