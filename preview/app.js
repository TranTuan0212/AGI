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
  phom9: {
    name: "Phỏm 9 lá (Tá Lả)",
    cardsPerPlayer: 9,
    community: 0,
    minPlayers: 2,
    maxPlayers: 4,
    desc: "9 lá/người (2-4 người). Ghép các phỏm dọc (sảnh cùng chất) hoặc phỏm ngang (3-4 lá cùng số). Ai Ù (0 lá rác) thắng tuyệt đối. Tính điểm các lá rác còn lại (A=1, J=11, Q=12, K=13), ít điểm nhất thắng; không có phỏm bị Móm (Cháy)."
  },
  binh13: {
    name: "Binh 13 lá (Mậu Binh / Chợ Lớn)",
    cardsPerPlayer: 13,
    community: 0,
    minPlayers: 2,
    maxPlayers: 4,
    desc: "13 lá/người, xếp 3 chi (3-5-5), luật Chi 3 ≥ Chi 2 ≥ Chi 1 (sai bị lủng x2), tính điểm từng chi + thưởng hàng, đè hàng x2, sập hầm x2, thắng trắng (Sảnh rồng, Đồng hoa, 6 đôi...)."
  },
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

class Binh13Evaluator {
  static checkInstantWin(cards) {
    if (!cards || cards.length !== 13) return null;
    const sorted = [...cards].sort((a, b) => a.rank - b.rank);
    const ranks = sorted.map(c => c.rank);
    const suits = sorted.map(c => c.suit);

    const isDragon = ranks.every((r, idx) => r === idx + 2);
    // 1. Rồng cuốn: 2->A cùng chất
    if (isDragon && suits.every(s => s === suits[0])) {
      return { name: "Thắng trắng: Rồng Cuốn (24 chi)", bonus: 24, rank: 7 };
    }
    // 2. Sảnh rồng: 2->A khác chất
    if (isDragon) {
      return { name: "Thắng trắng: Sảnh Rồng (12 chi)", bonus: 12, rank: 6 };
    }
    // 3. Đồng hoa 13 lá (toàn đỏ hoặc toàn đen)
    const allRed = suits.every(s => s === 'hearts' || s === 'diamonds');
    const allBlack = suits.every(s => s === 'spades' || s === 'clubs');
    if (allRed || allBlack) {
      return { name: "Thắng trắng: Đồng Hoa 13 Lá (8 chi)", bonus: 8, rank: 5 };
    }

    const counts = {};
    ranks.forEach(r => { counts[r] = (counts[r] || 0) + 1; });
    const cVals = Object.values(counts);
    const triples = cVals.filter(v => v >= 3).length;
    const pairs = cVals.reduce((acc, v) => acc + Math.floor(v / 2), 0);

    // 4. 5 đôi 1 sám
    if (triples === 1 && cVals.filter(v => v === 2).length === 5) {
      return { name: "Thắng trắng: 5 Đôi 1 Sám (6 chi)", bonus: 6, rank: 4 };
    }
    // 5. Lục phé bôn (6 đôi)
    if (pairs === 6) {
      return { name: "Thắng trắng: Lục Phé Bôn (6 Đôi) (6 chi)", bonus: 6, rank: 3 };
    }

    return null;
  }

  static evaluateFront(cards) {
    const sorted = [...cards].sort((a, b) => b.rank - a.rank);
    const ranks = sorted.map(c => c.rank);
    const sym = r => RANKS.find(x => x.raw === r)?.sym || r;

    if (ranks[0] === ranks[1] && ranks[1] === ranks[2]) {
      return { type: 3, primary: ranks[0], kickers: [], desc: `Sám cô ${sym(ranks[0])} (+3 chi)` };
    }
    if (ranks[0] === ranks[1]) {
      return { type: 2, primary: ranks[0], kickers: [ranks[2]], desc: `Đôi ${sym(ranks[0])} (Kicker ${sym(ranks[2])})` };
    }
    if (ranks[1] === ranks[2]) {
      return { type: 2, primary: ranks[1], kickers: [ranks[0]], desc: `Đôi ${sym(ranks[1])} (Kicker ${sym(ranks[0])})` };
    }
    return { type: 1, primary: ranks[0], kickers: [ranks[1], ranks[2]], desc: `Mậu thầu đỉnh ${sym(ranks[0])}` };
  }

  static compareFront(a, b) {
    if (a.type !== b.type) return a.type - b.type;
    if (a.primary !== b.primary) return a.primary - b.primary;
    for (let i = 0; i < Math.min(a.kickers.length, b.kickers.length); i++) {
      if (a.kickers[i] !== b.kickers[i]) return a.kickers[i] - b.kickers[i];
    }
    return 0;
  }

  static isMiddleGTEFront(middle, front) {
    if (front.type === 3) {
      if (middle.type < 4) return false;
      if (middle.type === 4) return middle.tieBreakers[0] >= front.primary;
      return true;
    }
    if (front.type === 2) {
      if (middle.type < 2) return false;
      if (middle.type === 2) {
        if (middle.tieBreakers[0] > front.primary) return true;
        if (middle.tieBreakers[0] < front.primary) return false;
        return middle.tieBreakers[1] >= (front.kickers[0] || 0);
      }
      return true;
    }
    if (middle.type > 1) return true;
    return middle.tieBreakers[0] >= front.primary;
  }

  static autoArrange(cards) {
    // Nhóm A: Instant-check trực tiếp từ 13 lá thô (không cần xếp chi)
    const instant = this.checkInstantWin(cards);
    if (instant) {
      const sorted = [...cards].sort((a, b) => b.rank - a.rank);
      return {
        front: sorted.slice(0, 3),
        middle: sorted.slice(3, 8),
        back: sorted.slice(8, 13),
        frontScore: this.evaluateFront(sorted.slice(0, 3)),
        middleScore: PokerEvaluator.evaluate5(sorted.slice(3, 8)),
        backScore: PokerEvaluator.evaluate5(sorted.slice(8, 13)),
        isLung: false,
        instantWin: instant
      };
    }

    const indices = Array.from({ length: 13 }, (_, i) => i);
    const back5Indices = getCombinations(indices, 5);
    let best = null;
    let bestWeight = -999999;
    let foundGroupBInstant = null;

    for (const bIdx of back5Indices) {
      const backCards = bIdx.map(i => cards[i]);
      const backScore = PokerEvaluator.evaluate5(backCards);

      const rem1 = indices.filter(i => !bIdx.includes(i));
      const mid5Indices = getCombinations(rem1, 5);

      for (const mIdx of mid5Indices) {
        const midCards = mIdx.map(i => cards[i]);
        const midScore = PokerEvaluator.evaluate5(midCards);

        // Back >= Middle
        if (PokerEvaluator.compareScores(backScore, midScore) < 0) continue;

        const fIdx = rem1.filter(i => !mIdx.includes(i));
        const frontCards = fIdx.map(i => cards[i]);
        const frontScore = this.evaluateFront(frontCards);

        // Middle >= Front
        if (!this.isMiddleGTEFront(midScore, frontScore)) continue;

        // Nhóm B: Kiểm tra Ba Cái Thùng / Ba Cái Sảnh phụ thuộc vào cách xếp chi hợp lệ
        const isFrontFlush = (frontCards[0].suit === frontCards[1].suit && frontCards[1].suit === frontCards[2].suit);
        const isMidFlush = (midScore.type === 6 || midScore.type >= 9);
        const isBackFlush = (backScore.type === 6 || backScore.type >= 9);

        const sortedF = [...frontCards].sort((a, b) => b.rank - a.rank);
        const rf = sortedF.map(c => c.rank);
        const isFrontStraight = (rf[0] - rf[1] === 1 && rf[1] - rf[2] === 1) || (rf[0] === 14 && rf[1] === 3 && rf[2] === 2);
        const isMidStraight = (midScore.type === 5 || midScore.type >= 9);
        const isBackStraight = (backScore.type === 5 || backScore.type >= 9);

        let groupBWin = null;
        if (isBackFlush && isMidFlush && isFrontFlush) {
          groupBWin = { name: "Thắng trắng: Ba Cái Thùng (3 chi)", bonus: 3, rank: 2 };
        } else if (isBackStraight && isMidStraight && isFrontStraight) {
          groupBWin = { name: "Thắng trắng: Ba Cái Sảnh (3 chi)", bonus: 3, rank: 1 };
        }

        if (groupBWin) {
          const arrGB = {
            front: frontCards,
            middle: midCards,
            back: backCards,
            frontScore,
            middleScore: midScore,
            backScore,
            isLung: false,
            instantWin: groupBWin
          };
          if (!foundGroupBInstant || groupBWin.rank > foundGroupBInstant.instantWin.rank) {
            foundGroupBInstant = arrGB;
          }
        }

        let weight = backScore.type * 1000 + (backScore.tieBreakers[0] || 0) * 10;
        weight += midScore.type * 1500 + (midScore.tieBreakers[0] || 0) * 15;
        weight += frontScore.type * 2000 + frontScore.primary * 20;

        if (frontScore.type === 3) weight += 5000;
        if (midScore.type === 7) weight += 4000;
        if (midScore.type === 8) weight += 15000;
        if (backScore.type === 8) weight += 8000;
        if (backScore.type >= 9) weight += 10000;

        if (weight > bestWeight) {
          bestWeight = weight;
          best = {
            front: frontCards,
            middle: midCards,
            back: backCards,
            frontScore,
            middleScore: midScore,
            backScore,
            isLung: false,
            instantWin: null
          };
        }
      }
    }

    if (foundGroupBInstant) return foundGroupBInstant;
    if (best) return best;

    // Fallback: Lung
    const sorted = [...cards].sort((a, b) => b.rank - a.rank);
    return {
      front: sorted.slice(0, 3),
      middle: sorted.slice(3, 8),
      back: sorted.slice(8, 13),
      frontScore: this.evaluateFront(sorted.slice(0, 3)),
      middleScore: PokerEvaluator.evaluate5(sorted.slice(3, 8)),
      backScore: PokerEvaluator.evaluate5(sorted.slice(8, 13)),
      isLung: true,
      instantWin: null
    };
  }

  static calculateInherentBonus(arr) {
    if (arr.isLung || arr.instantWin) return { total: 0, detail: "" };
    let bonus = 0;
    const parts = [];
    if (arr.frontScore.type === 3) {
      bonus += 3;
      parts.push("Sám chi đầu (+3 chi)");
    }
    if (arr.middleScore.type === 7) {
      bonus += 2;
      parts.push("Cù lũ chi 2 (+2 chi)");
    } else if (arr.middleScore.type === 8) {
      bonus += 8;
      parts.push("Tứ quý chi 2 (+8 chi)");
    } else if (arr.middleScore.type >= 9) {
      bonus += 10;
      parts.push("Thùng phá sảnh chi 2 (+10 chi)");
    }
    if (arr.backScore.type === 8) {
      bonus += 4;
      parts.push("Tứ quý chi 3 (+4 chi)");
    } else if (arr.backScore.type >= 9) {
      bonus += 5;
      parts.push("Thùng phá sảnh chi 3 (+5 chi)");
    }
    return { total: bonus, detail: parts.join(", ") };
  }

  static compareMatch(a, b) {
    // 1. Thắng Trắng vs Thắng Trắng
    if (a.instantWin && b.instantWin) {
      if (a.instantWin.rank > b.instantWin.rank) {
        return { scoreA: a.instantWin.bonus, detail: `${a.instantWin.name} thắng ${b.instantWin.name} (+${a.instantWin.bonus} chi)` };
      } else if (a.instantWin.rank < b.instantWin.rank) {
        return { scoreA: -b.instantWin.bonus, detail: `Thua đối thủ ${b.instantWin.name} (-${b.instantWin.bonus} chi)` };
      }
      return { scoreA: 0, detail: `Cùng Thắng Trắng: Hòa` };
    }
    // 2. Thắng Trắng vs Bài thường
    if (a.instantWin) return { scoreA: a.instantWin.bonus, detail: `${a.instantWin.name} thắng tuyệt đối bài thường (+${a.instantWin.bonus} chi)` };
    if (b.instantWin) return { scoreA: -b.instantWin.bonus, detail: `Đối thủ có ${b.instantWin.name} thắng tuyệt đối (-${b.instantWin.bonus} chi)` };

    // 3. Xử lý Lủng
    if (a.isLung && b.isLung) return { scoreA: 0, detail: "Cả hai đều bị Lủng (0 chi)" };
    if (a.isLung) {
      const bH = this.calculateInherentBonus(b);
      const totalLoss = -(6 + bH.total);
      const detailStr = bH.total > 0 ? `Bị Lủng (phạt 6 chi + đền hàng đối thủ [${bH.detail}]: ${totalLoss} chi)` : "Bị Lủng (phạt thua 3 chi x2 = -6 chi)";
      return { scoreA: totalLoss, detail: detailStr };
    }
    if (b.isLung) {
      const aH = this.calculateInherentBonus(a);
      const totalWin = 6 + aH.total;
      const detailStr = aH.total > 0 ? `Đối thủ bị Lủng (thắng 6 chi + nhận hàng [${aH.detail}]: +${totalWin} chi)` : "Đối thủ bị Lủng (thắng 3 chi x2 = +6 chi)";
      return { scoreA: totalWin, detail: detailStr };
    }

    // 4. So chi bài thường
    // Chi 1
    let c1 = 0, c1Bonus = 0;
    const cmp1 = this.compareFront(a.frontScore, b.frontScore);
    if (cmp1 > 0) {
      c1 = 1;
      if (a.frontScore.type === 3) {
        c1Bonus = (b.frontScore.type === 3) ? 6 : 3; // Đè hàng sám chi đầu
      }
    } else if (cmp1 < 0) {
      c1 = -1;
      if (b.frontScore.type === 3) {
        c1Bonus = (a.frontScore.type === 3) ? -6 : -3;
      }
    }

    // Chi 2
    let c2 = 0, c2Bonus = 0;
    const cmp2 = PokerEvaluator.compareScores(a.middleScore, b.middleScore);
    if (cmp2 > 0) {
      c2 = 1;
      if (a.middleScore.type === 7) {
        c2Bonus = (b.middleScore.type === 7) ? 4 : 2; // Cù lũ
      } else if (a.middleScore.type === 8) {
        c2Bonus = (b.middleScore.type === 8) ? 16 : 8; // Đè hàng tứ quý cùng loại
      } else if (a.middleScore.type >= 9) {
        c2Bonus = (b.middleScore.type >= 9) ? 20 : 10; // Đè hàng thùng phá sảnh cùng loại
      }
    } else if (cmp2 < 0) {
      c2 = -1;
      if (b.middleScore.type === 7) {
        c2Bonus = (a.middleScore.type === 7) ? -4 : -2;
      } else if (b.middleScore.type === 8) {
        c2Bonus = (a.middleScore.type === 8) ? -16 : -8;
      } else if (b.middleScore.type >= 9) {
        c2Bonus = (a.middleScore.type >= 9) ? -20 : -10;
      }
    }

    // Chi 3
    let c3 = 0, c3Bonus = 0;
    const cmp3 = PokerEvaluator.compareScores(a.backScore, b.backScore);
    if (cmp3 > 0) {
      c3 = 1;
      if (a.backScore.type === 8) {
        c3Bonus = (b.backScore.type === 8) ? 8 : 4; // Đè hàng tứ quý chi cuối
      } else if (a.backScore.type >= 9) {
        c3Bonus = (b.backScore.type >= 9) ? 10 : 5;
      }
    } else if (cmp3 < 0) {
      c3 = -1;
      if (b.backScore.type === 8) {
        c3Bonus = (a.backScore.type === 8) ? -8 : -4;
      } else if (b.backScore.type >= 9) {
        c3Bonus = (a.backScore.type >= 9) ? -10 : -5;
      }
    }

    let base = c1 + c2 + c3;
    let sapText = "";
    if (c1 > 0 && c2 > 0 && c3 > 0) {
      base = 6;
      sapText = " (Bắt sập hầm x2 = +6 chi)";
    } else if (c1 < 0 && c2 < 0 && c3 < 0) {
      base = -6;
      sapText = " (Bị sập hầm x2 = -6 chi)";
    }

    const bonus = c1Bonus + c2Bonus + c3Bonus;
    const total = base + bonus;
    return {
      scoreA: total,
      detail: `Chi 1: ${c1 > 0 ? '+1' : c1}, Chi 2: ${c2 > 0 ? '+1' : c2}, Chi 3: ${c3 > 0 ? '+1' : c3}${sapText}${bonus !== 0 ? `, Hàng: ${bonus > 0 ? '+' : ''}${bonus}` : ''} ➔ Tổng: ${total > 0 ? '+' : ''}${total} chi`
    };
  }
}

// MARK: - Phom (Tá Lả) Evaluator
class PhomEvaluator {
  static cardPoint(card) {
    if (card.rank === 14) return 1; // A = 1
    return card.rank; // 2..13 (J=11, Q=12, K=13)
  }

  static hasCa(c1, c2) {
    if (c1.rank === c2.rank) return true;
    if (c1.suit === c2.suit) {
      const diff = Math.abs(c1.rank - c2.rank);
      if (diff <= 2) return true;
      // Ace as 1
      const a1 = c1.rank === 14 ? 1 : c1.rank;
      const a2 = c2.rank === 14 ? 1 : c2.rank;
      if (Math.abs(a1 - a2) <= 2) return true;
    }
    return false;
  }

  static checkUKhan(cards) {
    if (cards.length !== 9) return false;
    for (let i = 0; i < cards.length; i++) {
      for (let j = i + 1; j < cards.length; j++) {
        if (this.hasCa(cards[i], cards[j])) return false;
      }
    }
    return true;
  }

  static evaluate(cards) {
    if (!cards || cards.length === 0) {
      return { isU: false, isMom: true, isUKhan: false, isUTron: false, phoms: [], deadwood: [], deadwoodScore: 0, summary: "Không có bài" };
    }

    // Check Ù Khan (9 cards with no cạ)
    if (cards.length === 9 && this.checkUKhan(cards)) {
      return {
        isU: true,
        isMom: false,
        isUKhan: true,
        isUTron: false,
        phoms: [],
        deadwood: [...cards],
        deadwoodScore: 0,
        summary: "🎉 Ù KHAN (Không có cạ, thắng tuyệt đối)"
      };
    }

    // 10-card hand evaluation
    if (cards.length === 10) {
      const all10Phoms = this.findAllCandidatePhoms(cards);
      let uTronPhoms = [];
      const search10 = (startIndex, currentPhoms, usedCardIds) => {
        const rem = cards.filter(c => !usedCardIds.has(c.id));
        if (rem.length === 0 && currentPhoms.length > 0) {
          uTronPhoms = [...currentPhoms];
          return;
        }
        for (let i = startIndex; i < all10Phoms.length; i++) {
          if (uTronPhoms.length > 0) return;
          const cand = all10Phoms[i];
          const candIds = new Set(cand.cards.map(c => c.id));
          let disjoint = true;
          for (const id of candIds) {
            if (usedCardIds.has(id)) { disjoint = false; break; }
          }
          if (disjoint) {
            const nextUsed = new Set(usedCardIds);
            candIds.forEach(id => nextUsed.add(id));
            search10(i + 1, [...currentPhoms, cand], nextUsed);
          }
        }
      };
      search10(0, [], new Set());

      if (uTronPhoms.length > 0) {
        const desc = uTronPhoms.map(p => p.description).join(" + ");
        return {
          isU: true,
          isMom: false,
          isUKhan: false,
          isUTron: true,
          phoms: uTronPhoms,
          deadwood: [],
          deadwoodScore: 0,
          summary: `🎉 Ù TRÒN 10 LÁ (Thắng x2) [${desc}]`
        };
      }

      // Not Ù Tròn: pick optimal 9-card subset (discarding 1 card)
      let bestSub = null;
      let bestDiscard = null;
      for (let i = 0; i < cards.length; i++) {
        const sub = cards.filter((_, idx) => idx !== i);
        const subRes = this.evaluate(sub);
        if (!bestSub) {
          bestSub = subRes;
          bestDiscard = cards[i];
        } else {
          if (subRes.isU && !bestSub.isU) {
            bestSub = subRes;
            bestDiscard = cards[i];
          } else if (subRes.isU === bestSub.isU) {
            if (!subRes.isMom && bestSub.isMom) {
              bestSub = subRes;
              bestDiscard = cards[i];
            } else if (subRes.isMom === bestSub.isMom) {
              if (subRes.deadwoodScore < bestSub.deadwoodScore) {
                bestSub = subRes;
                bestDiscard = cards[i];
              }
            }
          }
        }
      }

      if (bestSub && bestDiscard) {
        const discardNote = ` (Đã bỏ rác: ${bestDiscard.sym}${bestDiscard.suitIcon})`;
        return {
          isU: bestSub.isU,
          isMom: bestSub.isMom,
          isUKhan: bestSub.isUKhan,
          isUTron: false,
          phoms: bestSub.phoms,
          deadwood: bestSub.deadwood,
          deadwoodScore: bestSub.deadwoodScore,
          summary: bestSub.summary + discardNote
        };
      }
    }

    // Standard 9-card evaluation
    const allPhoms = this.findAllCandidatePhoms(cards);
    let bestPhoms = [];
    let bestDeadwood = [...cards];
    let minDeadwoodScore = cards.reduce((sum, c) => sum + this.cardPoint(c), 0);
    let isU = false;

    const search = (startIndex, currentPhoms, usedCardIds) => {
      const currentDeadwood = cards.filter(c => !usedCardIds.has(c.id));
      const currentScore = currentDeadwood.reduce((sum, c) => sum + this.cardPoint(c), 0);

      if (currentDeadwood.length === 0 && currentPhoms.length > 0) {
        isU = true;
        bestPhoms = [...currentPhoms];
        bestDeadwood = [];
        minDeadwoodScore = 0;
        return;
      }

      if (currentPhoms.length > 0) {
        if (bestPhoms.length === 0 || currentScore < minDeadwoodScore) {
          minDeadwoodScore = currentScore;
          bestPhoms = [...currentPhoms];
          bestDeadwood = currentDeadwood;
        }
      }

      for (let i = startIndex; i < allPhoms.length; i++) {
        if (isU) return;
        const candidate = allPhoms[i];
        const candIds = new Set(candidate.cards.map(c => c.id));
        let disjoint = true;
        for (const id of candIds) {
          if (usedCardIds.has(id)) {
            disjoint = false;
            break;
          }
        }
        if (disjoint) {
          const nextUsed = new Set(usedCardIds);
          candIds.forEach(id => nextUsed.add(id));
          search(i + 1, [...currentPhoms, candidate], nextUsed);
        }
      }
    };

    search(0, [], new Set());

    const isMom = bestPhoms.length === 0;
    if (isMom) {
      bestDeadwood = [...cards];
      minDeadwoodScore = cards.reduce((sum, c) => sum + this.cardPoint(c), 0);
    }

    let summary = "";
    if (isU) {
      const phomDesc = bestPhoms.map(p => p.description).join(" + ");
      summary = `🎉 Ù (0 điểm rác) [${phomDesc}]`;
    } else if (isMom) {
      summary = `💀 Móm / Cháy (Không có phỏm, ${minDeadwoodScore} điểm rác)`;
    } else {
      const phomDesc = bestPhoms.map(p => p.description).join(" + ");
      const deadwoodDesc = bestDeadwood.map(c => `${c.sym}${c.suitIcon}`).join(" ");
      summary = `${bestPhoms.length} Phỏm [${phomDesc}] | Rác (${deadwoodDesc}): ${minDeadwoodScore} điểm`;
    }

    return {
      isU,
      isMom,
      isUKhan: false,
      isUTron: false,
      phoms: bestPhoms,
      deadwood: bestDeadwood,
      deadwoodScore: minDeadwoodScore,
      summary
    };
  }

  static findAllCandidatePhoms(cards) {
    const candidates = [];

    // A. Phỏm ngang (3-4 lá cùng số)
    const rankGroups = {};
    cards.forEach(c => {
      rankGroups[c.rank] = rankGroups[c.rank] || [];
      rankGroups[c.rank].push(c);
    });

    for (const rank in rankGroups) {
      const grp = rankGroups[rank];
      if (grp.length === 3) {
        candidates.push({
          cards: grp,
          isVertical: false,
          description: `Phỏm ngang (${grp.map(c => c.sym + c.suitIcon).join(" ")})`
        });
      } else if (grp.length === 4) {
        candidates.push({
          cards: grp,
          isVertical: false,
          description: `Phỏm ngang 4 lá (${grp.map(c => c.sym + c.suitIcon).join(" ")})`
        });
        for (let i = 0; i < 4; i++) {
          const sub = grp.filter((_, idx) => idx !== i);
          candidates.push({
            cards: sub,
            isVertical: false,
            description: `Phỏm ngang (${sub.map(c => c.sym + c.suitIcon).join(" ")})`
          });
        }
      }
    }

    // B. Phỏm dọc (Cùng chất, liên tiếp >= 3 lá)
    const suitGroups = {};
    cards.forEach(c => {
      suitGroups[c.suit] = suitGroups[c.suit] || [];
      suitGroups[c.suit].push(c);
    });

    for (const suit in suitGroups) {
      const grp = suitGroups[suit];
      if (grp.length < 3) continue;

      const getVal = (c, aceHigh) => (c.rank === 14 ? (aceHigh ? 14 : 1) : c.rank);
      const sorted = [...grp].sort((a, b) => getVal(a, false) - getVal(b, false));

      const n = sorted.length;
      for (let i = 0; i < n - 2; i++) {
        for (let j = i + 2; j < n; j++) {
          const sub = sorted.slice(i, j + 1);
          let consec = true;
          for (let k = 0; k < sub.length - 1; k++) {
            if (getVal(sub[k + 1], false) !== getVal(sub[k], false) + 1) {
              consec = false;
              break;
            }
          }
          if (consec) {
            candidates.push({
              cards: sub,
              isVertical: true,
              description: `Phỏm dọc (${sub.map(c => c.sym + c.suitIcon).join(" ")})`
            });
          }
        }
      }

      // Ace High: Q-K-A
      const hasA = grp.find(c => c.rank === 14);
      const hasK = grp.find(c => c.rank === 13);
      const hasQ = grp.find(c => c.rank === 12);
      if (hasA && hasK && hasQ) {
        candidates.push({
          cards: [hasQ, hasK, hasA],
          isVertical: true,
          description: `Phỏm dọc (${hasQ.sym}${hasQ.suitIcon} ${hasK.sym}${hasK.suitIcon} ${hasA.sym}${hasA.suitIcon})`
        });
        const hasJ = grp.find(c => c.rank === 11);
        if (hasJ) {
          candidates.push({
            cards: [hasJ, hasQ, hasK, hasA],
            isVertical: true,
            description: `Phỏm dọc (${hasJ.sym}${hasJ.suitIcon} ${hasQ.sym}${hasQ.suitIcon} ${hasK.sym}${hasK.suitIcon} ${hasA.sym}${hasA.suitIcon})`
          });
        }
      }
    }

    return candidates;
  }

  static rankPlayers(players) {
    const evaluated = players.map((p, idx) => ({
      index: idx,
      name: p.name,
      result: this.evaluate(p.cards)
    }));

    evaluated.sort((a, b) => {
      // 1. Ù Tròn is supreme
      if (a.result.isUTron !== b.result.isUTron) return a.result.isUTron ? -1 : 1;
      // 2. Ù or Ù Khan
      if (a.result.isU !== b.result.isU) return a.result.isU ? -1 : 1;
      // 3. Móm loses to non-móm
      if (a.result.isMom !== b.result.isMom) return a.result.isMom ? 1 : -1;
      // 4. Deadwood points (lower is better)
      if (a.result.deadwoodScore !== b.result.deadwoodScore) return a.result.deadwoodScore - b.result.deadwoodScore;
      return a.index - b.index;
    });

    const n = evaluated.length;
    const ranks = new Array(n).fill(1);
    let currentRank = 1;
    for (let i = 0; i < n; i++) {
      if (i > 0) {
        const prev = evaluated[i - 1];
        const curr = evaluated[i];
        const isSame = (prev.result.isUTron === curr.result.isUTron) &&
                       (prev.result.isU === curr.result.isU) &&
                       (prev.result.isMom === curr.result.isMom) &&
                       (prev.result.deadwoodScore === curr.result.deadwoodScore);
        if (!isSame) {
          currentRank = i + 1;
        }
      }
      ranks[i] = currentRank;
    }

    const hasU = evaluated.some(e => e.result.isU);
    const deltas = new Array(n).fill(0);

    if (hasU) {
      const uWinners = evaluated.filter(e => e.result.isU);
      const isAnyUTron = uWinners.some(e => e.result.isUTron);
      const chipPenalty = isAnyUTron ? 12 : 6;

      let totalPool = 0;
      for (let i = 0; i < n; i++) {
        if (!evaluated[i].result.isU) {
          deltas[i] = -chipPenalty;
          totalPool += chipPenalty;
        }
      }

      const uCount = uWinners.length;
      if (uCount > 0) {
        const winPerU = Math.floor(totalPool / uCount);
        let remainder = totalPool % uCount;
        for (let i = 0; i < n; i++) {
          if (evaluated[i].result.isU) {
            deltas[i] = winPerU + (remainder > 0 ? 1 : 0);
            if (remainder > 0) remainder--;
          }
        }
      }
    } else {
      // Southern scoring: Nhì -1, Ba -2, Bét -3, Móm -4
      let totalPool = 0;
      for (let i = 0; i < n; i++) {
        if (ranks[i] > 1) {
          let penalty = 0;
          if (evaluated[i].result.isMom) {
            penalty = 4;
          } else {
            const rankPos = ranks[i];
            if (rankPos === 2) penalty = 1;
            else if (rankPos === 3) penalty = 2;
            else penalty = 3;
          }
          deltas[i] = -penalty;
          totalPool += penalty;
        }
      }

      const rank1Count = ranks.filter(r => r === 1).length;
      if (rank1Count > 0) {
        const winPerWinner = Math.floor(totalPool / rank1Count);
        let remainder = totalPool % rank1Count;
        for (let i = 0; i < n; i++) {
          if (ranks[i] === 1) {
            deltas[i] = winPerWinner + (remainder > 0 ? 1 : 0);
            if (remainder > 0) remainder--;
          }
        }
      }
    }

    return evaluated.map((item, pos) => ({
      index: item.index,
      name: item.name,
      result: item.result,
      rank: ranks[pos],
      scoreDelta: deltas[pos]
    }));
  }
}

// MARK: - State & App Controller

class AppController {

  constructor() {
    this.currentGameType = 'binh13';
    this.suitPreset = 'north';
    this.playerCount = 3;
    this.inputMode = 'roundRobin'; // 'roundRobin' or 'manual'
    this.roundRobinPointer = 0;
    this.selectedPlayerIndex = 0;
    this.isSelectingCommunity = false;
    this.phomTenCardPlayerIndex = null;
    this.lastPhomWinnerIndex = null;

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

  targetCards(playerIndex) {
    const cfg = GAME_CONFIGS[this.currentGameType];
    if (this.currentGameType === 'phom9') {
      return (this.phomTenCardPlayerIndex === playerIndex) ? 10 : 9;
    }
    return cfg.cardsPerPlayer;
  }

  togglePhomTenCard(index) {
    if (this.currentGameType !== 'phom9') return;
    if (this.phomTenCardPlayerIndex === index) {
      if (this.players[index].cards.length > 9) {
        const removed = this.players[index].cards.pop();
        this.actionHistory = this.actionHistory.filter(h => h.cardId !== removed.id);
      }
      this.phomTenCardPlayerIndex = null;
    } else {
      if (this.phomTenCardPlayerIndex !== null && this.players[this.phomTenCardPlayerIndex]?.cards.length > 9) {
        const removed = this.players[this.phomTenCardPlayerIndex].cards.pop();
        this.actionHistory = this.actionHistory.filter(h => h.cardId !== removed.id);
      }
      this.phomTenCardPlayerIndex = index;
    }
    this.clearResultsState();
    this.renderDeck();
    this.renderPlayers();
    this.updateUI();
  }

  startNewRound() {
    this.clearResultsState();
    this.players.forEach(p => { p.cards = []; });
    this.communityCards = [];
    this.actionHistory = [];
    this.isSelectingCommunity = false;

    if (this.currentGameType === 'phom9' && this.lastPhomWinnerIndex !== null && this.lastPhomWinnerIndex < this.players.length) {
      this.phomTenCardPlayerIndex = this.lastPhomWinnerIndex;
      this.roundRobinPointer = this.lastPhomWinnerIndex;
      this.selectedPlayerIndex = this.lastPhomWinnerIndex;
    } else {
      this.phomTenCardPlayerIndex = null;
      this.roundRobinPointer = 0;
      this.selectedPlayerIndex = 0;
    }

    this.renderDeck();
    this.renderPlayers();
    this.updateUI();
  }

  initPlayers() {
    this.phomTenCardPlayerIndex = null;
    this.lastPhomWinnerIndex = null;
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
        this.calculate();
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
        } else if (this.currentGameType === 'phom9' && this.phomTenCardPlayerIndex === null && curr && curr.cards.length === 9) {
          this.phomTenCardPlayerIndex = this.selectedPlayerIndex;
          curr.cards.push(card);
          this.actionHistory.push({ cardId: card.id, target: this.selectedPlayerIndex });
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
    if (this.currentGameType === 'phom9') {
      const allValid = this.players.every(p => p.cards.length >= 9 && p.cards.length <= 10);
      const tenCount = this.players.filter(p => p.cards.length === 10).length;
      return allValid && tenCount <= 1;
    }
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
    this.phomTenCardPlayerIndex = null;
    this.lastPhomWinnerIndex = null;
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

      let phomBtnHtml = '';
      if (this.currentGameType === 'phom9' && !hasResult) {
        const is10 = target === 10;
        phomBtnHtml = `<button type="button" class="btn-phom-10" style="font-size: 10px; font-weight: bold; padding: 2px 6px; margin-left: 6px; border-radius: 4px; border: 1px solid ${is10 ? '#f59e0b' : '#8e8e93'}; background: ${is10 ? '#f59e0b' : 'transparent'}; color: ${is10 ? '#fff' : 'inherit'}; cursor: pointer;">${is10 ? '🎴 10 lá' : '9 lá'}</button>`;
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
          ${phomBtnHtml}
          ${rankBadgeHtml ? rankBadgeHtml : (isActive ? `<span class="p-tag">${this.inputMode === 'roundRobin' ? '▶ Lượt nhận' : '▶ Đang chọn'}</span>` : '')}
        </div>
        ${counterHtml}
      `;
      
      const nameBox = header.querySelector('.p-name-container');
      nameBox.addEventListener('click', (e) => {
        e.stopPropagation();
        this.renamePlayer(idx);
      });

      const btnP10 = header.querySelector('.btn-phom-10');
      if (btnP10) {
        btnP10.addEventListener('click', (e) => {
          e.stopPropagation();
          this.togglePhomTenCard(idx);
        });
      }
      
      mat.appendChild(header);

      const cardsContainer = document.createElement('div');
      cardsContainer.className = 'hand-cards-container';

      const overlapWrap = document.createElement('div');
      overlapWrap.className = 'card-overlap-wrapper';

      p.cards.forEach(c => {
        const mini = this.createMiniCard(c);
        overlapWrap.appendChild(mini);
      });

      const missing = Math.max(0, target - p.cards.length);
      // Show up to 6 placeholders to avoid taking too much horizontal space
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
      mat.appendChild(cardsContainer);
      list.appendChild(mat);
    });
  }

  createMiniCard(card) {
    const mini = document.createElement('div');
    mini.className = `mini-card ${card.isRed ? 'red' : 'black'}`;
    mini.innerHTML = `
      <span class="mini-card-rank">${card.sym}</span>
      <span class="mini-card-suit">${card.suitIcon}</span>
    `;
    mini.title = `${card.sym} ${card.suitName} (Bấm để gỡ)`;
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
      btnCalc.className = 'btn-showdown-compact btn-new-round';
      btnCalc.innerHTML = `<span>🔄 VÁN MỚI</span>`;
    } else {
      btnCalc.className = 'btn-showdown-compact';
      btnCalc.disabled = !isReady;
      btnCalc.innerHTML = isReady ? `<span>👑 SO BÀI</span>` : `<span>👑 Chưa đủ lá</span>`;
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
      case 'phom9':
        this.calcPhom();
        break;
      case 'lieng3':
        this.calcLieng();
        break;
      case 'xiDach2':
        this.calcXiDach();
        break;
      case 'texasHoldem':
        this.calcHoldem();
        break;
      case 'binh13':
        this.calcBinh13();
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
    const evaluated = this.players.map((p, idx) => {
      const score = LiengEvaluator.evaluate(p.cards, this.suitPreset);
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

  calcPhom() {
    const inputList = this.players.map((p, idx) => ({
      index: idx,
      name: p.name,
      cards: p.cards
    }));
    const ranked = PhomEvaluator.rankPlayers(inputList);

    ranked.forEach(item => {
      const p = this.players[item.index];
      p.rankOrder = item.rank;
      p.score = item.scoreDelta;
      if (item.result.isUTron) {
        p.resultTitle = "🎉 Ù TRÒN 10 LÁ";
      } else if (item.result.isUKhan) {
        p.resultTitle = "🎉 Ù KHAN";
      } else if (item.result.isU) {
        p.resultTitle = "🎉 Ù (0 điểm rác)";
      } else if (item.result.isMom) {
        p.resultTitle = `💀 Móm / Cháy (${item.result.deadwoodScore}đ)`;
      } else {
        p.resultTitle = `${item.result.deadwoodScore} điểm rác (${item.result.phoms.length} phỏm)`;
      }
      p.resultDetail = item.result.summary;
    });

    const winners = this.players.filter(p => p.rankOrder === 1);
    if (winners.length > 0) {
      const wIdx = this.players.findIndex(p => p.rankOrder === 1);
      if (wIdx !== -1) {
        this.lastPhomWinnerIndex = wIdx;
      }
    }
    if (winners.length > 1) {
      document.getElementById('bannerWinner').innerHTML = `
        👑 <strong>Đồng Hạng 1</strong>: ${winners.map(w => w.name).join(', ')} (Hòa điểm với ${winners[0].resultTitle})!
      `;
    } else {
      const winner = winners[0];
      document.getElementById('bannerWinner').innerHTML = `
        🏆 <strong>${winner ? winner.name : '—'}</strong> Thắng ván Phỏm với ${winner ? winner.resultTitle : ''}!
      `;
    }
    document.getElementById('matrixSection').style.display = 'none';
  }

  calcBinh13() {
    const arrangements = this.players.map(p => {
      const arr = Binh13Evaluator.autoArrange(p.cards);
      p.isLung = arr.isLung;
      p.score = 0;
      if (arr.instantWin) {
        p.resultTitle = arr.instantWin.name;
        p.resultDetail = "Tự động Thắng Trắng mà không cần so từng chi!";
      } else if (arr.isLung) {
        p.resultTitle = "⚠️ BỊ LỦNG (Thua phạt x2)";
        p.resultDetail = "Chi dưới yếu hơn chi giữa hoặc chi trên!";
      } else {
        p.resultTitle = "Đã xếp 3 chi tối ưu";
        p.resultDetail = `Chi 1 (3 lá): ${arr.frontScore.desc}\nChi 2 (5 lá): ${arr.middleScore.desc}\nChi 3 (5 lá): ${arr.backScore.desc}`;
      }
      return arr;
    });

    // Matrix
    const N = this.players.length;
    const matrix = Array.from({ length: N }, () => Array(N).fill('—'));

    for (let i = 0; i < N; i++) {
      for (let j = i + 1; j < N; j++) {
        const match = Binh13Evaluator.compareMatch(arrangements[i], arrangements[j]);
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

    // Render Matrix Table
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

  calcBinh9() {
    this.calcBinh13();
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

    document.getElementById('modalSettings').style.display = 'flex';
  }

  closeSettings() {
    document.getElementById('modalSettings').style.display = 'none';
  }

  saveSettings() {
    const selected = document.querySelector('input[name="suitPreset"]:checked');
    if (selected) {
      this.suitPreset = selected.value;
      // Re-calculate and re-render immediately if cards are present!
      if (this.isReady()) {
        this.calculate();
      } else {
        this.renderPlayers();
        this.updateUI();
      }
    }
    this.closeSettings();
  }
}

// Instantiate on load
window.addEventListener('DOMContentLoaded', () => {
  window.app = new AppController();
});
