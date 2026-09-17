/**
 * Trợ Lý Bàn Bài Tây 52 Lá (Binh - Liêng - Xì Tố)
 * JavaScript Engine & UI Controller
 */

// MARK: - Constants & Config
const SUITS = [
  { id: 'hearts', symbol: '♥', nameVN: 'Cơ', isRed: true },
  { id: 'diamonds', symbol: '♦', nameVN: 'Rô', isRed: true },
  { id: 'clubs', symbol: '♣', nameVN: 'Chuồn (Tép)', isRed: false },
  { id: 'spades', symbol: '♠', nameVN: 'Bích', isRed: false }
];

const RANKS = [
  { raw: 2, sym: '2', lieng: 2 },
  { raw: 3, sym: '3', lieng: 3 },
  { raw: 4, sym: '4', lieng: 4 },
  { raw: 5, sym: '5', lieng: 5 },
  { raw: 6, sym: '6', lieng: 6 },
  { raw: 7, sym: '7', lieng: 7 },
  { raw: 8, sym: '8', lieng: 8 },
  { raw: 9, sym: '9', lieng: 9 },
  { raw: 10, sym: '10', lieng: 0 },
  { raw: 11, sym: 'J', lieng: 0 },
  { raw: 12, sym: 'Q', lieng: 0 },
  { raw: 13, sym: 'K', lieng: 0 },
  { raw: 14, sym: 'A', lieng: 1 }
];

const GAME_CONFIGS = {
  binh9: {
    name: "Binh 9 lá (3 chi x 3 lá)",
    cardsPerPlayer: 9,
    community: 0,
    minPlayers: 2,
    maxPlayers: 5,
    desc: "9 lá/người, xếp 3 chi (3-3-3), luật Chi 1 ≥ Chi 2 ≥ Chi 3 (Sám cô > Sảnh > Đôi > Mậu thầu), thưởng 3 sảnh, 3 sám, sập hầm x2."
  },
  binh6Poker: {
    name: "Binh 6 lá (Thang Poker 6 lá)",
    cardsPerPlayer: 6,
    community: 0,
    minPlayers: 2,
    maxPlayers: 8,
    desc: "6 lá/người, so trọn gói theo thang Poker: Tứ quý > Thùng phá sảnh > Sảnh > Cù lũ > Sám cô > Đôi..."
  },
  binh6Split: {
    name: "Binh 6 lá (Xếp 2 chi 3-3)",
    cardsPerPlayer: 6,
    community: 0,
    minPlayers: 2,
    maxPlayers: 8,
    desc: "6 lá/người, chia thành 2 chi (mỗi chi 3 lá), Chi 1 ≥ Chi 2, so từng chi."
  },
  lieng3: {
    name: "Liêng (3 Cây / Cào Tố)",
    cardsPerPlayer: 3,
    community: 0,
    minPlayers: 2,
    maxPlayers: 10,
    desc: "3 lá/người, phân cấp: Sáp (10.000 + rank) > Liêng (5.000 + rank) > Ba Tây (1.000) > Điểm mod 10. Bằng điểm nhau thì đồng hạng."
  },
  xiDach2: {
    name: "Xì Dách (2 Lá / Xì Lát)",
    cardsPerPlayer: 2,
    community: 0,
    minPlayers: 2,
    maxPlayers: 10,
    desc: "2 lá/người: Xì Bàng (A-A: 5021) > Xì Dách (A + 10/J/Q/K: 4000) > Ngũ Linh (5 lá ≤ 21đ) > Đủ tuổi (16-21đ) > Non (<16đ) > Quắc (>21đ)."
  },
  texasHoldem: {
    name: "Poker (Texas Hold'em 2+5)",
    cardsPerPlayer: 2,
    community: 5,
    minPlayers: 2,
    maxPlayers: 10,
    desc: "2 lá tẩy + 5 lá bài chung, chọn 5 lá tốt nhất từ 7 lá. 10 cấp bậc từ Mậu thầu đến Sảnh rồng đồng chất, đầy đủ sảnh bánh xe A-2-3-4-5 và kicker 5 bậc."
  }
};

// Suit ranking calculation
function getSuitValue(suitId, preset) {
  if (preset === 'international') return 0;
  if (preset === 'southA') {
    // Bích > Rô > Cơ > Tép
    switch(suitId) {
      case 'clubs': return 1;
      case 'hearts': return 2;
      case 'diamonds': return 3;
      case 'spades': return 4;
    }
  }
  // Default North / SouthB: Cơ > Rô > Chuồn > Bích
  switch(suitId) {
    case 'spades': return 1;
    case 'clubs': return 2;
    case 'diamonds': return 3;
    case 'hearts': return 4;
  }
}

// Combinations helper n choose k
function getCombinations(arr, k) {
  if (k === 0) return [[]];
  if (arr.length === 0) return [];
  const head = arr[0];
  const tail = arr.slice(1);
  const withHead = getCombinations(tail, k - 1).map(c => [head, ...c]);
  const withoutHead = getCombinations(tail, k);
  return [...withHead, ...withoutHead];
}

// MARK: - Hand Evaluators

class PokerEvaluator {
  static evaluate5(cards) {
    if (!cards || cards.length !== 5) {
      return { type: 1, typeName: "Mậu thầu", tieBreakers: [0], desc: "Lỗi thiếu lá", cards: [] };
    }
    const sorted = [...cards].sort((a, b) => b.rank - a.rank);
    const ranks = sorted.map(c => c.rank);
    const suits = sorted.map(c => c.suit);
    const isFlush = suits.every(s => s === suits[0]);

    // Straight checking (including wheel A-2-3-4-5)
    let isStraight = false;
    let straightHigh = 0;
    if (ranks[0] - ranks[1] === 1 && ranks[1] - ranks[2] === 1 && ranks[2] - ranks[3] === 1 && ranks[3] - ranks[4] === 1) {
      isStraight = true;
      straightHigh = ranks[0];
    } else if (ranks[0] === 14 && ranks[1] === 5 && ranks[2] === 4 && ranks[3] === 3 && ranks[4] === 2) {
      isStraight = true;
      straightHigh = 5; // Wheel straight, 5 is high
    }

    // Rank frequencies
    const counts = {};
    ranks.forEach(r => { counts[r] = (counts[r] || 0) + 1; });
    const grouped = Object.entries(counts).map(([r, c]) => ({ rank: Number(r), count: c }))
      .sort((a, b) => b.count - a.count || b.rank - a.rank);

    const sym = r => RANKS.find(x => x.raw === r)?.sym || r;

    // 10. Royal Flush & 9. Straight Flush
    if (isFlush && isStraight) {
      if (straightHigh === 14) {
        return { type: 10, typeName: "Thùng phá sảnh lớn", tieBreakers: [14], desc: "Thùng phá sảnh lớn (Royal Flush)", cards: sorted };
      }
      return { type: 9, typeName: "Thùng phá sảnh", tieBreakers: [straightHigh], desc: `Thùng phá sảnh đỉnh ${sym(straightHigh)}`, cards: sorted };
    }

    // 8. Four of a kind
    if (grouped[0].count === 4) {
      return {
        type: 8, typeName: "Tứ quý",
        tieBreakers: [grouped[0].rank, grouped[1].rank],
        desc: `Tứ quý ${sym(grouped[0].rank)} (Kicker ${sym(grouped[1].rank)})`,
        cards: sorted
      };
    }

    // 7. Full House
    if (grouped[0].count === 3 && grouped[1].count === 2) {
      return {
        type: 7, typeName: "Cù lũ",
        tieBreakers: [grouped[0].rank, grouped[1].rank],
        desc: `Cù lũ ${sym(grouped[0].rank)} bu ${sym(grouped[1].rank)}`,
        cards: sorted
      };
    }

    // 6. Flush
    if (isFlush) {
      const suitObj = SUITS.find(s => s.id === suits[0]);
      return {
        type: 6, typeName: "Thùng",
        tieBreakers: ranks,
        desc: `Thùng chất ${suitObj?.nameVN || ''} (Đỉnh ${sym(ranks[0])})`,
        cards: sorted
      };
    }

    // 5. Straight
    if (isStraight) {
      return {
        type: 5, typeName: "Sảnh",
        tieBreakers: [straightHigh],
        desc: straightHigh === 5 ? "Sảnh bánh xe (A-2-3-4-5)" : `Sảnh đỉnh ${sym(straightHigh)}`,
        cards: sorted
      };
    }

    // 4. Three of a kind
    if (grouped[0].count === 3) {
      return {
        type: 4, typeName: "Sám cô",
        tieBreakers: [grouped[0].rank, grouped[1].rank, grouped[2].rank],
        desc: `Sám cô ${sym(grouped[0].rank)} (Kickers ${sym(grouped[1].rank)}, ${sym(grouped[2].rank)})`,
        cards: sorted
      };
    }

    // 3. Two pair
    if (grouped[0].count === 2 && grouped[1].count === 2) {
      const highP = Math.max(grouped[0].rank, grouped[1].rank);
      const lowP = Math.min(grouped[0].rank, grouped[1].rank);
      const kicker = grouped[2].rank;
      return {
        type: 3, typeName: "Hai đôi",
        tieBreakers: [highP, lowP, kicker],
        desc: `Hai đôi (${sym(highP)} & ${sym(lowP)}) - Kicker ${sym(kicker)}`,
        cards: sorted
      };
    }

    // 2. One pair
    if (grouped[0].count === 2) {
      const pair = grouped[0].rank;
      const kickers = [grouped[1].rank, grouped[2].rank, grouped[3].rank];
      return {
        type: 2, typeName: "Một đôi",
        tieBreakers: [pair, ...kickers],
        desc: `Một đôi ${sym(pair)} (Kickers: ${kickers.map(sym).join(', ')})`,
        cards: sorted
      };
    }

    // 1. High card
    return {
      type: 1, typeName: "Mậu thầu",
      tieBreakers: ranks,
      desc: `Mậu thầu đỉnh ${sym(ranks[0])}`,
      cards: sorted
    };
  }

  static compareScores(a, b) {
    if (a.type !== b.type) return a.type - b.type;
    for (let i = 0; i < Math.min(a.tieBreakers.length, b.tieBreakers.length); i++) {
      if (a.tieBreakers[i] !== b.tieBreakers[i]) {
        return a.tieBreakers[i] - b.tieBreakers[i];
      }
    }
    return 0;
  }

  static evaluateBestOfMany(cards) {
    if (cards.length < 5) return this.evaluate5(cards);
    const combos = getCombinations(cards, 5);
    let best = null;
    for (const c of combos) {
      const score = this.evaluate5(c);
      if (!best || this.compareScores(score, best) > 0) {
        best = score;
      }
    }
    return best;
  }
}

function getSuitValue(suitId, preset = 'north') {
  if (preset === 'international') return 0;
  if (preset === 'southA') {
    if (suitId === 'spades') return 4;
    if (suitId === 'diamonds') return 3;
    if (suitId === 'hearts') return 2;
    if (suitId === 'clubs') return 1;
  } else {
    if (suitId === 'hearts') return 4;
    if (suitId === 'diamonds') return 3;
    if (suitId === 'clubs') return 2;
    if (suitId === 'spades') return 1;
  }
  return 0;
}

class LiengEvaluator {
  static evaluate(cards, preset = 'north') {
    if (!cards || cards.length !== 3) {
      return { score: 0, typeName: "Điểm", desc: "Không đủ 3 lá" };
    }
    const sorted = [...cards].sort((a, b) => b.rank - a.rank);
    const ranks = sorted.map(c => c.rank);
    const topCard = sorted[0];
    const suitScore = (preset === 'international') ? 0 : getSuitValue(topCard.suit, preset);

    // 1. Sáp (3 same rank)
    if (ranks[0] === ranks[1] && ranks[1] === ranks[2]) {
      const sym = RANKS.find(r => r.raw === ranks[0])?.sym || ranks[0];
      const score = 1000000 + ranks[0] * 10 + suitScore;
      return {
        score,
        typeName: "Sáp",
        desc: `🔥 SÁP ${sym}`
      };
    }

    // 2. Liêng (3 consecutive)
    let isLieng = false;
    let liengRankWeight = 0;
    let liengSymbol = "";
    let liengTopCard = topCard;

    if (ranks[0] - ranks[1] === 1 && ranks[1] - ranks[2] === 1) {
      isLieng = true;
      liengRankWeight = ranks[0];
      liengSymbol = sorted.map(c => RANKS.find(r => r.raw === c.rank)?.sym).reverse().join('-');
      liengTopCard = sorted[0];
    } else if (ranks[0] === 14 && ranks[1] === 3 && ranks[2] === 2) {
      // A-2-3 -> tops at 3
      isLieng = true;
      liengRankWeight = 3;
      liengSymbol = "A-2-3";
      liengTopCard = sorted.find(c => c.rank === 3) || sorted[0];
    }

    if (isLieng) {
      if (preset === 'international') {
        const score = 500000 + liengRankWeight * 10;
        return {
          score,
          typeName: "Liêng",
          desc: `⚡ LIÊNG ${liengSymbol}`
        };
      } else {
        const lSuitScore = getSuitValue(liengTopCard.suit, preset);
        const score = 500000 + liengRankWeight * 10 + lSuitScore;
        const lTopSym = RANKS.find(r => r.raw === liengTopCard.rank)?.sym || liengTopCard.rank;
        const lTopIcon = SUITS.find(s => s.id === liengTopCard.suit)?.symbol || '';
        return {
          score,
          typeName: "Liêng",
          desc: `⚡ LIÊNG ${liengSymbol} (${lTopSym}${lTopIcon})`
        };
      }
    }

    // 3. Ba Tây (All 3 are J, Q, K)
    const isDi = cards.every(c => c.rank === 11 || c.rank === 12 || c.rank === 13);
    if (isDi) {
      const symbols = sorted.map(c => RANKS.find(r => r.raw === c.rank)?.sym).join('-');
      if (preset === 'international') {
        return {
          score: 100000,
          typeName: "Ba Tây",
          desc: `👑 BA TÂY (${symbols})`
        };
      } else {
        const score = 100000 + topCard.rank * 10 + suitScore;
        const topSym = RANKS.find(r => r.raw === topCard.rank)?.sym || topCard.rank;
        const topIcon = SUITS.find(s => s.id === topCard.suit)?.symbol || '';
        return {
          score,
          typeName: "Ba Tây",
          desc: `👑 BA TÂY (${symbols}) - Lá cao: ${topSym}${topIcon}`
        };
      }
    }

    // 4. Điểm thường (Điểm mod 10)
    const totalPts = cards.reduce((sum, c) => sum + (RANKS.find(r => r.raw === c.rank)?.lieng || 0), 0);
    const mod = totalPts % 10;
    const ptText = mod === 0 ? "0 Điểm (Bù/Tịt)" : `${mod} Điểm`;

    if (preset === 'international') {
      const score = mod * 1000;
      return {
        score,
        typeName: "Điểm Thường",
        desc: `⭐ ${ptText}`
      };
    } else {
      const score = mod * 1000 + topCard.rank * 10 + suitScore;
      const topSym = RANKS.find(r => r.raw === topCard.rank)?.sym || topCard.rank;
      const topIcon = SUITS.find(s => s.id === topCard.suit)?.symbol || '';
      return {
        score,
        typeName: "Điểm Thường",
        desc: `⭐ ${ptText} (${topSym}${topIcon})`
      };
    }
  }

  static compare(a, b) {
    return (a.score || 0) - (b.score || 0);
  }
}

class XiDachEvaluator {
  static cardBaseValue(card) {
    if (card.rank === 14) return 1;
    if (card.rank >= 10) return 10;
    return card.rank;
  }

  static bestTotal(cards) {
    const nonAces = cards.filter(c => c.rank !== 14);
    const aceCount = cards.filter(c => c.rank === 14).length;
    const baseSum = nonAces.reduce((sum, c) => sum + this.cardBaseValue(c), 0);

    if (aceCount === 0) return baseSum;

    let possibleTotals = new Set([baseSum]);
    for (let i = 0; i < aceCount; i++) {
      const nextTotals = new Set();
      for (const t of possibleTotals) {
        nextTotals.add(t + 1);
        nextTotals.add(t + 10);
        nextTotals.add(t + 11);
      }
      possibleTotals = nextTotals;
    }

    const validTotals = Array.from(possibleTotals).filter(t => t <= 21);
    if (validTotals.length > 0) {
      return Math.max(...validTotals);
    }
    return Math.min(...possibleTotals);
  }

  static evaluate(cards) {
    if (!cards || cards.length < 2) {
      return { score: 0, title: "Chưa đủ 2 lá", detail: "Cần ít nhất 2 lá" };
    }

    const count = cards.length;
    const aceCount = cards.filter(c => c.rank === 14).length;

    // Case A: Exactly 2 cards
    if (count === 2) {
      // 1. Xì Bàng (A-A) -> 5021
      if (aceCount === 2) {
        return { score: 5021, title: "👑 Xì Bàng (A-A)", detail: "Thắng tuyệt đối toàn bàn" };
      }

      // 2. Xì Dách (A + 10/J/Q/K) -> 4000
      const hasFaceOr10 = cards.some(c => c.rank >= 10 && c.rank <= 13);
      if (aceCount === 1 && hasFaceOr10) {
        return { score: 4000, title: "🔥 Xì Dách (21đ)", detail: "1 Át + 1 Quân Tây/10" };
      }
    }

    // Case B: 5 cards (Ngũ Linh)
    const total = this.bestTotal(cards);
    if (count === 5 && total <= 21) {
      const score = 3000 + (21 - total);
      return { score, title: `🌟 Ngũ Linh (${total}đ)`, detail: "5 lá đủ điểm (≤ 21đ)" };
    }

    // Case C: Standard totals
    if (total >= 16 && total <= 21) {
      return { score: 2000 + total, title: `${total} Điểm (Đủ tuổi)`, detail: "Đạt ngưỡng chuẩn 16-21đ" };
    } else if (total < 16) {
      return { score: 1000 + total, title: `⚠️ Non (${total}đ)`, detail: "Chưa đủ 16 điểm" };
    } else {
      return { score: Math.max(0, 35 - total), title: `❌ Quắc (${total}đ)`, detail: "Vượt ngưỡng 21 điểm" };
    }
  }

  static compare(a, b) {
    return (a.score || 0) - (b.score || 0);
  }
}

// MARK: - Binh 9 Lá Evaluator
class Binh9Evaluator {
  static evaluateChi(cards) {
    if (!cards || cards.length !== 3) {
      return { type: 1, points: 0, primaryRank: 0, kickers: [], cards: cards || [], desc: "Chưa đủ 3 lá" };
    }

    const sorted = [...cards].sort((a, b) => b.rank - a.rank);
    const ranks = sorted.map(c => c.rank);
    const sym = (r) => RANKS.find(x => x.raw === r)?.sym || r;

    // 1. Sáp (3 of a kind)
    if (ranks[0] === ranks[1] && ranks[1] === ranks[2]) {
      return {
        type: 5,
        points: 0,
        primaryRank: ranks[0],
        kickers: [],
        cards: sorted,
        desc: `Sáp ${sym(ranks[0])}`
      };
    }

    // 2. Liêng / Sảnh (3 lá liên tiếp)
    if (ranks[0] - ranks[1] === 1 && ranks[1] - ranks[2] === 1) {
      return {
        type: 4,
        points: 0,
        primaryRank: ranks[0],
        kickers: [],
        cards: sorted,
        desc: `Liêng đỉnh ${sym(ranks[0])}`
      };
    }
    if (ranks[0] === 14 && ranks[1] === 3 && ranks[2] === 2) {
      return {
        type: 4,
        points: 0,
        primaryRank: 3,
        kickers: [],
        cards: sorted,
        desc: "Liêng A-2-3"
      };
    }

    // 3. Ba Tây / Hình (3 lá đều là J, Q, K)
    const isAllFaces = ranks.every(r => r >= 11 && r <= 13);
    if (isAllFaces) {
      return {
        type: 3,
        points: 0,
        primaryRank: ranks[0],
        kickers: ranks.slice(1),
        cards: sorted,
        desc: "Ba Tây (Hình)"
      };
    }

    // 4. Tính Điểm (Mod 10): A = 1, 2-9 = raw, 10,J,Q,K = 0
    const cardPoint = (r) => {
      if (r === 14) return 1;
      if (r >= 10) return 0;
      return r;
    };
    const totalPts = (cardPoint(ranks[0]) + cardPoint(ranks[1]) + cardPoint(ranks[2])) % 10;

    // Kiểm tra Đôi
    if (ranks[0] === ranks[1]) {
      return {
        type: 2,
        points: totalPts,
        primaryRank: ranks[0],
        kickers: [ranks[2]],
        cards: sorted,
        desc: `${totalPts} Điểm Đôi (Đôi ${sym(ranks[0])})`
      };
    }
    if (ranks[1] === ranks[2]) {
      return {
        type: 2,
        points: totalPts,
        primaryRank: ranks[1],
        kickers: [ranks[0]],
        cards: sorted,
        desc: `${totalPts} Điểm Đôi (Đôi ${sym(ranks[1])})`
      };
    }

    // Điểm thường
    const ptDesc = totalPts === 0 ? "Bù (0 Điểm)" : `${totalPts} Điểm`;
    return {
      type: 1,
      points: totalPts,
      primaryRank: 0,
      kickers: ranks,
      cards: sorted,
      desc: ptDesc
    };
  }

  static compareChi(s1, s2) {
    const s1Special = s1.type >= 3;
    const s2Special = s2.type >= 3;

    if (s1Special || s2Special) {
      if (s1.type !== s2.type) return s1.type - s2.type;
      if (s1.primaryRank !== s2.primaryRank) return s1.primaryRank - s2.primaryRank;
      const len = Math.min(s1.kickers.length, s2.kickers.length);
      for (let i = 0; i < len; i++) {
        if (s1.kickers[i] !== s2.kickers[i]) return s1.kickers[i] - s2.kickers[i];
      }
      return 0;
    }

    // Cả hai đều thuộc tầng Điểm
    if (s1.points !== s2.points) return s1.points - s2.points;

    // Cùng điểm: Đôi ăn Thường (type 2 > type 1)
    if (s1.type !== s2.type) return s1.type - s2.type;

    // Cùng Điểm Đôi: so đôi
    if (s1.type === 2) {
      if (s1.primaryRank !== s2.primaryRank) return s1.primaryRank - s2.primaryRank;
      if (s1.kickers[0] !== s2.kickers[0]) return s1.kickers[0] - s2.kickers[0];
      return 0;
    }

    // Cùng Điểm Thường: so lá bài lớn nhất
    for (let i = 0; i < s1.kickers.length; i++) {
      if (s1.kickers[i] !== s2.kickers[i]) return s1.kickers[i] - s2.kickers[i];
    }
    return 0;
  }

  static autoArrange(cards) {
    if (!cards || cards.length !== 9) {
      const empty = this.evaluateChi([]);
      return { chi1: [], chi2: [], chi3: [], score1: empty, score2: empty, score3: empty, isLung: true, instantWin: null };
    }

    const indices = [0, 1, 2, 3, 4, 5, 6, 7, 8];
    const all3Indices = getCombinations(indices, 3);
    let bestArrangement = null;
    let bestWeight = -999999999999;

    const chiScalar = (s) => {
      if (s.type === 5) return 500000 + s.primaryRank * 100;
      if (s.type === 4) return 400000 + s.primaryRank * 100;
      if (s.type === 3) return 300000 + s.primaryRank * 100 + (s.kickers[0] || 0);
      if (s.type === 2) return 100000 + s.points * 10000 + s.primaryRank * 100 + (s.kickers[0] || 0);
      return s.points * 10000 + (s.kickers[0] || 0) * 100 + (s.kickers[1] || 0);
    };

    for (const c1Indices of all3Indices) {
      const c1Cards = c1Indices.map(i => cards[i]);
      const s1 = this.evaluateChi(c1Cards);

      const rem1 = indices.filter(i => !c1Indices.includes(i));
      const remCombos = getCombinations(rem1, 3);

      for (const c2Indices of remCombos) {
        const c2Cards = c2Indices.map(i => cards[i]);
        const s2 = this.evaluateChi(c2Cards);

        if (this.compareChi(s1, s2) < 0) continue; // Chi 1 >= Chi 2

        const c3Indices = rem1.filter(i => !c2Indices.includes(i));
        const c3Cards = c3Indices.map(i => cards[i]);
        const s3 = this.evaluateChi(c3Cards);

        if (this.compareChi(s2, s3) < 0) continue; // Chi 2 >= Chi 3

        let instant = null;
        if (s1.type === 5 && s2.type === 5 && s3.type === 5) {
          instant = "Thắng trắng: Ba Sáp";
        } else if (s1.type === 4 && s2.type === 4 && s3.type === 4) {
          instant = "Thắng trắng: Ba Liêng";
        }

        let weight = chiScalar(s1) * 10000 + chiScalar(s2) * 100 + chiScalar(s3);
        if (instant) weight += 50000000000;

        if (weight > bestWeight) {
          bestWeight = weight;
          bestArrangement = {
            chi1: c1Cards, chi2: c2Cards, chi3: c3Cards,
            score1: s1, score2: s2, score3: s3,
            isLung: false, instantWin: instant
          };
        }
      }
    }

    if (bestArrangement) return bestArrangement;

    // Fallback lung
    const sorted = [...cards].sort((a, b) => b.rank - a.rank);
    const c1 = sorted.slice(0, 3);
    const c2 = sorted.slice(3, 6);
    const c3 = sorted.slice(6, 9);
    return {
      chi1: c1, chi2: c2, chi3: c3,
      score1: this.evaluateChi(c1), score2: this.evaluateChi(c2), score3: this.evaluateChi(c3),
      isLung: true, instantWin: null
    };
  }

  static compareMatch(a, b) {
    if (a.instantWin && b.instantWin) return { scoreA: 0, detail: `Hòa Thắng Trắng: ${a.instantWin} vs ${b.instantWin}` };
    if (a.instantWin) return { scoreA: 6, detail: `${a.instantWin} (+6 chi)` };
    if (b.instantWin) return { scoreA: -6, detail: `Đối thủ ${b.instantWin} (-6 chi)` };

    if (a.isLung && b.isLung) return { scoreA: 0, detail: "Cả hai đều bị Lủng" };
    if (a.isLung) return { scoreA: -6, detail: "Bị Lủng (phạt -6 chi)" };
    if (b.isLung) return { scoreA: 6, detail: "Đối thủ bị Lủng (+6 chi)" };

    let c1 = 0;
    const cmp1 = this.compareChi(a.score1, b.score1);
    if (cmp1 > 0) c1 = 1; else if (cmp1 < 0) c1 = -1;

    let c2 = 0;
    const cmp2 = this.compareChi(a.score2, b.score2);
    if (cmp2 > 0) c2 = 1; else if (cmp2 < 0) c2 = -1;

    let c3 = 0;
    const cmp3 = this.compareChi(a.score3, b.score3);
    if (cmp3 > 0) c3 = 1; else if (cmp3 < 0) c3 = -1;

    let total = c1 + c2 + c3;
    let sapHamText = "";
    if (c1 > 0 && c2 > 0 && c3 > 0) {
      total = 6;
      sapHamText = " (Bắt sập hầm x2 = +6 chi)";
    } else if (c1 < 0 && c2 < 0 && c3 < 0) {
      total = -6;
      sapHamText = " (Bị sập hầm x2 = -6 chi)";
    }

    const detail = `Chi 1: ${c1 > 0 ? '+1' : c1}, Chi 2: ${c2 > 0 ? '+1' : c2}, Chi 3: ${c3 > 0 ? '+1' : c3}${sapHamText} ➔ Tổng: ${total > 0 ? '+' : ''}${total} chi`;
    return { scoreA: total, detail };
  }
}

// MARK: - State & App Controller

class AppController {

  constructor() {
    this.currentGameType = 'lieng3';
    this.suitPreset = 'north';
    this.playerCount = 3;
    this.inputMode = 'roundRobin'; // 'roundRobin' or 'manual'
    this.roundRobinPointer = 0;
    this.selectedPlayerIndex = 0;
    this.isSelectingCommunity = false;
    this.isRankOnlyMode = localStorage.getItem('card_game_rank_only_mode') === 'true';

    this.players = [];
    this.communityCards = [];
    this.actionHistory = [];
    this.history = [];
    try {
      this.history = JSON.parse(localStorage.getItem('card_game_history') || '[]');
    } catch (e) {
      this.history = [];
    }

    this.initPlayers();
    this.bindEvents();
    this.renderDeck();
    this.renderPlayers();
    this.updateUI();
  }

  isRankOnlyActive() {
    return this.isRankOnlyMode && (this.currentGameType === 'lieng3' || this.currentGameType === 'xiDach2');
  }

  targetCards(playerIndex) {
    return GAME_CONFIGS[this.currentGameType].cardsPerPlayer;
  }

  startNewRound() {
    this.clearResultsState();
    this.players.forEach(p => { p.cards = []; });
    this.communityCards = [];
    this.actionHistory = [];
    this.isSelectingCommunity = false;

    this.roundRobinPointer = 0;
    this.selectedPlayerIndex = 0;

    this.renderDeck();
    this.renderPlayers();
    this.updateUI();
  }

  initPlayers() {
    this.players = [];
    for (let i = 0; i < this.playerCount; i++) {
      this.players.push({
        id: `P${i}`,
        name: `Tụ ${i + 1}`,
        cards: [],
        score: 0,
        rankOrder: null,
        resultTitle: "",
        resultDetail: "",
        isLung: false
      });
    }
  }

  bindEvents() {
    document.getElementById('selectGameType').addEventListener('change', (e) => {
      this.currentGameType = e.target.value;
      this.resetTable();
      this.renderDeck();
      this.updateUI();
    });

    document.getElementById('btnIncreasePlayer').addEventListener('click', () => {
      const cfg = GAME_CONFIGS[this.currentGameType];
      if (this.playerCount < cfg.maxPlayers) {
        this.playerCount++;
        this.initPlayers();
        this.resetTable();
        this.updateUI();
      }
    });

    document.getElementById('btnDecreasePlayer').addEventListener('click', () => {
      const cfg = GAME_CONFIGS[this.currentGameType];
      if (this.playerCount > cfg.minPlayers) {
        this.playerCount--;
        this.initPlayers();
        this.resetTable();
        this.updateUI();
      }
    });

    document.getElementById('modeRoundRobin').addEventListener('click', () => {
      this.inputMode = 'roundRobin';
      document.getElementById('modeRoundRobin').classList.add('active');
      document.getElementById('modeManual').classList.remove('active');
      this.renderPlayers();
      this.updateUI();
    });

    document.getElementById('modeManual').addEventListener('click', () => {
      this.inputMode = 'manual';
      document.getElementById('modeManual').classList.add('active');
      document.getElementById('modeRoundRobin').classList.remove('active');
      this.renderPlayers();
      this.updateUI();
    });

    document.getElementById('btnUndo').addEventListener('click', () => this.undo());
    
    // Nút Lịch Sử
    const btnHist = document.getElementById('btnHistory');
    if (btnHist) {
      btnHist.addEventListener('click', () => this.openHistoryModal());
    }

    document.getElementById('btnReset').addEventListener('click', () => this.resetTable());
    document.getElementById('btnCalculate').addEventListener('click', () => {
      const hasResults = this.players.some(p => p.rankOrder != null);
      if (hasResults) {
        this.startNewRound();
      } else {
        this.onHiddenCardClick();
      }
    });

    // History Modal events
    const btnCloseHist = document.getElementById('btnCloseHistory');
    if (btnCloseHist) btnCloseHist.addEventListener('click', () => this.closeHistoryModal());
    const btnCloseHistBtm = document.getElementById('btnCloseHistoryBottom');
    if (btnCloseHistBtm) btnCloseHistBtm.addEventListener('click', () => this.closeHistoryModal());
    const btnClearHist = document.getElementById('btnClearHistory');
    if (btnClearHist) btnClearHist.addEventListener('click', () => this.clearHistory());

    // Settings Modals
    document.getElementById('btnOpenSettings').addEventListener('click', () => this.openSettings());
    document.getElementById('btnCloseSettings').addEventListener('click', () => this.closeSettings());
    document.getElementById('btnSaveSettings').addEventListener('click', () => this.saveSettings());

    document.getElementById('btnCloseModal').addEventListener('click', () => this.closeResultModal());
    document.getElementById('btnCloseModalBottom').addEventListener('click', () => this.closeResultModal());
  }

  renamePlayer(idx) {
    const p = this.players[idx];
    const newName = prompt(`Nhập tên mới cho ${p.name}:`, p.name);
    if (newName && newName.trim()) {
      p.name = newName.trim();
      this.renderPlayers();
      this.renderDeck();
      this.updateUI();
    }
  }

  getCardOwner(cardId) {
    for (const p of this.players) {
      if (p.cards.some(c => c.id === cardId)) {
        let clean = p.name.replace("Tụ ", "").replace("Nhóm ", "").trim();
        return clean.length <= 3 ? clean : clean.slice(0, 3).toUpperCase();
      }
    }
    if (this.communityCards.some(c => c.id === cardId)) {
      return "BC";
    }
    return null;
  }

  generateFullDeck() {

    const deck = [];
    SUITS.forEach(s => {
      RANKS.forEach(r => {
        deck.push({
          id: `${r.sym}${s.symbol}`,
          suit: s.id,
          suitIcon: s.symbol,
          suitName: s.nameVN,
          isRed: s.isRed,
          rank: r.raw,
          sym: r.sym
        });
      });
    });
    return deck;
  }

  renderDeck() {
    const grid = document.getElementById('deckGrid');
    if (!grid) return;
    grid.innerHTML = '';

    if (this.isRankOnlyActive()) {
      const rankGrid = document.createElement('div');
      rankGrid.className = 'deck-rank-grid';

      const row1 = ['A', '2', '3', '4', '5'];
      const row2 = ['6', '7', '8', '9', '10'];
      const row3 = ['J', 'Q', 'K'];

      [row1, row2, row3].forEach(rowSyms => {
        const row = document.createElement('div');
        row.className = 'deck-rank-row';

        rowSyms.forEach(sym => {
          const rObj = RANKS.find(r => r.sym === sym);
          const cell = document.createElement('div');
          let cls = 'rank-cell';
          if (sym === 'A') cls += ' ace-card';
          else if (['J', 'Q', 'K'].includes(sym)) cls += ' face-card';
          cell.className = cls;
          cell.textContent = sym;
          cell.addEventListener('click', () => this.onRankClick(rObj));
          row.appendChild(cell);
        });

        rankGrid.appendChild(row);
      });

      grid.appendChild(rankGrid);
      return;
    }

    const deck = this.generateFullDeck();

    SUITS.forEach(suit => {
      const row = document.createElement('div');
      row.className = 'deck-suit-row';

      const suitCards = deck.filter(c => c.suit === suit.id);
      suitCards.forEach(card => {
        const cell = document.createElement('div');
        cell.className = `card-cell ${card.isRed ? 'red' : 'black'}`;
        cell.dataset.cardId = card.id;

        const owner = this.getCardOwner(card.id);
        if (owner) {
          cell.classList.add('selected');
        }

        cell.innerHTML = `
          <span class="card-cell-rank">${card.sym}</span>
          <span class="card-cell-suit">${card.suitIcon}</span>
          ${owner ? `<span class="card-owner-badge">${owner}</span>` : ''}
        `;

        cell.addEventListener('click', () => this.onCardClick(card));
        row.appendChild(cell);
      });

      grid.appendChild(row);
    });
  }

  onRankClick(rankItem) {
    const cardId = `rank_${rankItem.sym}_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    const card = {
      id: cardId,
      rank: rankItem.raw,
      sym: rankItem.sym,
      suit: 'spades',
      suitIcon: '',
      suitName: '',
      isRed: rankItem.sym === 'A' || rankItem.sym === '10',
      isRankOnly: true
    };

    if (this.inputMode === 'roundRobin') {
      for (let i = 0; i < this.players.length; i++) {
        const pIdx = (this.roundRobinPointer + i) % this.players.length;
        const targetCards = this.targetCards(pIdx);
        if (this.players[pIdx].cards.length < targetCards) {
          this.players[pIdx].cards.push(card);
          this.actionHistory.push({ cardId: card.id, target: pIdx });
          this.roundRobinPointer = (pIdx + 1) % this.players.length;
          this.selectedPlayerIndex = this.roundRobinPointer;
          break;
        }
      }
    } else {
      const curP = this.players[this.selectedPlayerIndex];
      const targetCards = this.targetCards(this.selectedPlayerIndex);
      if (curP && curP.cards.length < targetCards) {
        curP.cards.push(card);
        this.actionHistory.push({ cardId: card.id, target: this.selectedPlayerIndex });
        if (curP.cards.length === targetCards) {
          let nextIdx = null;
          for (let i = 0; i < this.players.length; i++) {
            if (this.players[i].cards.length < this.targetCards(i)) {
              nextIdx = i;
              break;
            }
          }
          if (nextIdx !== null) this.selectedPlayerIndex = nextIdx;
        }
      }
    }

    this.renderPlayers();
    this.updateUI();

    if (this.isReady()) {
      this.calculate();
    }
  }

  onHiddenCardClick() {
    const cardId = `hidden_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    const card = {
      id: cardId,
      rank: 2,
      sym: '?',
      suit: '',
      suitIcon: 'Ẩn',
      suitName: 'Không rõ',
      isRed: false,
      isHidden: true
    };

    if (this.inputMode === 'roundRobin') {
      for (let i = 0; i < this.players.length; i++) {
        const pIdx = (this.roundRobinPointer + i) % this.players.length;
        const targetCards = this.targetCards(pIdx);
        if (this.players[pIdx].cards.length < targetCards) {
          this.players[pIdx].cards.push(card);
          this.actionHistory.push({ cardId: card.id, target: pIdx });
          this.roundRobinPointer = (pIdx + 1) % this.players.length;
          this.selectedPlayerIndex = this.roundRobinPointer;
          break;
        }
      }
    } else {
      const curP = this.players[this.selectedPlayerIndex];
      const targetCards = this.targetCards(this.selectedPlayerIndex);
      if (curP && curP.cards.length < targetCards) {
        curP.cards.push(card);
        this.actionHistory.push({ cardId: card.id, target: this.selectedPlayerIndex });
        if (curP.cards.length === targetCards) {
          let nextIdx = null;
          for (let i = 0; i < this.players.length; i++) {
            if (this.players[i].cards.length < this.targetCards(i)) {
              nextIdx = i;
              break;
            }
          }
          if (nextIdx !== null) this.selectedPlayerIndex = nextIdx;
        }
      }
    }

    this.renderPlayers();
    this.updateUI();

    if (this.isReady()) {
      this.calculate();
    }
  }

  onCardClick(card) {
    // If card already selected -> locked! (Users must tap the card on the mat to remove)
    if (this.getCardOwner(card.id)) {
      return;
    }

    const cfg = GAME_CONFIGS[this.currentGameType];
    const commTarget = cfg.community;

    if (this.inputMode === 'roundRobin') {
      // Find next player who still needs cards
      let found = false;
      for (let i = 0; i < this.players.length; i++) {
        const pIdx = (this.roundRobinPointer + i) % this.players.length;
        const targetCards = this.targetCards(pIdx);
        if (this.players[pIdx].cards.length < targetCards) {
          this.players[pIdx].cards.push(card);
          this.actionHistory.push({ cardId: card.id, target: pIdx });
          
          // Find next player who actually still needs cards!
          let nextNeedingIdx = null;
          for (let offset = 1; offset <= this.players.length; offset++) {
            const checkIdx = (pIdx + offset) % this.players.length;
            if (this.players[checkIdx].cards.length < this.targetCards(checkIdx)) {
              nextNeedingIdx = checkIdx;
              break;
            }
          }
          
          if (nextNeedingIdx !== null) {
            this.roundRobinPointer = nextNeedingIdx;
            this.isSelectingCommunity = false;
          } else if (commTarget > 0 && this.communityCards.length < commTarget) {
            this.isSelectingCommunity = true;
          }

          found = true;
          break;
        }
      }

      if (!found && this.communityCards.length < commTarget) {
        this.communityCards.push(card);
        this.actionHistory.push({ cardId: card.id, target: 'COMMUNITY' });
        if (this.communityCards.length < commTarget) {
          this.isSelectingCommunity = true;
        }
      }
    } else {
      // Manual selection
      if (this.isSelectingCommunity) {
        if (this.communityCards.length < commTarget) {
          this.communityCards.push(card);
          this.actionHistory.push({ cardId: card.id, target: 'COMMUNITY' });
        }
      } else {
        const curr = this.players[this.selectedPlayerIndex];
        const targetCards = this.targetCards(this.selectedPlayerIndex);
        if (curr && curr.cards.length < targetCards) {
          curr.cards.push(card);
          this.actionHistory.push({ cardId: card.id, target: this.selectedPlayerIndex });
          
          // Auto-advance to next player who still needs cards if current player is full
          if (curr.cards.length === targetCards) {
            let nextNeedingIdx = null;
            for (let offset = 1; offset < this.players.length; offset++) {
              const checkIdx = (this.selectedPlayerIndex + offset) % this.players.length;
              if (this.players[checkIdx].cards.length < this.targetCards(checkIdx)) {
                nextNeedingIdx = checkIdx;
                break;
              }
            }
            if (nextNeedingIdx !== null) {
              this.selectedPlayerIndex = nextNeedingIdx;
            } else if (commTarget > 0 && this.communityCards.length < commTarget) {
              this.isSelectingCommunity = true;
            }
          }

        } else if (commTarget > 0 && this.communityCards.length < commTarget) {
          this.communityCards.push(card);
          this.actionHistory.push({ cardId: card.id, target: 'COMMUNITY' });
          this.isSelectingCommunity = true;
        }
      }
    }

    this.renderDeck();
    this.renderPlayers();
    this.updateUI();

    // Auto calculate if all cards are dealt
    if (this.isReady()) {
      this.calculate();
    }
  }

  isReady() {
    const cfg = GAME_CONFIGS[this.currentGameType];
    const commFull = this.communityCards.length === cfg.community;
    const allFull = this.players.every((p, i) => p.cards.length >= this.targetCards(i));
    return allFull && commFull;
  }

  clearResultsState() {
    this.players.forEach(p => {
      p.rankOrder = null;
      p.score = 0;
      p.resultTitle = "";
      p.resultDetail = "";
      p.isLung = false;
    });
  }

  removeCard(cardId) {
    for (let i = 0; i < this.players.length; i++) {
      const p = this.players[i];
      const idx = p.cards.findIndex(c => c.id === cardId);
      if (idx !== -1) {
        p.cards.splice(idx, 1);
        this.actionHistory = this.actionHistory.filter(h => h.cardId !== cardId);
        
        // Reset focus back to this player so next tapped card goes to this exact player!
        this.selectedPlayerIndex = i;
        this.roundRobinPointer = i;
        this.isSelectingCommunity = false;
        break;
      }
    }
    const cIdx = this.communityCards.findIndex(c => c.id === cardId);
    if (cIdx !== -1) {
      this.communityCards.splice(cIdx, 1);
      this.actionHistory = this.actionHistory.filter(h => h.cardId !== cardId);
      this.isSelectingCommunity = true;
    }
    this.clearResultsState();
    this.renderDeck();
    this.renderPlayers();
    this.updateUI();
  }

  undo() {
    const last = this.actionHistory.pop();
    if (last) {
      this.removeCard(last.cardId);
    }
  }

  resetTable() {
    this.players.forEach(p => {
      p.cards = [];
      p.score = 0;
      p.rankOrder = null;
      p.resultTitle = "";
      p.resultDetail = "";
      p.isLung = false;
    });
    this.communityCards = [];
    this.actionHistory = [];
    this.roundRobinPointer = 0;
    this.selectedPlayerIndex = 0;
    this.isSelectingCommunity = false;
    this.renderDeck();
    this.renderPlayers();
    this.updateUI();
  }

  autoDeal() {
    this.resetTable();
    const deck = this.generateFullDeck();
    // Fisher-Yates Shuffle
    for (let i = deck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [deck[i], deck[j]] = [deck[j], deck[i]];
    }

    const cfg = GAME_CONFIGS[this.currentGameType];
    let cardIdx = 0;

    for (let i = 0; i < this.players.length; i++) {
      this.players[i].cards = deck.slice(cardIdx, cardIdx + cfg.cardsPerPlayer);
      cardIdx += cfg.cardsPerPlayer;
    }

    if (cfg.community > 0) {
      this.communityCards = deck.slice(cardIdx, cardIdx + cfg.community);
      cardIdx += cfg.community;
    }

    this.renderDeck();
    this.renderPlayers();
    this.updateUI();

    if (this.isReady()) {
      setTimeout(() => {
        if (this.isReady()) {
          this.calculate();
        }
      }, 200);
    }
  }

  renderPlayers() {
    const cfg = GAME_CONFIGS[this.currentGameType];
    const commSection = document.getElementById('communitySection');
    const commContainer = document.getElementById('communityCardsContainer');
    const txtCommCount = document.getElementById('txtCommunityCount');

    const allPlayersFull = this.players.every((p, i) => p.cards.length >= this.targetCards(i));
    const commNeedsCards = cfg.community > 0 && this.communityCards.length < cfg.community;
    const isCommSelected = commNeedsCards && !this.players.some(p => p.rankOrder != null) && (this.isSelectingCommunity || (this.inputMode === 'roundRobin' && allPlayersFull) || (this.inputMode === 'manual' && allPlayersFull));

    if (cfg.community > 0) {
      commSection.style.display = 'block';
      if (isCommSelected) {
        commSection.classList.add('active');
      } else {
        commSection.classList.remove('active');
      }

      txtCommCount.innerHTML = `${isCommSelected ? '<span class="comm-active-tag">▶ Đang chọn</span> ' : ''}${this.communityCards.length}/${cfg.community}`;
      commContainer.innerHTML = '';
      this.communityCards.forEach(c => {
        const mini = this.createMiniCard(c);
        commContainer.appendChild(mini);
      });
      const rem = Math.max(0, cfg.community - this.communityCards.length);
      for (let i = 0; i < rem; i++) {
        const ph = document.createElement('div');
        ph.className = 'placeholder-card';
        ph.textContent = '+';
        commContainer.appendChild(ph);
      }
      commSection.onclick = () => {
        if (this.inputMode === 'manual') {
          this.isSelectingCommunity = true;
          this.renderPlayers();
          this.updateUI();
        }
      };
    } else {
      commSection.style.display = 'none';
      commSection.onclick = null;
    }

    const list = document.getElementById('playersList');
    list.innerHTML = '';

    this.players.forEach((p, idx) => {
      const target = this.targetCards(idx);
      const isRR = this.inputMode === 'roundRobin' && this.roundRobinPointer === idx && !allPlayersFull;
      const isManual = this.inputMode === 'manual' && this.selectedPlayerIndex === idx && !this.isSelectingCommunity && !isCommSelected;
      const hasResult = p.rankOrder != null;
      const isWinner = p.rankOrder === 1;
      const isActive = isRR || isManual;

      const mat = document.createElement('div');
      mat.className = `player-compact-card ${isActive && !hasResult ? 'active' : ''} ${isWinner ? 'winner-mat' : ''}`;
      mat.addEventListener('click', () => {
        if (this.inputMode === 'manual') {
          this.selectedPlayerIndex = idx;
          this.isSelectingCommunity = false;
          this.renderPlayers();
          this.updateUI();
        }
      });

      let rankBadgeHtml = '';
      if (hasResult) {
        const isTie = this.players.filter(other => other.rankOrder === p.rankOrder).length > 1;
        const rankText = p.rankOrder === 1 ? (isTie ? '👑 Đ.Hạng 1' : '👑 Nhất') :
                         (p.rankOrder === 2 ? (isTie ? '🥈 Đ.Hạng 2' : '🥈 Nhì') :
                         (p.rankOrder === 3 ? (isTie ? '🥉 Đ.Hạng 3' : '🥉 Ba') :
                         (isTie ? `Đ.Hạng ${p.rankOrder}` : `Hạng ${p.rankOrder}`)));
        const badgeClass = p.rankOrder === 1 ? 'rank-1' : (p.rankOrder === 2 ? 'rank-2' : 'rank-other');
        const scoreStr = p.score !== 0 ? `<span class="p-score-tag ${p.score > 0 ? 'score-pos' : 'score-neg'}">${p.score > 0 ? '+' : ''}${p.score} chi</span>` : '';
        const titleHtml = p.resultTitle ? `<span class="p-hand-title-inline">${p.resultTitle}</span>` : '';
        rankBadgeHtml = `<span class="p-rank-badge ${badgeClass}">${rankText}</span> ${titleHtml} ${scoreStr}`;
      }



      const counterHtml = `<span class="p-count ${p.cards.length === target ? 'full' : ''}">${p.cards.length}/${target} lá</span>`;

      const header = document.createElement('div');
      header.className = 'player-card-header';
      header.innerHTML = `
        <div class="p-left">
          <span class="p-dot" style="${isWinner ? 'background:#f59e0b;' : ''}"></span>
          <div class="p-name-container" title="Bấm để đổi tên tụ">
            <span class="p-name" style="${isWinner ? 'color:#f59e0b;font-weight:700;' : ''}">${p.name}</span>
            <span class="p-edit-icon">✏️</span>
          </div>
                    ${rankBadgeHtml ? rankBadgeHtml : (isActive ? `<span class="p-tag">${this.inputMode === 'roundRobin' ? '▶ Lượt nhận' : '▶ Đang chọn'}</span>` : '')}
        </div>
        ${counterHtml}
      `;
      
      const nameBox = header.querySelector('.p-name-container');
      nameBox.addEventListener('click', (e) => {
        e.stopPropagation();
        this.renamePlayer(idx);
      });


      
      mat.appendChild(header);

      const cardsContainer = document.createElement('div');
      cardsContainer.className = 'hand-cards-container';

      if (this.currentGameType === 'binh9' || this.currentGameType === 'binh6Split') {
        const chiCount = this.currentGameType === 'binh9' ? 3 : 2;
        const chiGroupsWrap = document.createElement('div');
        chiGroupsWrap.className = 'chi-groups-wrapper';

        for (let chiIdx = 0; chiIdx < chiCount; chiIdx++) {
          const startIdx = chiIdx * 3;
          const chiCards = (startIdx < p.cards.length) ? p.cards.slice(startIdx, startIdx + 3) : [];
          const missingInChi = 3 - chiCards.length;

          const chiBox = document.createElement('div');
          chiBox.className = 'chi-group-box';

          const chiLabel = document.createElement('div');
          chiLabel.className = 'chi-group-label';
          chiLabel.textContent = `Chi ${chiIdx + 1}`;
          chiBox.appendChild(chiLabel);

          const chiCardsDiv = document.createElement('div');
          chiCardsDiv.className = 'chi-group-cards';

          chiCards.forEach(c => {
            const mini = this.createMiniCard(c);
            chiCardsDiv.appendChild(mini);
          });

          for (let m = 0; m < missingInChi; m++) {
            const ph = document.createElement('div');
            ph.className = 'placeholder-card';
            ph.textContent = '+';
            chiCardsDiv.appendChild(ph);
          }

          chiBox.appendChild(chiCardsDiv);
          chiGroupsWrap.appendChild(chiBox);
        }

        cardsContainer.appendChild(chiGroupsWrap);
      } else {
        const overlapWrap = document.createElement('div');
        overlapWrap.className = 'card-overlap-wrapper';

        p.cards.forEach(c => {
          const mini = this.createMiniCard(c);
          overlapWrap.appendChild(mini);
        });

        const missing = Math.max(0, target - p.cards.length);
        const showPlaceholders = Math.min(missing, 6);
        for (let i = 0; i < showPlaceholders; i++) {
          const ph = document.createElement('div');
          ph.className = 'placeholder-card';
          ph.textContent = '+';
          overlapWrap.appendChild(ph);
        }
        if (missing > showPlaceholders) {
          const morePh = document.createElement('div');
          morePh.className = 'placeholder-card';
          morePh.style.fontSize = '9px';
          morePh.textContent = `+${missing - showPlaceholders}`;
          overlapWrap.appendChild(morePh);
        }

        cardsContainer.appendChild(overlapWrap);
      }

      mat.appendChild(cardsContainer);
      list.appendChild(mat);
    });
  }

  createMiniCard(card) {
    const mini = document.createElement('div');
    if (card.isHidden) {
      mini.className = 'mini-card hidden-card';
      mini.innerHTML = `
        <span class="mini-card-rank">?</span>
        <span class="mini-card-suit">Ẩn</span>
      `;
      mini.title = 'Lá ẩn (Không thấy) - Bấm để gỡ';
    } else if (card.isRankOnly) {
      let colorCls = card.sym === 'A' ? 'red' : (['J', 'Q', 'K'].includes(card.sym) ? 'blue' : 'black');
      mini.className = `mini-card rank-only ${colorCls}`;
      mini.innerHTML = `
        <span class="mini-card-rank">${card.sym}</span>
      `;
      mini.title = `Lá ${card.sym} (Bấm để gỡ)`;
    } else {
      mini.className = `mini-card ${card.isRed ? 'red' : 'black'}`;
      mini.innerHTML = `
        <span class="mini-card-rank">${card.sym}</span>
        <span class="mini-card-suit">${card.suitIcon}</span>
      `;
      mini.title = `${card.sym} ${card.suitName} (Bấm để gỡ)`;
    }
    mini.addEventListener('click', (e) => {
      e.stopPropagation();
      this.removeCard(card.id);
    });
    return mini;
  }

  updateUI() {
    const cfg = GAME_CONFIGS[this.currentGameType];
    document.getElementById('txtPlayerCount').textContent = `${this.playerCount} Nhóm`;

    const isReady = this.isReady();
    const hasResults = this.players.some(p => p.rankOrder != null);

    const btnCalc = document.getElementById('btnCalculate');
    if (hasResults) {
      btnCalc.disabled = false;
      btnCalc.className = 'btn-showdown-full btn-new-round';
      btnCalc.innerHTML = `<span>🔄 VÁN MỚI</span>`;
    } else {
      btnCalc.disabled = false;
      btnCalc.className = 'btn-showdown-full';
      btnCalc.innerHTML = `<span>❓ KHÔNG THẤY (BÀI ẨN)</span>`;
    }

    // Turn indicator
    const turn = document.getElementById('turnIndicator');
    if (this.inputMode === 'roundRobin') {
      const nextP = this.players[this.roundRobinPointer];
      const short = nextP ? nextP.name.replace("Nhóm ", "") : '—';
      turn.innerHTML = `Lượt: <strong>${short}</strong>`;
    } else {
      const curP = this.players[this.selectedPlayerIndex];
      const short = curP ? curP.name.replace("Nhóm ", "") : '—';
      turn.innerHTML = `Chọn: <strong>${short}</strong>`;
    }
  }


  calculate() {
    switch(this.currentGameType) {
      case 'lieng3':
        this.calcLieng();
        break;
      case 'xiDach2':
        this.calcXiDach();
        break;
      case 'texasHoldem':
        this.calcHoldem();
        break;
      case 'binh9':
        this.calcBinh9();
        break;
      case 'binh6Poker':
        this.calcBinh6Poker();
        break;
      case 'binh6Split':
        this.calcBinh6Split();
        break;
    }
    this.recordMatchResult();
    this.renderPlayers(); // Show result directly on the mats!
    this.updateUI();
  }

  recordMatchResult() {
    const winner = [...this.players].sort((a, b) => (a.rankOrder || 99) - (b.rankOrder || 99))[0];
    const record = {
      id: Date.now(),
      time: new Date().toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
      game: GAME_CONFIGS[this.currentGameType].name,
      winner: winner ? winner.name : '—',
      winnerTitle: winner ? winner.resultTitle : '',
      scores: this.players.map(p => ({
        name: p.name,
        rank: p.rankOrder,
        score: p.score,
        hand: p.resultTitle
      }))
    };
    this.history.unshift(record);
    if (this.history.length > 50) this.history.pop();
    try {
      localStorage.setItem('card_game_history', JSON.stringify(this.history));
    } catch (e) {}
  }

  openHistoryModal() {
    const cumulative = {};
    this.history.forEach(m => {
      m.scores.forEach(s => {
        if (!cumulative[s.name]) cumulative[s.name] = { wins: 0, score: 0 };
        if (s.rank === 1) cumulative[s.name].wins++;
        cumulative[s.name].score += (s.score || 0);
      });
    });

    const sbContainer = document.getElementById('cumulativeScoreboard');
    const sortedPlayers = Object.entries(cumulative).sort((a, b) => {
      if (b[1].score !== a[1].score) return b[1].score - a[1].score;
      return b[1].wins - a[1].wins;
    });

    if (sortedPlayers.length === 0) {
      sbContainer.innerHTML = '<div style="font-size: 12px; color: var(--ios-subtext); padding: 6px 0;">Chưa có dữ liệu ván đấu nào.</div>';
    } else {
      let sbHtml = '';
      sortedPlayers.forEach(([name, stat], idx) => {
        const medal = idx === 0 ? '🥇 ' : (idx === 1 ? '🥈 ' : (idx === 2 ? '🥉 ' : ''));
        const scoreStr = stat.score !== 0 ? `<span class="cumulative-score ${stat.score > 0 ? 'positive' : 'negative'}">${stat.score > 0 ? '+' : ''}${stat.score} chi</span>` : '';
        sbHtml += `
          <div class="cumulative-row">
            <span class="cumulative-name">${medal}${name} (${stat.wins} ván Nhất)</span>
            ${scoreStr}
          </div>
        `;
      });
      sbContainer.innerHTML = sbHtml;
    }

    const listContainer = document.getElementById('historyMatchesList');
    if (this.history.length === 0) {
      listContainer.innerHTML = '<div style="font-size: 12px; color: var(--ios-subtext); text-align: center; padding: 16px 0;">Chưa có ván bài nào được lưu. Hãy bấm "So Bài" sau mỗi ván để lưu tự động!</div>';
    } else {
      let listHtml = '';
      this.history.forEach((m, idx) => {
        const scoresSummary = m.scores.map(s => `${s.name}: ${s.score !== 0 ? (s.score > 0 ? '+' + s.score : s.score) + ' chi' : 'Hạng ' + s.rank}`).join(' | ');
        listHtml += `
          <div class="history-match-item">
            <div class="history-match-header">
              <span>#${this.history.length - idx} • ${m.game}</span>
              <span>${m.time}</span>
            </div>
            <div class="history-match-winner">🏆 Nhất: ${m.winner} (${m.winnerTitle})</div>
            <div class="history-match-scores">${scoresSummary}</div>
          </div>
        `;
      });
      listContainer.innerHTML = listHtml;
    }

    document.getElementById('modalHistory').style.display = 'flex';
  }

  closeHistoryModal() {
    document.getElementById('modalHistory').style.display = 'none';
  }

  clearHistory() {
    if (confirm("Bạn có chắc chắn muốn xóa toàn bộ lịch sử thắng thua các ván?")) {
      this.history = [];
      try {
        localStorage.removeItem('card_game_history');
      } catch (e) {}
      this.openHistoryModal();
    }
  }


  calcLieng() {
    const preset = this.isRankOnlyActive() ? 'international' : this.suitPreset;
    const evaluated = this.players.map((p, idx) => {
      const score = LiengEvaluator.evaluate(p.cards, preset);
      p.resultTitle = score.desc;
      p.resultDetail = `Loại: ${score.typeName}`;
      return { idx, score };
    });

    evaluated.sort((a, b) => LiengEvaluator.compare(b.score, a.score));
    let currentRank = 1;
    evaluated.forEach((item, r) => {
      if (r > 0 && LiengEvaluator.compare(item.score, evaluated[r - 1].score) < 0) {
        currentRank = r + 1;
      }
      this.players[item.idx].rankOrder = currentRank;
    });

    const winners = this.players.filter(p => p.rankOrder === 1);
    if (winners.length > 1) {
      document.getElementById('bannerWinner').innerHTML = `
        👑 <strong>Đồng Hạng 1</strong>: ${winners.map(w => w.name).join(', ')} (Cùng ${winners[0].resultTitle})!
      `;
    } else {
      const winner = winners[0];
      document.getElementById('bannerWinner').innerHTML = `
        🏆 <strong>${winner ? winner.name : '—'}</strong> Thắng Cuộc với ${winner ? winner.resultTitle : ''}!
      `;
    }
    document.getElementById('matrixSection').style.display = 'none';
  }

  calcXiDach() {
    const evaluated = this.players.map((p, idx) => {
      const score = XiDachEvaluator.evaluate(p.cards);
      p.resultTitle = score.title;
      p.resultDetail = score.detail;
      return { idx, score };
    });

    evaluated.sort((a, b) => XiDachEvaluator.compare(b.score, a.score));
    let currentRank = 1;
    evaluated.forEach((item, r) => {
      if (r > 0 && XiDachEvaluator.compare(item.score, evaluated[r - 1].score) < 0) {
        currentRank = r + 1;
      }
      this.players[item.idx].rankOrder = currentRank;
    });

    const winners = this.players.filter(p => p.rankOrder === 1);
    if (winners.length > 1) {
      document.getElementById('bannerWinner').innerHTML = `
        👑 <strong>Đồng Hạng 1</strong>: ${winners.map(w => w.name).join(', ')} (Cùng ${winners[0].resultTitle})!
      `;
    } else {
      const winner = winners[0];
      document.getElementById('bannerWinner').innerHTML = `
        🏆 <strong>${winner ? winner.name : '—'}</strong> Thắng Xì Dách với ${winner ? winner.resultTitle : ''}!
      `;
    }
    document.getElementById('matrixSection').style.display = 'none';
  }

  calcHoldem() {
    const evaluated = this.players.map((p, idx) => {
      const all7 = [...p.cards, ...this.communityCards];
      const best5 = PokerEvaluator.evaluateBestOfMany(all7);
      p.resultTitle = best5.desc;
      p.resultDetail = `5 lá tạo bộ: ${best5.cards.map(c => c.sym + c.suitIcon).join(' ')}`;
      return { idx, score: best5 };
    });

    evaluated.sort((a, b) => PokerEvaluator.compareScores(b.score, a.score));
    let currentRank = 1;
    evaluated.forEach((item, r) => {
      if (r > 0 && PokerEvaluator.compareScores(item.score, evaluated[r - 1].score) < 0) {
        currentRank = r + 1;
      }
      this.players[item.idx].rankOrder = currentRank;
    });

    const winners = this.players.filter(p => p.rankOrder === 1);
    if (winners.length > 1) {
      document.getElementById('bannerWinner').innerHTML = `
        👑 <strong>Đồng Hạng 1 (Split Pot)</strong>: ${winners.map(w => w.name).join(', ')} với ${winners[0].resultTitle}!
      `;
    } else {
      const winner = winners[0];
      document.getElementById('bannerWinner').innerHTML = `
        🏆 <strong>${winner ? winner.name : '—'}</strong> Thắng Pot với ${winner ? winner.resultTitle : ''}!
      `;
    }
    document.getElementById('matrixSection').style.display = 'none';
  }

  calcBinh9() {
    const arrangements = this.players.map(p => {
      const arr = Binh9Evaluator.autoArrange(p.cards);
      p.cards = [...arr.chi1, ...arr.chi2, ...arr.chi3];
      p.isLung = arr.isLung;
      p.score = 0;
      if (arr.instantWin) {
        p.resultTitle = arr.instantWin;
        p.resultDetail = "Tự động Thắng Trắng mà không cần so từng chi!";
      } else if (arr.isLung) {
        p.resultTitle = "⚠️ BỊ LỦNG (Thua phạt -6 chi)";
        p.resultDetail = "Chi dưới yếu hơn chi trên!";
      } else {
        p.resultTitle = "Đã xếp 3 chi tối ưu";
        p.resultDetail = `Chi 1 (3 lá): ${arr.score1.desc}\nChi 2 (3 lá): ${arr.score2.desc}\nChi 3 (3 lá): ${arr.score3.desc}`;
      }
      return arr;
    });

    const N = this.players.length;
    const matrix = Array.from({ length: N }, () => Array(N).fill('—'));

    for (let i = 0; i < N; i++) {
      for (let j = i + 1; j < N; j++) {
        const match = Binh9Evaluator.compareMatch(arrangements[i], arrangements[j]);
        this.players[i].score += match.scoreA;
        this.players[j].score -= match.scoreA;
        matrix[i][j] = (match.scoreA > 0 ? `+${match.scoreA}` : `${match.scoreA}`) + " chi";
        matrix[j][i] = (-match.scoreA > 0 ? `+${-match.scoreA}` : `${-match.scoreA}`) + " chi";
      }
    }

    const sortedIdx = Array.from({ length: N }, (_, i) => i).sort((a, b) => this.players[b].score - this.players[a].score);
    let currentRank = 1;
    sortedIdx.forEach((idx, r) => {
      if (r > 0 && this.players[idx].score < this.players[sortedIdx[r - 1]].score) {
        currentRank = r + 1;
      }
      this.players[idx].rankOrder = currentRank;
    });

    const winners = this.players.filter(p => p.rankOrder === 1);
    if (winners.length > 1) {
      document.getElementById('bannerWinner').innerHTML = `
        👑 <strong>Đồng Hạng 1</strong>: ${winners.map(w => w.name).join(', ')} (Cùng <strong>${winners[0].score > 0 ? '+' : ''}${winners[0].score} chi</strong>)!
      `;
    } else {
      const winner = winners[0];
      document.getElementById('bannerWinner').innerHTML = `
        🏆 <strong>${winner ? winner.name : '—'}</strong> Dẫn đầu với tổng điểm: <strong>${winner ? (winner.score > 0 ? '+' : '') + winner.score : 0} chi</strong>!
      `;
    }

    const matSection = document.getElementById('matrixSection');
    matSection.style.display = 'block';
    const matWrapper = document.getElementById('matrixTableWrapper');
    let tblHtml = `<table class="matrix-table"><thead><tr><th>Nhà</th>`;
    this.players.forEach(p => {
      tblHtml += `<th>${p.name.replace("Nhóm ", "")}</th>`;
    });
    tblHtml += `</tr></thead><tbody>`;

    for (let i = 0; i < N; i++) {
      tblHtml += `<tr><td><strong>${this.players[i].name.replace("Nhóm ", "")}</strong></td>`;
      for (let j = 0; j < N; j++) {
        const val = matrix[i][j];
        const color = val.includes('+') ? '#34C759' : (val.includes('-') ? '#FF3B30' : '#8E8E93');
        tblHtml += `<td style="color: ${color}; font-weight: bold;">${val}</td>`;
      }
      tblHtml += `</tr>`;
    }
    tblHtml += `</tbody></table>`;
    matWrapper.innerHTML = tblHtml;
  }

  calcBinh6Poker() {
    const evaluated = this.players.map((p, idx) => {
      const best5 = PokerEvaluator.evaluateBestOfMany(p.cards);
      p.resultTitle = best5.desc;
      p.resultDetail = `5 lá tốt nhất từ 6 lá: ${best5.cards.map(c => c.sym + c.suitIcon).join(' ')}`;
      return { idx, score: best5 };
    });

    evaluated.sort((a, b) => PokerEvaluator.compareScores(b.score, a.score));
    let currentRank = 1;
    evaluated.forEach((item, r) => {
      if (r > 0 && PokerEvaluator.compareScores(item.score, evaluated[r - 1].score) < 0) {
        currentRank = r + 1;
      }
      this.players[item.idx].rankOrder = currentRank;
    });

    const winners = this.players.filter(p => p.rankOrder === 1);
    if (winners.length > 1) {
      document.getElementById('bannerWinner').innerHTML = `
        👑 <strong>Đồng Hạng 1</strong>: ${winners.map(w => w.name).join(', ')} với ${winners[0].resultTitle}!
      `;
    } else {
      const winner = winners[0];
      document.getElementById('bannerWinner').innerHTML = `
        🏆 <strong>${winner ? winner.name : '—'}</strong> Thắng Binh 6 lá với ${winner ? winner.resultTitle : ''}!
      `;
    }
    document.getElementById('matrixSection').style.display = 'none';
  }

  calcBinh6Split() {
    this.calcBinh6Poker();
  }

  openResultModal() {
    const container = document.getElementById('rankingsContainer');
    container.innerHTML = '';

    const sorted = [...this.players].sort((a, b) => (a.rankOrder || 99) - (b.rankOrder || 99));

    sorted.forEach(p => {
      const item = document.createElement('div');
      item.className = 'rank-item';
      const rankCls = p.rankOrder === 1 ? 'rank-1' : (p.rankOrder === 2 ? 'rank-2' : (p.rankOrder === 3 ? 'rank-3' : 'rank-other'));
      const isTie = this.players.filter(other => other.rankOrder === p.rankOrder).length > 1;

      item.innerHTML = `
        <div class="rank-badge ${rankCls}">${p.rankOrder}</div>
        <div class="rank-info">
          <div class="rank-title-row">
            <div>
              <span class="rank-player-name">${p.name}</span>
              ${isTie ? '<span class="tie-tag" style="font-size:10px;font-weight:700;color:#f59e0b;background:rgba(245,158,11,0.15);padding:2px 5px;border-radius:4px;margin-left:4px;">ĐỒNG HẠNG</span>' : ''}
              ${p.isLung ? '<span class="lung-tag">LỦNG</span>' : ''}
            </div>
            ${p.score !== 0 ? `<span class="rank-score ${p.score > 0 ? 'positive' : 'negative'}">${p.score > 0 ? '+' : ''}${p.score} chi</span>` : ''}
          </div>
          <div class="rank-hand-title">${p.resultTitle}</div>
          <div class="rank-hand-detail">${p.resultDetail}</div>
        </div>
      `;
      container.appendChild(item);
    });

    document.getElementById('modalResult').style.display = 'flex';
  }

  closeResultModal() {
    document.getElementById('modalResult').style.display = 'none';
  }

  openSettings() {
    const cfg = GAME_CONFIGS[this.currentGameType];
    document.getElementById('gameRuleDescription').textContent = cfg.desc;
    
    // Sync current suitPreset to the radio buttons
    const radio = document.querySelector(`input[name="suitPreset"][value="${this.suitPreset}"]`);
    if (radio) {
      radio.checked = true;
    }

    const chkRank = document.getElementById('chkRankOnlyMode');
    if (chkRank) {
      chkRank.checked = this.isRankOnlyMode;
    }

    document.getElementById('modalSettings').style.display = 'flex';
  }

  closeSettings() {
    document.getElementById('modalSettings').style.display = 'none';
  }

  saveSettings() {
    const selected = document.querySelector('input[name="suitPreset"]:checked');
    if (selected) {
      this.suitPreset = selected.value;
    }

    const chkRank = document.getElementById('chkRankOnlyMode');
    if (chkRank) {
      this.isRankOnlyMode = chkRank.checked;
      localStorage.setItem('card_game_rank_only_mode', this.isRankOnlyMode ? 'true' : 'false');
    }

    this.renderDeck();
    if (this.isReady()) {
      this.calculate();
    } else {
      this.renderPlayers();
      this.updateUI();
    }
    this.closeSettings();
  }
}

// Instantiate on load
window.addEventListener('DOMContentLoaded', () => {
  window.app = new AppController();
});
