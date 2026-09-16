import Foundation

public enum GameCategory: String, CaseIterable, Identifiable, Codable {
    case phom = "Phỏm (Tá Lả)"
    case binh = "Binh (Mậu Binh)"
    case lieng = "Liêng (3 Cây / Cào Tố)"
    case xiDach = "Xì Dách (2 Lá / Xì Lát)"
    case poker = "Poker (Texas Hold'em)"
    
    public var id: String { rawValue }
}

public enum GameType: String, CaseIterable, Identifiable, Codable {
    // Phỏm
    case phom9 = "Phỏm (Tá Lả 9 lá)"
    
    // Binh variants
    case binh13 = "Binh 13 lá (Mậu Binh / Chợ Lớn)"
    case binh9 = "Binh 9 lá (3 chi x 3 lá)"
    case binh6Poker = "Binh 6 lá (Bộ Poker 6 lá)"
    case binh6Split = "Binh 6 lá (Xếp 2 chi 3-3)"
    
    // Lieng
    case lieng3 = "Liêng (3 Cây chuẩn)"
    
    // Xi Dach
    case xiDach2 = "Xì Dách (2 Lá chuẩn)"
    
    // Poker
    case texasHoldem = "Poker (Texas Hold'em 2+5)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .phom9: return "Phỏm 9 lá"
        case .binh13: return "Binh 13 lá"
        case .binh9: return "Binh 9 lá"
        case .binh6Poker: return "Binh 6 lá"
        case .binh6Split: return "Binh 6 lá (2 chi)"
        case .lieng3: return "Liêng (3 Cây)"
        case .xiDach2: return "Xì Dách (2 Lá)"
        case .texasHoldem: return "Texas Hold'em"
        }
    }
    
    public var category: GameCategory {
        switch self {
        case .phom9:
            return .phom
        case .binh13, .binh9, .binh6Poker, .binh6Split:
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
        case .phom9: return 9
        case .binh13: return 13
        case .binh9: return 9
        case .binh6Poker, .binh6Split: return 6
        case .lieng3: return 3
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
        case .phom9: return 4
        case .binh13: return 4
        case .binh9: return 5
        case .binh6Poker, .binh6Split: return 8
        case .lieng3: return 10
        case .xiDach2: return 10
        case .texasHoldem: return 10
        }
    }
    
    public var descriptionVN: String {
        switch self {
        case .phom9:
            return "9 lá/người (2-4 người). Ghép các phỏm dọc (sảnh cùng chất) hoặc phỏm ngang (3-4 lá cùng số). Ai Ù (0 lá rác) thắng tuyệt đối. Tính điểm các lá rác còn lại (A=1, J=11, Q=12, K=13), ít điểm nhất thắng; không có phỏm bị Móm (Cháy)."
        case .binh13:
            return "13 lá/người, xếp 3 chi (3-5-5), luật Chi cuối ≥ Chi giữa ≥ Chi đầu (sai bị lủng), tính điểm từng chi + thưởng hàng, thắng trắng (Sảnh rồng, Lục phé bôn...)."
        case .binh9:
            return "9 lá/người, xếp 3 chi (3-3-3), luật Chi 1 ≥ Chi 2 ≥ Chi 3 (Sám cô > Sảnh > Đôi > Mậu thầu), thưởng 3 sảnh, 3 sám."
        case .binh6Poker:
            return "6 lá/người, so bài trực tiếp trọn gói 6 lá theo thứ tự: Tứ quý > Thùng phá sảnh > Sảnh > Cù lũ > Sám > Đôi..."
        case .binh6Split:
            return "6 lá/người, chia thành 2 chi (mỗi chi 3 lá), Chi 1 ≥ Chi 2, so từng chi."
        case .lieng3:
            return "3 lá/người, phân cấp: Sáp (10.000 + độ mạnh) > Liêng (5.000 + độ mạnh) > Ba Tây (1.000) > Điểm mod 10. Bằng điểm nhau thì đồng hạng."
        case .xiDach2:
            return "2 lá/người: Xì Bàng (A-A: 5021) > Xì Dách (A + 10/J/Q/K: 4000) > Ngũ Linh (5 lá ≤ 21đ) > Đủ tuổi (16-21đ) > Non (<16đ) > Quắc (>21đ)."
        case .texasHoldem:
            return "2 lá bài riêng (hole cards) + 5 lá bài chung (board). Tạo kết hợp 5 lá mạnh nhất từ 7 lá. 10 cấp bậc từ Mậu thầu đến Sảnh rồng đồng chất, đầy đủ sảnh bánh xe A-2-3-4-5 và kicker 5 bậc."
        }
    }
}
