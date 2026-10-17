import Foundation
import SwiftUI

public enum Server2HandType: String, Codable {
    case empty
    case partial
    case sap
    case lieng
    case threeTay
    case points
}

public struct Server2HandResult: Equatable {
    public let type: Server2HandType
    public let label: String
    public let score: Int
    public let isComplete: Bool
    public let hasUnknown: Bool
    public let hasRo: Bool
    
    public init(
        type: Server2HandType,
        label: String,
        score: Int,
        isComplete: Bool,
        hasUnknown: Bool = false,
        hasRo: Bool = false
    ) {
        self.type = type
        self.label = label
        self.score = score
        self.isComplete = isComplete
        self.hasUnknown = hasUnknown
        self.hasRo = hasRo
    }
}

public struct Server2RankInfo {
    public let rank: Int
    public let badgeText: String
    public let isTie: Bool
    public let isWinner: Bool
    public let primaryColor: Color
    public let backgroundColor: Color
}

public class Server2ThreeCardEvaluator {
    
    /// Đánh giá kết quả của 1 tụ bài 3 lá theo chuẩn Server 2
    public static func evaluate(cards: [Card]) -> Server2HandResult {
        if cards.isEmpty {
            return Server2HandResult(
                type: .empty,
                label: "Chờ nhập",
                score: -1,
                isComplete: false
            )
        }
        
        // 0. Nếu trong nhóm có quân bài ẩn (không thấy / 0)
        let hasUnknown = cards.contains { $0.isHidden }
        if hasUnknown {
            return Server2HandResult(
                type: .points,
                label: "???",
                score: -1,
                isComplete: false,
                hasUnknown: true
            )
        }
        
        // Trường hợp chưa đủ 3 lá (1 hoặc 2 lá)
        if cards.count < 3 {
            let sum = cards.reduce(0) { $0 + $1.server2Value }
            let mod10 = sum % 10
            let hasRo = cards.contains { $0.isRo }
            return Server2HandResult(
                type: .partial,
                label: "\(mod10) Điểm (\(cards.count)/3 lá)\(hasRo ? " (♦)" : "")",
                score: mod10,
                isComplete: false,
                hasRo: hasRo
            )
        }
        
        // Xét 3 lá gần nhất
        let last3 = Array(cards.suffix(3))
        
        // Tính Ro Bonus nếu có quân bài chất Rô
        let roCards = last3.filter { $0.isRo }
        let maxRoPower = roCards.map { $0.rankPower }.max() ?? 0
        // roBonus: nếu có Rô, cộng từ 52 đến 64 (50 + maxRoPower)
        let roBonus = maxRoPower > 0 ? (50 + maxRoPower) : 0
        let roSuffix = roCards.isEmpty ? "" : " (♦)"
        let hasRo = !roCards.isEmpty
        
        let ranks = last3.map { $0.rank }
        
        // 1. Kiểm tra Sáp (Bộ 3 giống nhau / 3 quân cùng rank)
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            let power = last3[0].rankPower
            let display = last3[0].rank.displaySymbol
            return Server2HandResult(
                type: .sap,
                label: "Bộ Ba (\(display)) 👑\(roSuffix)",
                score: 10000 + power * 100 + roBonus,
                isComplete: true,
                hasRo: hasRo
            )
        }
        
        // 2. Kiểm tra Chuỗi liên tiếp (Liêng / 3 số liên tiếp)
        // Ánh xạ thứ tự số: 1..13 (A = 1, J = 11, Q = 12, K = 13)
        let orderNums: [Int] = last3.map { card -> Int in
            switch card.rank {
            case .ace: return 1
            case .jack: return 11
            case .queen: return 12
            case .king: return 13
            default: return card.rank.rawValue
            }
        }.sorted()
        
        var isLieng = false
        var liengPower = 0
        var liengLabel = ""
        
        if orderNums.count == 3 {
            if orderNums[0] == 1 && orderNums[1] == 12 && orderNums[2] == 13 {
                // Q-K-A
                isLieng = true
                liengPower = 14
                liengLabel = "Chuỗi Cao (Q-K-A) ⭐\(roSuffix)"
            } else if orderNums[0] == 1 && orderNums[1] == 2 && orderNums[2] == 3 {
                // A-2-3
                isLieng = true
                liengPower = 3
                liengLabel = "Chuỗi (A-2-3)\(roSuffix)"
            } else if orderNums[0] + 1 == orderNums[1] && orderNums[1] + 1 == orderNums[2] {
                isLieng = true
                liengPower = orderNums[2]
                let d0 = displaySymbolForOrderNum(orderNums[0])
                let d1 = displaySymbolForOrderNum(orderNums[1])
                let d2 = displaySymbolForOrderNum(orderNums[2])
                liengLabel = "Chuỗi (\(d0)-\(d1)-\(d2))\(roSuffix)"
            }
        }
        
        if isLieng {
            return Server2HandResult(
                type: .lieng,
                label: liengLabel,
                score: 5000 + liengPower * 100 + roBonus,
                isComplete: true,
                hasRo: hasRo
            )
        }
        
        // 3. Kiểm tra Nhóm Cao (Ba Tây / cả 3 lá đều là J, Q, K)
        let is3Tay = last3.allSatisfy { $0.rank == .jack || $0.rank == .queen || $0.rank == .king }
        if is3Tay {
            return Server2HandResult(
                type: .threeTay,
                label: "Nhóm Cao (11-13) ✨\(roSuffix)",
                score: 1000 + roBonus,
                isComplete: true,
                hasRo: hasRo
            )
        }
        
        // 4. Tính điểm thường: tổng điểm mod 10
        let sum = last3.reduce(0) { $0 + $1.server2Value }
        let mod10 = sum % 10
        let normalScore = mod10 * 100 + roBonus
        let baseLabel = mod10 == 0 ? "0 Điểm" : "\(mod10) Điểm"
        let labelWithRo = hasRo ? "\(baseLabel) (♦)" : baseLabel
        
        return Server2HandResult(
            type: .points,
            label: labelWithRo,
            score: normalScore,
            isComplete: true,
            hasRo: hasRo
        )
    }
    
    private static func displaySymbolForOrderNum(_ n: Int) -> String {
        switch n {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(n)"
        }
    }
    
    /// Lấy thông tin theme màu sắc và nhãn thứ hạng chuẩn Server 2
    public static func getRankTheme(rank: Int, isComplete: Bool) -> Server2RankInfo {
        if !isComplete {
            return Server2RankInfo(
                rank: rank,
                badgeText: "Hạng \(rank) (Tạm)",
                isTie: false,
                isWinner: false,
                primaryColor: .orange,
                backgroundColor: Color.orange.opacity(0.15)
            )
        }
        
        switch rank {
        case 1:
            return Server2RankInfo(
                rank: 1,
                badgeText: "👑 Hạng 1 (Thắng)",
                isTie: false,
                isWinner: true,
                primaryColor: Color(red: 1.0, green: 0.84, blue: 0.0), // Gold
                backgroundColor: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.18)
            )
        case 2:
            return Server2RankInfo(
                rank: 2,
                badgeText: "🥈 Hạng 2",
                isTie: false,
                isWinner: false,
                primaryColor: Color(red: 0.88, green: 0.90, blue: 0.93), // Silver
                backgroundColor: Color.white.opacity(0.15)
            )
        case 3:
            return Server2RankInfo(
                rank: 3,
                badgeText: "🥉 Hạng 3",
                isTie: false,
                isWinner: false,
                primaryColor: Color(red: 0.80, green: 0.50, blue: 0.20), // Bronze
                backgroundColor: Color.orange.opacity(0.2)
            )
        case 4:
            return Server2RankInfo(
                rank: 4,
                badgeText: "💎 Hạng 4",
                isTie: false,
                isWinner: false,
                primaryColor: Color.emeraldAccent,
                backgroundColor: Color.emeraldAccent.opacity(0.15)
            )
        case 5:
            return Server2RankInfo(
                rank: 5,
                badgeText: "⭐ Hạng 5",
                isTie: false,
                isWinner: false,
                primaryColor: Color.cyan,
                backgroundColor: Color.cyan.opacity(0.15)
            )
        case 6:
            return Server2RankInfo(
                rank: 6,
                badgeText: "⚡ Hạng 6",
                isTie: false,
                isWinner: false,
                primaryColor: Color.purple,
                backgroundColor: Color.purple.opacity(0.15)
            )
        case 7:
            return Server2RankInfo(
                rank: 7,
                badgeText: "🎯 Hạng 7",
                isTie: false,
                isWinner: false,
                primaryColor: Color.blue,
                backgroundColor: Color.blue.opacity(0.15)
            )
        case 8:
            return Server2RankInfo(
                rank: 8,
                badgeText: "🔥 Hạng 8",
                isTie: false,
                isWinner: false,
                primaryColor: Color.pink,
                backgroundColor: Color.pink.opacity(0.15)
            )
        case 9:
            return Server2RankInfo(
                rank: 9,
                badgeText: "🔹 Hạng 9",
                isTie: false,
                isWinner: false,
                primaryColor: Color.orange,
                backgroundColor: Color.orange.opacity(0.15)
            )
        default:
            return Server2RankInfo(
                rank: rank,
                badgeText: "🔘 Hạng \(rank)",
                isTie: false,
                isWinner: false,
                primaryColor: Color.gray,
                backgroundColor: Color.gray.opacity(0.15)
            )
        }
    }
}

extension Color {
    static let emeraldAccent = Color(red: 0.06, green: 0.76, blue: 0.49)
}
