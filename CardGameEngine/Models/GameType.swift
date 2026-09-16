import Foundation

public enum GameCategory: String, CaseIterable, Identifiable, Codable {
    case binh = "Binh (Mậu Binh)"
    case lieng = "Liêng (3 Cây / Cào Tố)"
    case poker = "Xì Tố (Poker)"
    
    public var id: String { rawValue }
}

public enum GameType: String, CaseIterable, Identifiable, Codable {
    // Binh variants
    case binh13 = "Binh 13 lá (Mậu Binh / Chợ Lớn)"
    case binh9 = "Binh 9 lá (3 chi x 3 lá)"
    case binh6Poker = "Binh 6 lá (Bộ Poker 6 lá)"
    case binh6Split = "Binh 6 lá (Xếp 2 chi 3-3)"
    
    // Lieng
    case lieng3 = "Liêng (3 Cây chuẩn)"
    
    // Poker variants
    case texasHoldem = "Texas Hold'em (2 tẩy + 5 chung)"
    case omaha = "Omaha Poker (4 tẩy + 5 chung)"
    case sevenCardStud = "Xì Tố 7 lá (Seven Card Stud)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .binh13: return "Binh 13 lá"
        case .binh9: return "Binh 9 lá"
        case .binh6Poker: return "Binh 6 lá"
        case .binh6Split: return "Binh 6 lá (2 chi)"
        case .lieng3: return "Liêng (3 Cây)"
        case .texasHoldem: return "Texas Hold'em"
        case .omaha: return "Omaha Poker"
        case .sevenCardStud: return "Xì Tố 7 lá"
        }
    }
    
    public var category: GameCategory {
        switch self {
        case .binh13, .binh9, .binh6Poker, .binh6Split:
            return .binh
        case .lieng3:
            return .lieng
        case .texasHoldem, .omaha, .sevenCardStud:
            return .poker
        }
    }
    
    // Cards required per player
    public var cardsPerPlayer: Int {
        switch self {
        case .binh13: return 13
        case .binh9: return 9
        case .binh6Poker, .binh6Split: return 6
        case .lieng3: return 3
        case .texasHoldem: return 2
        case .omaha: return 4
        case .sevenCardStud: return 7
        }
    }
    
    // Community cards required (e.g. Flop, Turn, River)
    public var communityCardsCount: Int {
        switch self {
        case .texasHoldem, .omaha: return 5
        default: return 0
        }
    }
    
    public var minPlayers: Int { 2 }
    
    public var maxPlayers: Int {
        switch self {
        case .binh13: return 4
        case .binh9: return 5
        case .binh6Poker, .binh6Split: return 8
        case .lieng3: return 10
        case .texasHoldem: return 10
        case .omaha: return 10
        case .sevenCardStud: return 7
        }
    }
    
    public var descriptionVN: String {
        switch self {
        case .binh13:
            return "13 lá/người, xếp 3 chi (3-5-5), luật Chi cuối ≥ Chi giữa ≥ Chi đầu (sai bị lủng), tính điểm từng chi + thưởng hàng, thắng trắng (Sảnh rồng, Lục phé bôn...)."
        case .binh9:
            return "9 lá/người, xếp 3 chi (3-3-3), luật Chi 1 ≥ Chi 2 ≥ Chi 3 (Sám cô > Sảnh > Đôi > Mậu thầu), thưởng 3 sảnh, 3 sám."
        case .binh6Poker:
            return "6 lá/người, so bài trực tiếp trọn gói 6 lá theo thứ tự: Tứ quý > Thùng phá sảnh > Sảnh > Cù lũ > Sám > Đôi..."
        case .binh6Split:
            return "6 lá/người, chia thành 2 chi (mỗi chi 3 lá), Chi 1 ≥ Chi 2, so từng chi."
        case .lieng3:
            return "3 lá/người, phân cấp: Sáp > Liêng (Sảnh) > Đĩ (Ba Tây J-Q-K) > Điểm Mậu thầu mod 10, so lá to nhất và chất theo cài đặt."
        case .texasHoldem:
            return "2 lá tẩy + 5 lá bài chung, chọn 5 lá tốt nhất từ 7 lá. Đầy đủ sảnh bánh xe A-2-3-4-5 và kicker 5 bậc."
        case .omaha:
            return "4 lá tẩy + 5 lá bài chung, BẮT BUỘC dùng đúng 2 lá tẩy + 3 lá chung để tạo bộ 5 lá mạnh nhất."
        case .sevenCardStud:
            return "7 lá bài riêng mỗi người, chọn bộ 5 lá mạnh nhất trong 7 lá để so tài."
        }
    }
}
