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
        "sì": .ace, "si": .ace, "mốt": .ace, "mot": .ace, "a": .ace, "ace": .ace,
        "à": .ace, "á": .ace, "ây": .ace, "ay": .ace, "dách": .ace, "dach": .ace, "một": .ace, "1": .ace,
        
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
        "11": .jack, "bồi": .jack, "boi": .jack, "ri": .jack, "gi": .jack, "di": .jack,
        "gì": .jack, "ghi": .jack, "dê": .jack, "de": .jack, "j": .jack, "jack": .jack,
        
        // Q
        "12": .queen, "đầm": .queen, "dam": .queen, "quy": .queen, "q": .queen, "qui": .queen,
        "quê": .queen, "que": .queen, "nữ": .queen, "nu": .queen, "queen": .queen,
        
        // K
        "13": .king, "già": .king, "gia": .king, "ka": .king, "k": .king, "ca": .king, "cả": .king, "cá": .king, "cà": .king,
        "kay": .king, "cay": .king, "vua": .king, "king": .king
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
        "con", "lá", "la", "quân", "quan", "cây",
        "nhà", "nha", "tụ", "tu",
        "với", "voi", "và", "va",
        "nhập", "nhap", "thêm", "them", "lấy", "lay",
        "nữa", "nua", "nhé", "nhe", "rồi", "roi"
    ]
    
    /// Tách các chuỗi số dính nhau thành các số bài riêng biệt có khoảng cách
    /// Bảo tồn 10, 11 (J), 12 (Q), 13 (K); các số khác hoặc chuỗi dài được tách thông minh
    /// Ví dụ: "123456789 10 11 23" -> "1 2 3 4 5 6 7 8 9 10 11 2 3"
    public static func separateDigits(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        
        var result = ""
        var currentDigits = ""
        
        func flushDigits() {
            guard !currentDigits.isEmpty else { return }
            if currentDigits == "10" || currentDigits == "11" || currentDigits == "12" || currentDigits == "13" {
                result.append(currentDigits)
            } else if currentDigits.count == 2 {
                let first = currentDigits.prefix(1)
                let second = currentDigits.suffix(1)
                result.append("\(first) \(second)")
            } else {
                var res: [String] = []
                var i = currentDigits.startIndex
                while i < currentDigits.endIndex {
                    if currentDigits[i] == "1" {
                        let nextIndex = currentDigits.index(after: i)
                        if nextIndex < currentDigits.endIndex && currentDigits[nextIndex] == "0" {
                            res.append("10")
                            i = currentDigits.index(after: nextIndex)
                            continue
                        }
                    }
                    res.append(String(currentDigits[i]))
                    i = currentDigits.index(after: i)
                }
                result.append(res.joined(separator: " "))
            }
            currentDigits = ""
        }
        
        for ch in text {
            if ch.isNumber {
                currentDigits.append(ch)
            } else {
                flushDigits()
                result.append(ch)
            }
        }
        flushDigits()
        
        return result
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Phân tích một chuỗi giọng nói tiếng Việt thành danh sách quân bài
    public static func parse(_ text: String) -> [ParsedVoiceCard] {
        let unglued = separateDigits(text)
        let separators = CharacterSet(charactersIn: ",.:;?!/\\-—_~|\n\r\t\"'")
        let cleaned = unglued.lowercased()
            .components(separatedBy: separators)
            .joined(separator: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else { return [] }
        
        // Handle multi-word quantity phrases and card phrases
        var normalized = cleaned
            .replacingOccurrences(of: "tứ quý", with: "tu_quy")
            .replacingOccurrences(of: "tu quy", with: "tu_quy")
            .replacingOccurrences(of: "hai con", with: "đôi")
            .replacingOccurrences(of: "hai lá", with: "đôi")
            .replacingOccurrences(of: "ba con", with: "sám")
            .replacingOccurrences(of: "ba lá", with: "sám")
            .replacingOccurrences(of: "bốn con", with: "tu_quy")
            .replacingOccurrences(of: "bốn lá", with: "tu_quy")
            .replacingOccurrences(of: "hắt xì", with: "xì")
            .replacingOccurrences(of: "ách xì", with: "xì")
            .replacingOccurrences(of: "xì dách", with: "xì")
            .replacingOccurrences(of: "sì dách", with: "xì")
            .replacingOccurrences(of: "mười một", with: "11")
            .replacingOccurrences(of: "muoi mot", with: "11")
            .replacingOccurrences(of: "mười hai", with: "12")
            .replacingOccurrences(of: "muoi hai", with: "12")
            .replacingOccurrences(of: "mười ba", with: "13")
            .replacingOccurrences(of: "muoi ba", with: "13")

        
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
