import Foundation

public class Binh6Evaluator {
    // 6-card Poker Hand (best 5 out of 6)
    public static func evaluatePoker6(_ cards: [Card]) -> PokerHandScore {
        return PokerEvaluator.evaluate7Cards(cards)
    }
}

