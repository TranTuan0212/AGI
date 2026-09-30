import Foundation

public struct ParsedVoiceCard: Equatable {
    public let rank: Rank
    public let suit: Suit?
    
    public init(rank: Rank, suit: Suit? = nil) {
        self.rank = rank
        self.suit = suit
    }
}

public struct VietnameseCardVoiceParser {
    
    // Normalized synonym mapping for ranks
    private static let rankMap: [String: Rank] = [
        // Ace
        "át": .ace, "at": .ace, "ách": .ace, "ach": .ace, "xì": .ace, "xi": .ace,
        "mốt": .ace, "mot": .ace, "a": .ace, "ace": .ace, "một": .ace, "mot": .ace,
        
        // 2
        "hai": .two, "nhị": .two, "nhi": .two, "2": .two,
        
        // 3
        "ba": .three, "tam": .three, "3": .three,
        
        // 4
        "bốn": .four, "bon": .four, "tư": .four, "tu": .four, "4": .four,
        
        // 5
        "năm": .five, "nam": .five, "ngũ": .five, "ngu": .five, "5": .five,
        
        // 6
        "sáu": .six, "sau": .six, "lục": .six, "luc": .six, "6": .six,
        
        // 7
        "bảy": .seven, "bay": .seven, "bẩy": .seven, "bey": .seven, "thất": .seven, "that": .seven, "7": .seven,
        
        // 8
        "tám": .eight, "tam8": .eight, "bát": .eight, "bat": .eight, "8": .eight,
        
        // 9
        "chín": .nine, "chin": .nine, "cửu": .nine, "cuu": .nine, "9": .nine,
        
        // 10
        "mười": .ten, "muoi": .ten, "chục": .ten, "chuc": .ten, "10": .ten,
        
        // J
        "bồi": .jack, "boi": .jack, "ri": .jack, "gi": .jack, "di": .jack,
        "ghi": .jack, "j": .jack, "jack": .jack,
        
        // Q
        "đầm": .queen, "dam": .queen, "quy": .queen, "q": .queen, "qui": .queen,
        "nữ": .queen, "nu": .queen, "queen": .queen,
        
        // K
        "già": .king, "gia": .king, "ka": .king, "k": .king, "vua": .king, "king": .king
    ]
    
    // Normalized synonym mapping for suits
    private static let suitMap: [String: Suit] = [
        "cơ": .hearts, "co": .hearts, "tim": .hearts, "đỏ": .hearts, "do": .hearts, "heart": .hearts,
        "rô": .diamonds, "ro": .diamonds, "vuông": .diamonds, "vuong": .diamonds, "diamond": .diamonds,
        "tép": .clubs, "tep": .clubs, "chuồn": .clubs, "chuon": .clubs, "nhép": .clubs, "nhep": .clubs, "chùy": .clubs, "club": .clubs,
        "bích": .spades, "bich": .spades, "đen": .spades, "den": .spades, "spade": .spades
    ]
    
    // Quantity prefixes
    private static let quantityMap: [String: Int] = [
        "đôi": 2, "doi": 2,
        "sám": 3, "sam": 3, "xám": 3, "xam": 3,
        "tứ quý": 4, "tu quy": 4, "tứ": 4, "tu": 4
    ]
    
    // Filler words to ignore safely
    private static let fillerWords: Set<String> = [
        "cho", "tôi", "toi", "tao", "mình", "minh",
        "con", "lá", "la", "quân", "quan", "cây", "cay",
        "nhà", "nha", "tụ", "tu",
        "với", "voi", "và", "va",
        "nhập", "nhap", "thêm", "them", "lấy", "lay",
        "nữa", "nua", "nhé", "nhe", "rồi", "roi"
    ]
    
    /// Phân tích một chuỗi giọng nói tiếng Việt thành danh sách quân bài
    public static func parse(_ text: String) -> [ParsedVoiceCard] {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: "[,.:;?!/\\-—_]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else { return [] }
        
        // Handle multi-word quantity phrases like "tứ quý", "ba con", "bốn con"
        var normalized = cleaned
            .replacingOccurrences(of: "tứ quý", with: "tu_quy")
            .replacingOccurrences(of: "tu quy", with: "tu_quy")
            .replacingOccurrences(of: "hai con", with: "đôi")
            .replacingOccurrences(of: "hai lá", with: "đôi")
            .replacingOccurrences(of: "ba con", with: "sám")
            .replacingOccurrences(of: "ba lá", with: "sám")
            .replacingOccurrences(of: "bốn con", with: "tu_quy")
            .replacingOccurrences(of: "bốn lá", with: "tu_quy")
        
        let tokens = normalized.split(separator: " ").map { String($0) }
        var result: [ParsedVoiceCard] = []
        var i = 0
        var multiplier = 1
        
        while i < tokens.count {
            let token = tokens[i]
            
            // Check quantity
            if token == "tu_quy" {
                multiplier = 4
                i += 1
                continue
            } else if token == "đôi" || token == "doi" {
                multiplier = 2
                i += 1
                continue
            } else if token == "sám" || token == "sam" || token == "xám" || token == "xam" {
                multiplier = 3
                i += 1
                continue
            }
            
            // Skip filler words
            if fillerWords.contains(token) {
                i += 1
                continue
            }
            
            // Check if token matches a rank
            if let rank = rankMap[token] {
                var detectedSuit: Suit? = nil
                
                // Lookahead for suit
                if i + 1 < tokens.count {
                    let nextToken = tokens[i + 1]
                    if let suit = suitMap[nextToken] {
                        detectedSuit = suit
                        i += 1 // consume suit token
                    }
                }
                
                let countToAppend = multiplier
                multiplier = 1 // reset multiplier
                
                for _ in 0..<countToAppend {
                    result.append(ParsedVoiceCard(rank: rank, suit: detectedSuit))
                }
            }
            
            i += 1
        }
        
        return result
    }
}
