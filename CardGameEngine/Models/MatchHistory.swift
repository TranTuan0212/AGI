import Foundation

public struct PlayerScoreHistory: Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let rank: Int
    public let score: Int
    public let hand: String
    
    public init(name: String, rank: Int, score: Int, hand: String) {
        self.name = name
        self.rank = rank
        self.score = score
        self.hand = hand
    }
}

public struct MatchHistoryRecord: Identifiable, Codable {
    public let id: UUID
    public let time: String
    public let gameName: String
    public let winnerName: String
    public let winnerDetail: String
    public let playerScores: [PlayerScoreHistory]
    
    public init(id: UUID = UUID(), time: String, gameName: String, winnerName: String, winnerDetail: String, playerScores: [PlayerScoreHistory]) {
        self.id = id
        self.time = time
        self.gameName = gameName
        self.winnerName = winnerName
        self.winnerDetail = winnerDetail
        self.playerScores = playerScores
    }
}
