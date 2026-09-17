import Foundation

public enum GameCategory: String, CaseIterable, Identifiable, Codable {
    case binh = "Binh (Mậu Binh)"
    case lieng = "Liêng (3 Cây / Cào Tố)"
    case xiDach = "Xì Dách (2 Lá / Xì Lát)"
    case poker = "Poker (Texas Hold'em)"
    
    public var id: String { rawValue }
}

public enum GameType: String, CaseIterable, Identifiable, Codable {
    // Lieng
    case lieng3 = "Liêng (3 Cây chuẩn)"
    
    // Binh variants
    case binh9 = "Binh 9 lá (3 chi x 3 lá)"
    case binh6Poker = "Binh 6 lá"
    
    // Xi Dach
    case xiDach2 = "Xì Dách (2 Lá chuẩn)"
    
    // Poker
    case texasHoldem = "Poker (Texas Hold'em 2+5)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .lieng3: return "Liêng (3 Cây)"
        case .binh9: return "Binh 9 lá"
        case .binh6Poker: return "Binh 6 lá"
        case .xiDach2: return "Xì Dách (2 Lá)"
        case .texasHoldem: return "Texas Hold'em"
        }
    }
    
    public var category: GameCategory {
        switch self {
        case .binh9, .binh6Poker:
            return .binh
        case .lieng3:
            return .lieng
        case .xiDach2:
            return .xiDach
        case .texasHoldem:
            return .poker
        }
    }
    
    // Cards required per player
    public var cardsPerPlayer: Int {
        switch self {
        case .lieng3: return 3
        case .binh9: return 9
        case .binh6Poker: return 6
        case .xiDach2: return 2
        case .texasHoldem: return 2
        }
    }
    
    // Community cards required (e.g. Flop, Turn, River)
    public var communityCardsCount: Int {
        switch self {
        case .texasHoldem: return 5
        default: return 0
        }
    }
    
    public var minPlayers: Int { 2 }
    
    public var maxPlayers: Int {
        switch self {
        case .binh9: return 5
        case .binh6Poker: return 8
        case .lieng3: return 10
        case .xiDach2: return 10
        case .texasHoldem: return 10
        }
    }
    
    public var descriptionVN: String {
        switch self {
        case .lieng3:
            return "3 lá/người, phân cấp: Sáp (10.000 + độ mạnh) > Liêng (5.000 + độ mạnh) > Ba Tây (1.000) > Điểm mod 10. Bằng điểm nhau thì đồng hạng."
        case .binh9:
            return "9 lá/người, xếp 3 chi (3-3-3), luật Chi 1 ≥ Chi 2 ≥ Chi 3 (Sáp > Liêng > Ba Tây > Điểm Đôi > Điểm Thường)."
        case .binh6Poker:
            return "6 lá/người, so bài trực tiếp theo thang Poker 5 lá mạnh nhất từ 6 lá: Thùng phá sảnh > Tứ quý > Cù lũ > Thùng > Sảnh > Sám..."
        case .xiDach2:
            return "2 lá/người: Xì Bàng (A-A: 5021) > Xì Dách (A + 10/J/Q/K: 4000) > Ngũ Linh (5 lá ≤ 21đ) > Đủ tuổi (16-21đ) > Non (<16đ) > Quắc (>21đ)."
        case .texasHoldem:
            return "2 lá bài riêng (hole cards) + 5 lá bài chung (board). Tạo kết hợp 5 lá mạnh nhất từ 7 lá. 10 cấp bậc từ Mậu thầu đến Sảnh rồng đồng chất, đầy đủ sảnh bánh xe A-2-3-4-5 và kicker 5 bậc."
        }
    }
}
