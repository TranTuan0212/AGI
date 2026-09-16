const fs = require('fs');
const vm = require('vm');

// We will read app.js content and evaluate the classes in a sandbox
const appCode = fs.readFileSync('e:/appgame/preview/app.js', 'utf8');

// Strip out window / document DOM stuff for node testing
const logicCode = appCode.split('// MARK: - State & App Controller')[0];

vm.runInThisContext(logicCode);



let passed = 0;
let total = 0;

function assert(condition, message) {
  total++;
  if (condition) {
    passed++;
    console.log(`✅ [PASS] ${message}`);
  } else {
    console.error(`❌ [FAIL] ${message}`);
  }
}

console.log('=== BẮT ĐẦU KIỂM THỬ THUẬT TOÁN ENGINE ===\n');

// 1. Test Poker Wheel Straight (A-2-3-4-5) vs (2-3-4-5-6)
{
  const wheel = [
    { rank: 14, suit: 'hearts' },
    { rank: 2, suit: 'diamonds' },
    { rank: 3, suit: 'clubs' },
    { rank: 4, suit: 'spades' },
    { rank: 5, suit: 'hearts' }
  ];
  const straight6 = [
    { rank: 6, suit: 'hearts' },
    { rank: 2, suit: 'diamonds' },
    { rank: 3, suit: 'clubs' },
    { rank: 4, suit: 'spades' },
    { rank: 5, suit: 'spades' }
  ];
  const sWheel = PokerEvaluator.evaluate5(wheel);
  const s6 = PokerEvaluator.evaluate5(straight6);

  assert(sWheel.type === 5, 'Nhận diện đúng Sảnh bánh xe (type=5 Straight)');
  assert(sWheel.tieBreakers[0] === 5, 'Sảnh bánh xe có đỉnh là 5 (tieBreakers[0] == 5)');
  assert(PokerEvaluator.compareScores(s6, sWheel) > 0, 'Sảnh 2-3-4-5-6 (đỉnh 6) thắng Sảnh bánh xe A-2-3-4-5 (đỉnh 5)');
}

// 2. Test Poker Kicker (AA88K vs AA88Q)
{
  const h1 = [
    { rank: 14, suit: 'hearts' }, { rank: 14, suit: 'spades' },
    { rank: 8, suit: 'diamonds' }, { rank: 8, suit: 'clubs' },
    { rank: 13, suit: 'hearts' } // King kicker
  ];
  const h2 = [
    { rank: 14, suit: 'diamonds' }, { rank: 14, suit: 'clubs' },
    { rank: 8, suit: 'spades' }, { rank: 8, suit: 'hearts' },
    { rank: 12, suit: 'spades' } // Queen kicker
  ];
  const score1 = PokerEvaluator.evaluate5(h1);
  const score2 = PokerEvaluator.evaluate5(h2);
  assert(PokerEvaluator.compareScores(score1, score2) > 0, 'Hai đôi AA88K thắng AA88Q nhờ Kicker King > Queen');
}

// 3. Test Omaha 2+3 rule (4 hearts in hand, 1 heart on board -> NOT Flush)
{
  const hole = [
    { rank: 14, suit: 'hearts' },
    { rank: 13, suit: 'hearts' },
    { rank: 10, suit: 'hearts' },
    { rank: 9, suit: 'hearts' }
  ];
  const board = [
    { rank: 2, suit: 'hearts' },
    { rank: 3, suit: 'spades' },
    { rank: 4, suit: 'clubs' },
    { rank: 7, suit: 'diamonds' },
    { rank: 8, suit: 'spades' }
  ];
  // Player can only pick 2 hearts from hand, and from board there is only 1 heart! Total hearts in 5-card = 2+1=3 -> Can't make flush!
  const hole2Combos = getCombinations(hole, 2);
  const board3Combos = getCombinations(board, 3);
  let best = null;
  for (const h of hole2Combos) {
    for (const b of board3Combos) {
      const score = PokerEvaluator.evaluate5([...h, ...b]);
      if (!best || PokerEvaluator.compareScores(score, best) > 0) best = score;
    }
  }
  assert(best.type !== 6, 'Omaha 4 lá cơ trên tay + 1 lá cơ trên bàn KHÔNG được Thùng (Flush)');
}

// 4. Test Liêng (Sáp > Liêng > Ba Tây > Điểm mod 10 theo DataGroupingUI)
{
  const sap = [{ rank: 7, suit: 'hearts' }, { rank: 7, suit: 'spades' }, { rank: 7, suit: 'diamonds' }];
  const lieng = [{ rank: 12, suit: 'hearts' }, { rank: 13, suit: 'diamonds' }, { rank: 14, suit: 'clubs' }]; // Q-K-A
  const di = [{ rank: 11, suit: 'hearts' }, { rank: 12, suit: 'spades' }, { rank: 11, suit: 'diamonds' }]; // J-Q-J
  const diem9 = [{ rank: 5, suit: 'hearts' }, { rank: 4, suit: 'spades' }, { rank: 10, suit: 'diamonds' }]; // 9 điểm

  const sSap = LiengEvaluator.evaluate(sap);
  const sLieng = LiengEvaluator.evaluate(lieng);
  const sDi = LiengEvaluator.evaluate(di);
  const sDiem9 = LiengEvaluator.evaluate(diem9);

  assert(sSap.score === 10007 && sSap.typeName === 'Sáp', 'Nhận diện Sáp 7 (10.007 điểm)');
  assert(sLieng.score === 5014 && sLieng.typeName === 'Liêng', 'Nhận diện Liêng Q-K-A (5.014 điểm)');
  assert(sDi.score === 1000 && sDi.typeName === 'Ba Tây', 'Nhận diện Ba Tây J-Q-J (1.000 điểm)');
  assert(sDiem9.score === 900 && sDiem9.typeName === 'Điểm Thường', 'Nhận diện Điểm (9 điểm = 900 điểm)');

  assert(LiengEvaluator.compare(sSap, sLieng) > 0, 'Sáp thắng Liêng');
  assert(LiengEvaluator.compare(sLieng, sDi) > 0, 'Liêng thắng Ba Tây');
  assert(LiengEvaluator.compare(sDi, sDiem9) > 0, 'Ba Tây thắng 9 điểm');
}

// 5. Test Binh 13 Thắng Trắng & Precedence
{
  // Sảnh rồng: 2 to A
  const dragon = Array.from({ length: 13 }, (_, i) => ({ rank: i + 2, suit: i % 2 === 0 ? 'hearts' : 'spades' }));
  const instant = Binh13Evaluator.checkInstantWin(dragon);
  assert(instant && instant.name.includes('Sảnh Rồng'), 'Nhận diện Sảnh Rồng 2->A');
  assert(instant.bonus === 12, 'Sảnh Rồng được ăn 12 chi/nhà');

  // Lục phé bôn (6 pairs + 1 single)
  const lucPhe = [
    { rank: 2, suit: 'hearts' }, { rank: 2, suit: 'spades' },
    { rank: 4, suit: 'hearts' }, { rank: 4, suit: 'spades' },
    { rank: 6, suit: 'hearts' }, { rank: 6, suit: 'spades' },
    { rank: 8, suit: 'hearts' }, { rank: 8, suit: 'spades' },
    { rank: 10, suit: 'hearts' }, { rank: 10, suit: 'spades' },
    { rank: 12, suit: 'hearts' }, { rank: 12, suit: 'spades' },
    { rank: 14, suit: 'hearts' } // single Ace
  ];
  const instantLuc = Binh13Evaluator.checkInstantWin(lucPhe);
  assert(instantLuc && instantLuc.name.includes('Lục Phé Bôn'), 'Nhận diện Lục Phé Bôn (6 đôi)');
  assert(instantLuc.bonus === 6, 'Lục Phé Bôn được ăn 6 chi/nhà');
}

// 6. Test Binh 13 Auto-Arrange & Bắt Sập Hầm x2
{
  // Player A has a monster hand: Full house + Flush + High Pair
  const handA = [
    { rank: 14, suit: 'hearts' }, { rank: 14, suit: 'diamonds' }, { rank: 14, suit: 'clubs' }, { rank: 13, suit: 'hearts' }, { rank: 13, suit: 'diamonds' }, // Full house A bu K
    { rank: 12, suit: 'spades' }, { rank: 10, suit: 'spades' }, { rank: 8, suit: 'spades' }, { rank: 6, suit: 'spades' }, { rank: 4, suit: 'spades' }, // Flush Spades
    { rank: 11, suit: 'hearts' }, { rank: 11, suit: 'diamonds' }, { rank: 9, suit: 'clubs' } // Pair of Jacks
  ];

  // Player B has a weaker normal hand (not 6 pairs): One pair + High cards
  const handB = [
    { rank: 10, suit: 'hearts' }, { rank: 10, suit: 'diamonds' }, { rank: 9, suit: 'hearts' }, { rank: 8, suit: 'diamonds' }, { rank: 2, suit: 'clubs' }, // One pair 10
    { rank: 7, suit: 'hearts' }, { rank: 6, suit: 'diamonds' }, { rank: 5, suit: 'clubs' }, { rank: 4, suit: 'clubs' }, { rank: 3, suit: 'diamonds' }, // High card 7
    { rank: 7, suit: 'diamonds' }, { rank: 5, suit: 'diamonds' }, { rank: 2, suit: 'hearts' } // High card 7
  ];


  const arrA = Binh13Evaluator.autoArrange(handA);
  const arrB = Binh13Evaluator.autoArrange(handB);

  console.log('Player A chi 1 (front):', arrA.frontScore.desc);
  console.log('Player A chi 2 (middle):', arrA.middleScore.desc);
  console.log('Player A chi 3 (back):', arrA.backScore.desc);

  console.log('Player B chi 1 (front):', arrB.frontScore.desc);
  console.log('Player B chi 2 (middle):', arrB.middleScore.desc);
  console.log('Player B chi 3 (back):', arrB.backScore.desc);

  const match = Binh13Evaluator.compareMatch(arrA, arrB);
  console.log('Match result:', match);

  assert(match.scoreA >= 6, `Player A thắng cả 3 chi và bắt sập hầm Player B (${match.scoreA} chi)`);
  assert(match.detail.includes('sập hầm'), 'Có thông báo bắt sập hầm x2 chi tiết');
}

// 7. Test Ba Cái Thùng (Cần tìm cách xếp 3 chi đều là Thùng)
{
  // 13 cards with: Chi 3 (5 Spades: A, K, Q, J, 9), Chi 2 (5 Hearts: A, K, 10, 8, 4), Chi 1 (3 Diamonds: K, Q, 10)
  const threeFlushHand = [
    { rank: 14, suit: 'spades' }, { rank: 13, suit: 'spades' }, { rank: 12, suit: 'spades' }, { rank: 11, suit: 'spades' }, { rank: 9, suit: 'spades' },
    { rank: 14, suit: 'hearts' }, { rank: 13, suit: 'hearts' }, { rank: 10, suit: 'hearts' }, { rank: 8, suit: 'hearts' }, { rank: 4, suit: 'hearts' },
    { rank: 13, suit: 'diamonds' }, { rank: 12, suit: 'diamonds' }, { rank: 10, suit: 'diamonds' }
  ];

  const arrThreeFlush = Binh13Evaluator.autoArrange(threeFlushHand);
  assert(arrThreeFlush.instantWin && arrThreeFlush.instantWin.name.includes('Ba Cái Thùng'), 'Nhận diện đúng Thắng Trắng Ba Cái Thùng sau khi xếp chi hợp lệ');
  assert(arrThreeFlush.instantWin.bonus === 3, 'Ba Cái Thùng ăn 3 chi');
}

// 8. Test Thắng Trắng vs Bài thường (thắng tuyệt đối không xét chi)
{
  const dragon = Array.from({ length: 13 }, (_, i) => ({ rank: i + 2, suit: i % 2 === 0 ? 'hearts' : 'spades' }));
  const arrDragon = Binh13Evaluator.autoArrange(dragon);
  
  // Normal hand with monster quad in middle
  const normalHand = [
    { rank: 14, suit: 'hearts' }, { rank: 14, suit: 'diamonds' }, { rank: 14, suit: 'clubs' }, { rank: 14, suit: 'spades' }, { rank: 13, suit: 'hearts' },
    { rank: 12, suit: 'hearts' }, { rank: 12, suit: 'diamonds' }, { rank: 10, suit: 'clubs' }, { rank: 8, suit: 'spades' }, { rank: 6, suit: 'hearts' },
    { rank: 5, suit: 'hearts' }, { rank: 4, suit: 'diamonds' }, { rank: 2, suit: 'clubs' }
  ];
  const arrNormal = Binh13Evaluator.autoArrange(normalHand);

  const matchRes = Binh13Evaluator.compareMatch(arrDragon, arrNormal);
  assert(matchRes.scoreA === 12, 'Sảnh Rồng thắng tuyệt đối bài thường ăn trọn 12 chi mà không xét chi của bài thường');
}

// 9. Test Lủng đền toàn bộ hàng của đối thủ (-6 - inherent bonus)
{
  const lungHand = {
    isLung: true,
    instantWin: null,
    frontScore: { type: 1, primary: 2, kickers: [] },
    middleScore: { type: 1, tieBreakers: [2] },
    backScore: { type: 1, tieBreakers: [2] }
  };
  
  // Opponent has Quad in Chi 2 (+8 chi) and Sám in Chi 1 (+3 chi) -> Inherent bonus = 11 chi!
  const opponentWithHangs = {
    isLung: false,
    instantWin: null,
    frontScore: { type: 3, primary: 14, kickers: [], desc: 'Sám cô A' },
    middleScore: { type: 8, tieBreakers: [13, 2], desc: 'Tứ quý K' }, // Quad chi 2 (+8)
    backScore: { type: 7, tieBreakers: [12, 10], desc: 'Cù lũ Q' }
  };

  const matchLung = Binh13Evaluator.compareMatch(lungHand, opponentWithHangs);
  assert(matchLung.scoreA === -17, `Người bị Lủng bị phạt -6 chi cơ bản + đền 11 chi hàng = -17 chi (Thực tế: ${matchLung.scoreA} chi)`);
}

// 10. Test Đè Hàng: Chỉ kích hoạt khi CÙNG loại hàng
{
  // A has Quad 9 in Chi 2 (+8 chi standard, if đè quad 8 -> +16 chi)
  const aQuad = {
    isLung: false, instantWin: null,
    frontScore: { type: 1, primary: 5, kickers: [] },
    middleScore: { type: 8, tieBreakers: [9, 2] }, // Quad 9
    backScore: { type: 7, tieBreakers: [14, 10] }
  };
  // B has Quad 8 in Chi 2
  const bQuad = {
    isLung: false, instantWin: null,
    frontScore: { type: 1, primary: 4, kickers: [] },
    middleScore: { type: 8, tieBreakers: [8, 2] }, // Quad 8
    backScore: { type: 7, tieBreakers: [13, 10] }
  };
  const matchQuad = Binh13Evaluator.compareMatch(aQuad, bQuad);
  // A thắng cả 3 chi -> Sập hầm = 6 chi cơ bản + 16 chi đè hàng Tứ Quý = 22 chi!
  assert(matchQuad.scoreA === 22, `Cùng Tứ Quý chi 2 và thắng cả 3 chi: Sập hầm 6 chi + Đè hàng nhân đôi 16 chi = 22 chi (Thực tế: ${matchQuad.scoreA} chi)`);
}

// 11. Test Phỏm (Tá Lả) Evaluator
{
  // Case 1: Ù 9 lá (3 Phỏm: 3-3-3 ngang, 7-8-9 bích, J-Q-K cơ)
  const uCards = [
    { id: '3h', rank: 3, sym: '3', suit: 'hearts', suitIcon: '♥' },
    { id: '3d', rank: 3, sym: '3', suit: 'diamonds', suitIcon: '♦' },
    { id: '3s', rank: 3, sym: '3', suit: 'spades', suitIcon: '♠' },
    { id: '7s', rank: 7, sym: '7', suit: 'spades', suitIcon: '♠' },
    { id: '8s', rank: 8, sym: '8', suit: 'spades', suitIcon: '♠' },
    { id: '9s', rank: 9, sym: '9', suit: 'spades', suitIcon: '♠' },
    { id: 'Jh', rank: 11, sym: 'J', suit: 'hearts', suitIcon: '♥' },
    { id: 'Qh', rank: 12, sym: 'Q', suit: 'hearts', suitIcon: '♥' },
    { id: 'Kh', rank: 13, sym: 'K', suit: 'hearts', suitIcon: '♥' }
  ];
  const uResult = PhomEvaluator.evaluate(uCards);
  assert(uResult.isU === true, `Phỏm: Nhận diện chính xác Ù 9 lá (3 phỏm)`);
  assert(uResult.deadwoodScore === 0, `Phỏm: Điểm rác của Ù phải bằng 0 (Thực tế: ${uResult.deadwoodScore})`);
  assert(uResult.phoms.length === 3, `Phỏm: Đủ 3 phỏm tạo thành Ù (Thực tế: ${uResult.phoms.length})`);

  // Case 2: 1 Phỏm (7-7-7) + 6 lá rác (A=1, 2=2, 4=4, 5=5, J=11, K=13) -> Tổng rác = 36
  const onePhomCards = [
    { id: '7h', rank: 7, sym: '7', suit: 'hearts', suitIcon: '♥' },
    { id: '7d', rank: 7, sym: '7', suit: 'diamonds', suitIcon: '♦' },
    { id: '7s', rank: 7, sym: '7', suit: 'spades', suitIcon: '♠' },
    { id: 'Ac', rank: 14, sym: 'A', suit: 'clubs', suitIcon: '♣' }, // A = 1
    { id: '2c', rank: 2, sym: '2', suit: 'clubs', suitIcon: '♣' },  // 2
    { id: '4h', rank: 4, sym: '4', suit: 'hearts', suitIcon: '♥' }, // 4
    { id: '5d', rank: 5, sym: '5', suit: 'diamonds', suitIcon: '♦' }, // 5
    { id: 'Js', rank: 11, sym: 'J', suit: 'spades', suitIcon: '♠' }, // 11
    { id: 'Kd', rank: 13, sym: 'K', suit: 'diamonds', suitIcon: '♦' } // 13
  ];
  const onePhomResult = PhomEvaluator.evaluate(onePhomCards);
  assert(onePhomResult.isU === false, `Phỏm: Không bị nhận nhầm thành Ù`);
  assert(onePhomResult.isMom === false, `Phỏm: Có 1 phỏm nên không bị Móm`);
  assert(onePhomResult.deadwoodScore === 36, `Phỏm: Tính điểm rác chính xác 1+2+4+5+11+13 = 36 (Thực tế: ${onePhomResult.deadwoodScore})`);

  // Case 3: Móm (Không có bất kỳ phỏm nào)
  const momCards = [
    { id: '2h', rank: 2, sym: '2', suit: 'hearts', suitIcon: '♥' },
    { id: '4d', rank: 4, sym: '4', suit: 'diamonds', suitIcon: '♦' },
    { id: '6s', rank: 6, sym: '6', suit: 'spades', suitIcon: '♠' },
    { id: '8c', rank: 8, sym: '8', suit: 'clubs', suitIcon: '♣' },
    { id: '10h', rank: 10, sym: '10', suit: 'hearts', suitIcon: '♥' },
    { id: 'Qd', rank: 12, sym: 'Q', suit: 'diamonds', suitIcon: '♦' },
    { id: 'As', rank: 14, sym: 'A', suit: 'spades', suitIcon: '♠' },
    { id: '3c', rank: 3, sym: '3', suit: 'clubs', suitIcon: '♣' },
    { id: '9h', rank: 9, sym: '9', suit: 'hearts', suitIcon: '♥' }
  ];
  const momResult = PhomEvaluator.evaluate(momCards);
  assert(momResult.isMom === true, `Phỏm: Nhận diện chính xác Móm (Cháy bài)`);
  assert(momResult.phoms.length === 0, `Phỏm: Móm có 0 phỏm`);

  // Case 4: Xếp hạng 3 người chơi: Player A (Ù) vs Player B (1 phỏm, 36 điểm rác) vs Player C (Móm)
  const ranked = PhomEvaluator.rankPlayers([
    { name: 'Player B', cards: onePhomCards },
    { name: 'Player C', cards: momCards },
    { name: 'Player A', cards: uCards }
  ]);
  assert(ranked[0].name === 'Player A' && ranked[0].rank === 1, `Phỏm: Người Ù đứng Hạng 1`);
  assert(ranked[1].name === 'Player B' && ranked[1].rank === 2, `Phỏm: Người có phỏm đứng Hạng 2`);
  assert(ranked[2].name === 'Player C' && ranked[2].rank === 3, `Phỏm: Người Móm đứng Chót bảng (Hạng 3)`);
  assert(ranked[0].scoreDelta === 12, `Phỏm: Người Ù ăn mỗi nhà 6 chi (Tổng +12 chi)`);

  // Case 5: Phỏm Đồng điểm: 2 người cùng 36 điểm rác -> Cả 2 cùng Đồng Hạng 1
  const onePhomCards2 = [
    { id: '8h', rank: 8, sym: '8', suit: 'hearts', suitIcon: '♥' },
    { id: '8d', rank: 8, sym: '8', suit: 'diamonds', suitIcon: '♦' },
    { id: '8s', rank: 8, sym: '8', suit: 'spades', suitIcon: '♠' },
    { id: 'Ah', rank: 14, sym: 'A', suit: 'hearts', suitIcon: '♥' }, // 1
    { id: '2h', rank: 2, sym: '2', suit: 'hearts', suitIcon: '♥' },  // 2
    { id: '4d', rank: 4, sym: '4', suit: 'diamonds', suitIcon: '♦' }, // 4
    { id: '5s', rank: 5, sym: '5', suit: 'spades', suitIcon: '♠' }, // 5
    { id: 'Jc', rank: 11, sym: 'J', suit: 'clubs', suitIcon: '♣' }, // 11
    { id: 'Kc', rank: 13, sym: 'K', suit: 'clubs', suitIcon: '♣' } // 13 -> sum rác = 36
  ];
  const rankedTie = PhomEvaluator.rankPlayers([
    { name: 'Player A', cards: onePhomCards },
    { name: 'Player B', cards: onePhomCards2 },
    { name: 'Player C', cards: momCards }
  ]);
  assert(rankedTie[0].rank === 1 && rankedTie[1].rank === 1, `Phỏm: Cả 2 người bằng điểm rác đều nhận Hạng 1 (Đồng Hạng 1)`);
  assert(rankedTie[2].rank === 3, `Phỏm: Người Móm xếp sau đứng Hạng 3`);
  assert(rankedTie[0].scoreDelta > 0 && rankedTie[1].scoreDelta > 0, `Phỏm: 2 người Đồng Hạng 1 cùng được chia phần tiền thắng`);
  assert(rankedTie[0].scoreDelta + rankedTie[1].scoreDelta + rankedTie[2].scoreDelta === 0, `Phỏm: Tổng điểm thắng thua toàn bàn bảo toàn Zero-Sum (= 0)`);
}

// 12. Test Xì Dách (2 Lá / Xì Lát) Evaluator theo DataGroupingUI
{
  // 12.1 Xì Bàng (A-A) -> score = 5021
  const xiBang = [
    { rank: 14, suit: 'hearts' },
    { rank: 14, suit: 'spades' }
  ];
  const sXiBang = XiDachEvaluator.evaluate(xiBang);
  assert(sXiBang.score === 5021 && sXiBang.title.includes('Xì Bàng'), 'Xì Dách: Nhận diện đúng Xì Bàng (A-A, 5.021 điểm)');

  // 12.2 Xì Dách (A + 10/J/Q/K) -> score = 4000
  const xiDach = [
    { rank: 14, suit: 'diamonds' },
    { rank: 13, suit: 'clubs' } // A + K
  ];
  const sXiDach = XiDachEvaluator.evaluate(xiDach);
  assert(sXiDach.score === 4000 && sXiDach.title.includes('Xì Dách'), 'Xì Dách: Nhận diện đúng Xì Dách (A + K, 4.000 điểm)');

  // 12.3 Ngũ Linh (5 lá <= 21đ) -> 3000 + (21 - total)
  const nguLinh18 = [
    { rank: 2, suit: 'hearts' },
    { rank: 3, suit: 'spades' },
    { rank: 4, suit: 'diamonds' },
    { rank: 4, suit: 'clubs' },
    { rank: 5, suit: 'hearts' } // Total = 18
  ];
  const nguLinh19 = [
    { rank: 2, suit: 'hearts' },
    { rank: 3, suit: 'spades' },
    { rank: 4, suit: 'diamonds' },
    { rank: 4, suit: 'clubs' },
    { rank: 6, suit: 'hearts' } // Total = 19
  ];
  const sNL18 = XiDachEvaluator.evaluate(nguLinh18);
  const sNL19 = XiDachEvaluator.evaluate(nguLinh19);
  assert(sNL18.score === 3003 && sNL18.title.includes('Ngũ Linh'), 'Xì Dách: Nhận diện Ngũ Linh 18đ (3.003 điểm)');
  assert(sNL19.score === 3002 && sNL19.title.includes('Ngũ Linh'), 'Xì Dách: Nhận diện Ngũ Linh 19đ (3.002 điểm)');
  assert(XiDachEvaluator.compare(sNL18, sNL19) > 0, 'Xì Dách: Ngũ Linh điểm nhỏ hơn thắng (18đ thắng 19đ)');

  // 12.4 Đủ Điểm / Đủ Tuổi (16 - 21đ) -> 2000 + total
  const du20 = [
    { rank: 10, suit: 'hearts' },
    { rank: 10, suit: 'spades' } // 20đ
  ];
  const sDu20 = XiDachEvaluator.evaluate(du20);
  assert(sDu20.score === 2020 && sDu20.title.includes('Đủ tuổi'), 'Xì Dách: Nhận diện Đủ tuổi 20đ (2.020 điểm)');

  // 12.5 Non (< 16đ) -> 1000 + total
  const non15 = [
    { rank: 7, suit: 'hearts' },
    { rank: 8, suit: 'spades' } // 15đ
  ];
  const sNon15 = XiDachEvaluator.evaluate(non15);
  assert(sNon15.score === 1015 && sNon15.title.includes('Non'), 'Xì Dách: Nhận diện Non 15đ (1.015 điểm)');

  // 12.6 Quắc (> 21đ) -> max(0, 35 - total)
  const quac23 = [
    { rank: 10, suit: 'hearts' },
    { rank: 10, suit: 'diamonds' },
    { rank: 3, suit: 'clubs' } // 23đ -> 35 - 23 = 12
  ];
  const quac25 = [
    { rank: 10, suit: 'hearts' },
    { rank: 10, suit: 'diamonds' },
    { rank: 5, suit: 'clubs' } // 25đ -> 35 - 25 = 10
  ];
  const sQuac23 = XiDachEvaluator.evaluate(quac23);
  const sQuac25 = XiDachEvaluator.evaluate(quac25);
  assert(sQuac23.score === 12 && sQuac23.title.includes('Quắc'), 'Xì Dách: Nhận diện Quắc 23đ (12 điểm)');
  assert(sQuac25.score === 10 && sQuac25.title.includes('Quắc'), 'Xì Dách: Nhận diện Quắc 25đ (10 điểm)');
  assert(XiDachEvaluator.compare(sQuac23, sQuac25) > 0, 'Xì Dách: Quắc ít điểm hơn thắng (23đ thắng 25đ)');

  // 12.7 So sánh thứ tự các bộ bài
  assert(XiDachEvaluator.compare(sXiBang, sXiDach) > 0, 'Xì Dách: Xì Bàng thắng Xì Dách');
  assert(XiDachEvaluator.compare(sXiDach, sNL18) > 0, 'Xì Dách: Xì Dách thắng Ngũ Linh');
  assert(XiDachEvaluator.compare(sNL18, sDu20) > 0, 'Xì Dách: Ngũ Linh thắng Đủ tuổi');
  assert(XiDachEvaluator.compare(sDu20, sNon15) > 0, 'Xì Dách: Đủ tuổi thắng Non');
  assert(XiDachEvaluator.compare(sNon15, sQuac23) > 0, 'Xì Dách: Non thắng Quắc');
}

console.log(`\n=== TỔNG KẾT: ${passed}/${total} TESTS ĐẠT CHUẨN 100% ===`);




