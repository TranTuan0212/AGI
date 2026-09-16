import Foundation
import SwiftUI
import Combine

public enum InputMode: String, CaseIterable, Identifiable {
    case roundRobin = "Chia Tuần Tự (A ➔ B ➔ C)"
    case manual = "Chọn Thủ Công Từng Nhóm"
    
    public var id: String { rawValue }
    
    public var shortTitle: String {
        switch self {
        case .roundRobin: return "Chia Tuần Tự"
        case .manual: return "Chọn Thủ Công"
        }
    }
}

public class GameViewModel: ObservableObject {
    @Published public var gameType: GameType = .binh13 {
        didSet {
            resetTable()
        }
    }
    
    @Published public var suitPreset: SuitRulePreset = .north {
        didSet {
            if hasCalculatedResults {
                calculateResults()
            }
        }
    }
    
    @Published public var inputMode: InputMode = .roundRobin
    @Published public var numberOfPlayers: Int = 3 {
        didSet {
            updatePlayerCount()
        }
    }
    
    @Published public var players: [Player] = []
    @Published public var communityCards: [Card] = []
    @Published public var selectedPlayerIndex: Int = 0
    @Published public var roundRobinPointer: Int = 0
    
    // Result State
    @Published public var hasCalculatedResults: Bool = false
    @Published public var isShowResultModal: Bool = false
    @Published public var isShowingHistory: Bool = false
    @Published public var showdownSummary: String = ""
    @Published public var confrontationMatrix: [[String]] = []
    
    // Match History
    @Published public var history: [MatchHistoryRecord] = []
    
    // Action History for Undo
    private var actionHistory: [(card: Card, target: String)] = []
    
    public func renamePlayer(at index: Int, to newName: String) {
        guard index >= 0 && index < players.count else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            players[index].name = trimmed
        }
    }

    
    public init() {
        setupInitialPlayers()
    }
    
    private func setupInitialPlayers() {
        let names = ["Nhóm A", "Nhóm B", "Nhóm C", "Nhóm D", "Nhóm E", "Nhóm F", "Nhóm G", "Nhóm H"]
        players = (0..<numberOfPlayers).map { i in
            Player(name: names[i % names.count])
        }
    }
    
    private func updatePlayerCount() {
        let names = ["Nhóm A", "Nhóm B", "Nhóm C", "Nhóm D", "Nhóm E", "Nhóm F", "Nhóm G", "Nhóm H", "Nhóm I", "Nhóm K"]
        if players.count < numberOfPlayers {
            for i in players.count..<numberOfPlayers {
                players.append(Player(name: names[i % names.count]))
            }
        } else if players.count > numberOfPlayers {
            players = Array(players.prefix(numberOfPlayers))
        }
        resetTable()
    }
    
    public func resetTable() {
        for i in 0..<players.count {
            players[i].clearCards()
        }
        communityCards.removeAll()
        roundRobinPointer = 0
        selectedPlayerIndex = 0
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        actionHistory.removeAll()
    }
    
    // Check if a card is currently assigned
    public func cardOwner(_ card: Card) -> String? {
        for p in players {
            if p.cards.contains(card) {
                return p.name
            }
        }
        if communityCards.contains(card) {
            return "Bài chung"
        }
        return nil
    }
    
    // Handle card click
    public func onCardTapped(_ card: Card) {
        // If already selected, remove it
        if let owner = cardOwner(card) {
            removeCard(card)
            return
        }
        
        let targetCount = gameType.cardsPerPlayer
        let commTargetCount = gameType.communityCardsCount
        
        if inputMode == .roundRobin {
            // Find next player who still needs cards
            var attempts = 0
            while attempts < players.count {
                let idx = (roundRobinPointer + attempts) % players.count
                if players[idx].cards.count < targetCount {
                    players[idx].cards.append(card)
                    actionHistory.append((card: card, target: players[idx].id))
                    roundRobinPointer = (idx + 1) % players.count
                    return
                }
                attempts += 1
            }
            
            // If all players have full cards, check community cards
            if communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
                return
            }
            
        } else {
            // Manual selection mode
            if selectedPlayerIndex < players.count {
                if players[selectedPlayerIndex].cards.count < targetCount {
                    players[selectedPlayerIndex].cards.append(card)
                    actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                    
                    // Auto-advance to next player if current player is full
                    if players[selectedPlayerIndex].cards.count == targetCount && selectedPlayerIndex < players.count - 1 {
                        selectedPlayerIndex += 1
                    }
                } else if selectedPlayerIndex == players.count - 1 && communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            }
        }
        
        // Auto-calculate immediately when all cards are dealt
        if isReadyToCalculate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self, self.isReadyToCalculate else { return }
                self.calculateResults()
            }
        }
    }
    
    // Clear calculated results when cards change
    private func clearResultsState() {
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        for i in 0..<players.count {
            players[i].rankOrder = nil
            players[i].score = 0
            players[i].resultTitle = ""
            players[i].resultDetail = ""
            players[i].isLung = false
        }
    }
    
    // Remove specific card
    public func removeCard(_ card: Card) {
        for i in 0..<players.count {
            if let idx = players[i].cards.firstIndex(of: card) {
                players[i].cards.remove(at: idx)
                actionHistory.removeAll { $0.card == card }
                clearResultsState()
                return
            }
        }
        if let idx = communityCards.firstIndex(of: card) {
            communityCards.remove(at: idx)
            actionHistory.removeAll { $0.card == card }
            clearResultsState()
        }
    }
    
    // Undo last card tap
    public func undoLastAction() {
        guard let last = actionHistory.popLast() else { return }
        removeCard(last.card)
    }
    
    // Auto Deal Random Cards for testing
    public func autoDealRandom() {
        resetTable()
        var deck = Card.fullDeck52.shuffled()
        let targetCount = gameType.cardsPerPlayer
        let commTargetCount = gameType.communityCardsCount
        
        for i in 0..<players.count {
            let dealt = Array(deck.prefix(targetCount))
            players[i].cards = dealt
            deck.removeFirst(targetCount)
        }
        
        if commTargetCount > 0 {
            let commDealt = Array(deck.prefix(commTargetCount))
            communityCards = commDealt
            deck.removeFirst(commTargetCount)
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Check if table is ready for calculation
    public var isReadyToCalculate: Bool {
        let allPlayersFull = players.allSatisfy { $0.cards.count == gameType.cardsPerPlayer }
        let commFull = communityCards.count == gameType.communityCardsCount
        return allPlayersFull && commFull
    }
    
    // Calculate Winner & Results
    public func calculateResults() {
        guard isReadyToCalculate else { return }
        
        switch gameType {
        case .phom9:
            calculatePhom()
        case .binh13:
            calculateBinh13()
        case .binh9:
            calculateBinh9()
        case .binh6Poker:
            calculateBinh6Poker()
        case .binh6Split:
            calculateBinh6Split()
        case .lieng3:
            calculateLieng()
        case .texasHoldem:
            calculateTexasHoldem()
        }
        
        recordMatchToHistory()
        hasCalculatedResults = true
        isShowResultModal = true
    }
    
    private func recordMatchToHistory() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        
        let winner = players.min(by: { ($0.rankOrder ?? 99) < ($1.rankOrder ?? 99) })
        let scores = players.map {
            PlayerScoreHistory(name: $0.name, rank: $0.rankOrder ?? 0, score: $0.score, hand: $0.resultTitle)
        }
        let record = MatchHistoryRecord(
            id: UUID(),
            time: timeStr,
            gameName: gameType.rawValue,
            winnerName: winner?.name ?? "—",
            winnerDetail: winner?.resultTitle ?? "",
            playerScores: scores
        )
        history.insert(record, at: 0)
        if history.count > 50 {
            history.removeLast()
        }
    }

    
    // MARK: - Game Calculation Logic
    
    private func calculatePhom() {
        let inputList = players.enumerated().map { (index: $0.offset, name: $0.element.name, cards: $0.element.cards) }
        let ranked = PhomEvaluator.rankPlayers(players: inputList)
        
        for item in ranked {
            let idx = item.index
            players[idx].rankOrder = item.rank
            players[idx].score = item.scoreDelta
            players[idx].resultTitle = item.result.isU ? "🎉 Ù (0 điểm)" : (item.result.isMom ? "💀 Móm / Cháy (\(item.result.deadwoodScore)đ)" : "\(item.result.deadwoodScore) điểm rác (\(item.result.phoms.count) phỏm)")
            players[idx].resultDetail = item.result.summary
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Hòa ván Phỏm với \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng ván Phỏm với \(winner.resultTitle)!"
        }
    }
    
    private func calculateLieng() {
        var scores = [(index: Int, score: LiengHandScore)]()
        for (i, p) in players.enumerated() {
            let score = LiengEvaluator.evaluate(cards: p.cards, suitRule: suitPreset)
            scores.append((index: i, score: score))
            players[i].resultTitle = score.descriptionVN
            players[i].resultDetail = "Loại: \(score.handType.nameVN)"
        }
        
        scores.sort { $0.score > $1.score }
        
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng cuộc với \(winner.resultTitle)!"
        }
    }
    
    private func calculateTexasHoldem() {
        var scores = [(index: Int, score: PokerHandScore)]()
        for (i, p) in players.enumerated() {
            let allCards = p.cards + communityCards
            let score = PokerEvaluator.evaluate7Cards(allCards)
            scores.append((index: i, score: score))
            players[i].resultTitle = score.descriptionVN
            players[i].resultDetail = "Bộ bài 5 lá tốt nhất: \(score.cards.map { $0.displayName }.joined(separator: " "))"
        }
        
        scores.sort { $0.score > $1.score }
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1 (Split Pot): \(names) với \(rank1Players[0].resultTitle)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Pot với \(winner.resultTitle)!"
        }
    }
    
    private func calculateBinh13() {
        var arrangements = [Binh13Arrangement]()
        for i in 0..<players.count {
            let arr = Binh13Evaluator.autoArrange(cards: players[i].cards)
            arrangements.append(arr)
            players[i].isLung = arr.isLung
            if let instant = arr.instantWin {
                players[i].resultTitle = instant.nameVN
                players[i].resultDetail = "Tự động Thắng Trắng mà không cần so từng chi!"
            } else if arr.isLung {
                players[i].resultTitle = "⚠️ BỊ LỦNG"
                players[i].resultDetail = "Chi dưới yếu hơn chi trên hoặc chi giữa!"
            } else {
                players[i].resultTitle = "Đã xếp 3 chi tối ưu"
                players[i].resultDetail = "Chi 1 (3 lá): \(arr.frontScore.descriptionVN)\nChi 2 (5 lá): \(arr.middleScore.descriptionVN)\nChi 3 (5 lá): \(arr.backScore.descriptionVN)"
            }
            players[i].score = 0
        }
        
        // Matrix showdown
        var matrix = Array(repeating: Array(repeating: "-", count: players.count), count: players.count)
        
        for i in 0..<players.count {
            for j in 0..<players.count {
                if i == j {
                    matrix[i][j] = "—"
                } else if i < j {
                    let res = Binh13Evaluator.compareMatch(a: arrangements[i], b: arrangements[j])
                    players[i].score += res.scoreA
                    players[j].score -= res.scoreA
                    matrix[i][j] = "\(res.scoreA > 0 ? "+\(res.scoreA)" : "\(res.scoreA)") chi"
                    matrix[j][i] = "\(-res.scoreA > 0 ? "+\(-res.scoreA)" : "\(-res.scoreA)") chi"
                }
            }
        }
        
        confrontationMatrix = matrix
        
        // Sort by total score with tie awareness
        var sortedIndices = Array(0..<players.count)
        sortedIndices.sort { players[$0].score > players[$1].score }
        var currentRank = 1
        for i in 0..<sortedIndices.count {
            let idx = sortedIndices[i]
            if i > 0 {
                let prevIdx = sortedIndices[i - 1]
                if players[idx].score < players[prevIdx].score {
                    currentRank = i + 1
                }
            }
            players[idx].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].score > 0 ? "+\(rank1Players[0].score)" : "\(rank1Players[0].score)") chi)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Dẫn đầu với tổng điểm: \(winner.score > 0 ? "+\(winner.score)" : "\(winner.score)") chi!"
        }
    }
    
    private func calculateBinh9() {
        var arrangements = [Binh9Arrangement]()
        for i in 0..<players.count {
            let arr = Binh9Evaluator.autoArrange(cards: players[i].cards)
            arrangements.append(arr)
            players[i].isLung = arr.isLung
            if let win = arr.instantWin {
                players[i].resultTitle = win
                players[i].resultDetail = "Thắng trắng!"
            } else if arr.isLung {
                players[i].resultTitle = "⚠️ BỊ LỦNG"
                players[i].resultDetail = "Chi trước yếu hơn chi sau!"
            } else {
                players[i].resultTitle = "Xếp 3 chi (3-3-3)"
                players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN)\nChi 2: \(arr.score2.descriptionVN)\nChi 3: \(arr.score3.descriptionVN)"
            }
            players[i].score = 0
        }
        
        for i in 0..<players.count {
            for j in (i+1)..<players.count {
                let res = Binh9Evaluator.compareMatch(a: arrangements[i], b: arrangements[j])
                players[i].score += res.scoreA
                players[j].score -= res.scoreA
            }
        }
        
        var sortedIndices = Array(0..<players.count)
        sortedIndices.sort { players[$0].score > players[$1].score }
        var currentRank = 1
        for i in 0..<sortedIndices.count {
            let idx = sortedIndices[i]
            if i > 0 {
                let prevIdx = sortedIndices[i - 1]
                if players[idx].score < players[prevIdx].score {
                    currentRank = i + 1
                }
            }
            players[idx].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].score > 0 ? "+\(rank1Players[0].score)" : "\(rank1Players[0].score)") chi)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Về Nhất Binh 9 lá với \(winner.score > 0 ? "+\(winner.score)" : "\(winner.score)") chi!"
        }
    }
    
    private func calculateBinh6Poker() {
        var scores = [(index: Int, score: PokerHandScore)]()
        for (i, p) in players.enumerated() {
            let s = Binh6Evaluator.evaluatePoker6(p.cards)
            scores.append((index: i, score: s))
            players[i].resultTitle = s.descriptionVN
            players[i].resultDetail = "Bộ 5 lá tốt nhất từ 6 lá: \(s.cards.map { $0.displayName }.joined(separator: " "))"
        }
        scores.sort { $0.score > $1.score }
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) với \(rank1Players[0].resultTitle)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Binh 6 lá với \(winner.resultTitle)!"
        }
    }
    
    private func calculateBinh6Split() {
        var arrangements = [Binh6SplitArrangement]()
        for i in 0..<players.count {
            let arr = Binh6Evaluator.autoArrangeSplit(players[i].cards)
            arrangements.append(arr)
            players[i].isLung = arr.isLung
            players[i].resultTitle = arr.isLung ? "⚠️ BỊ LỦNG" : "2 Chi (3-3)"
            players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN), Chi 2: \(arr.score2.descriptionVN)"
            players[i].score = 0
        }
        
        for i in 0..<players.count {
            for j in (i+1)..<players.count {
                let res = Binh6Evaluator.compareSplit(a: arrangements[i], b: arrangements[j])
                players[i].score += res.scoreA
                players[j].score -= res.scoreA
            }
        }
        
        var sortedIndices = Array(0..<players.count)
        sortedIndices.sort { players[$0].score > players[$1].score }
        var currentRank = 1
        for i in 0..<sortedIndices.count {
            let idx = sortedIndices[i]
            if i > 0 {
                let prevIdx = sortedIndices[i - 1]
                if players[idx].score < players[prevIdx].score {
                    currentRank = i + 1
                }
            }
            players[idx].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].score > 0 ? "+\(rank1Players[0].score)" : "\(rank1Players[0].score)") chi)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Binh 6 lá 2 Chi với \(winner.score > 0 ? "+\(winner.score)" : "\(winner.score)") chi!"
        }
    }
}
