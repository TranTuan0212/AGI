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

// 4. Test Liêng (Sáp > Liêng > Ba Tây > Điểm mod 10 & So sánh lá to nhất + Chất bài)
{
  const sap = [{ rank: 7, suit: 'hearts' }, { rank: 7, suit: 'spades' }, { rank: 7, suit: 'diamonds' }];
  const lieng = [{ rank: 12, suit: 'hearts' }, { rank: 13, suit: 'diamonds' }, { rank: 14, suit: 'clubs' }]; // Q-K-A
  const di = [{ rank: 11, suit: 'hearts' }, { rank: 12, suit: 'spades' }, { rank: 11, suit: 'diamonds' }]; // J-Q-J
  const diem9_K = [{ rank: 13, suit: 'diamonds' }, { rank: 5, suit: 'clubs' }, { rank: 4, suit: 'hearts' }]; // K(0) + 5 + 4 = 9 điểm, lá to K♦
  const diem9_9Co = [{ rank: 9, suit: 'hearts' }, { rank: 5, suit: 'clubs' }, { rank: 5, suit: 'spades' }]; // 9 điểm, lá to 9♥
  const diem9_9Ro = [{ rank: 9, suit: 'diamonds' }, { rank: 6, suit: 'clubs' }, { rank: 4, suit: 'hearts' }]; // 9 điểm, lá to 9♦

  const sSap = LiengEvaluator.evaluate(sap, 'north');
  const sLieng = LiengEvaluator.evaluate(lieng, 'north');
  const sDi = LiengEvaluator.evaluate(di, 'north');
  const sDiem9_K = LiengEvaluator.evaluate(diem9_K, 'north');
  const sDiem9_9Co = LiengEvaluator.evaluate(diem9_9Co, 'north');
  const sDiem9_9Ro = LiengEvaluator.evaluate(diem9_9Ro, 'north');

  assert(sSap.typeName === 'Sáp' && sSap.score >= 1000000, 'Nhận diện Sáp (> 1.000.000 điểm)');
  assert(sLieng.typeName === 'Liêng' && sLieng.score >= 500000, 'Nhận diện Liêng Q-K-A (> 500.000 điểm)');
  assert(sDi.typeName === 'Ba Tây' && sDi.score >= 100000, 'Nhận diện Ba Tây J-Q-J (> 100.000 điểm)');
  assert(sDiem9_K.typeName === 'Điểm Thường' && sDiem9_K.score >= 9000, 'Nhận diện Điểm Thường 9 điểm (9.000+ điểm)');

  assert(LiengEvaluator.compare(sSap, sLieng) > 0, 'Sáp thắng Liêng');
  assert(LiengEvaluator.compare(sLieng, sDi) > 0, 'Liêng thắng Ba Tây');
  assert(LiengEvaluator.compare(sDi, sDiem9_K) > 0, 'Ba Tây thắng 9 điểm');

  // Test So sánh lá cao nhất: K♦ thắng 9♥
  assert(LiengEvaluator.compare(sDiem9_K, sDiem9_9Co) > 0, 'Cùng 9 điểm: Lá cao K♦ thắng lá cao 9♥');

  // Test So sánh chất bài khi cùng lá cao nhất là 9: 9 Cơ thắng 9 Rô (Miền Bắc: Cơ > Rô)
  assert(LiengEvaluator.compare(sDiem9_9Co, sDiem9_9Ro) > 0, 'Cùng 9 điểm và cùng lá to nhất là 9: 9♥ (Cơ) thắng 9♦ (Rô)');

  // Test luật Miền Nam Bích lớn: Rô > Cơ -> 9♦ thắng 9♥
  const s9Co_SouthA = LiengEvaluator.evaluate(diem9_9Co, 'southA');
  const s9Ro_SouthA = LiengEvaluator.evaluate(diem9_9Ro, 'southA');
  assert(LiengEvaluator.compare(s9Ro_SouthA, s9Co_SouthA) > 0, 'Luật Miền Nam Bích lớn: 9♦ (Rô) thắng 9♥ (Cơ)');

  // Test Chuẩn Quốc Tế: Không so chất -> Cùng 9 điểm là ĐỒNG HẠNG (Hòa) tuyệt đối!
  const s9K_Int = LiengEvaluator.evaluate(diem9_K, 'international');
  const s9Co_Int = LiengEvaluator.evaluate(diem9_9Co, 'international');
  const s9Ro_Int = LiengEvaluator.evaluate(diem9_9Ro, 'international');
  assert(s9K_Int.score === 9000 && s9Co_Int.score === 9000 && s9Ro_Int.score === 9000, 'Chuẩn Quốc Tế: Cả 3 tụ 9 điểm đều có điểm số bằng nhau (9.000 điểm)');
  assert(LiengEvaluator.compare(s9K_Int, s9Co_Int) === 0, 'Chuẩn Quốc Tế: 9 điểm có K♦ HÒA với 9 điểm có 9♥ (Đồng Hạng 1)');
  assert(LiengEvaluator.compare(s9Co_Int, s9Ro_Int) === 0, 'Chuẩn Quốc Tế: 9 điểm 9♥ HÒA với 9 điểm 9♦ (Đồng Hạng 1)');
  assert(s9K_Int.desc === '⭐ 9 Điểm', 'Chuẩn Quốc Tế: Tiêu đề hiển thị gọn gàng "9 Điểm", không ghi chất phụ');
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

// 13. Test Cơ Chế Giữ Con Trỏ / Khung Sáng khi Tụ Còn Thiếu Bài (Fix Bug)
{
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: setTimeout
  };
  vm.createContext(sandbox);
  vm.runInContext(appCode, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const app = new AppCtrl();
  app.currentGameType = 'lieng3';
  app.initPlayers(); // 3 players, 3 cards each

  // Chia full 3 lá cho cả 3 tụ (9 lá)
  for (let i = 2; i <= 10; i++) {
    app.onCardClick({ id: i + 'h', rank: i, suit: 'hearts', sym: '' + i, suitIcon: '♥' });
  }

  assert(app.players[0].cards.length === 3 && app.players[1].cards.length === 3 && app.players[2].cards.length === 3, 'Con trỏ: Chia đủ bài cho cả 3 tụ');

  // Xóa 2 lá của Tụ 1 (P0) -> P0 còn 1 lá
  const c1 = app.players[0].cards[0].id;
  const c2 = app.players[0].cards[1].id;
  app.removeCard(c1);
  app.removeCard(c2);

  assert(app.players[0].cards.length === 1, 'Con trỏ: Xóa 2 lá của Tụ 1 thành công (Tụ 1 còn 1 lá)');
  assert(app.roundRobinPointer === 0, 'Con trỏ: Tiêu điểm chuyển về Tụ 1 sau khi xóa lá');

  // Nhập 1 lá mới -> Tụ 1 lên 2 lá (vẫn còn thiếu 1 lá)
  app.onCardClick({ id: 'Ah', rank: 14, suit: 'hearts', sym: 'A', suitIcon: '♥' });
  assert(app.players[0].cards.length === 2, 'Con trỏ: Tụ 1 nhận lá thành công (Tụ 1 lên 2 lá)');
  assert(app.roundRobinPointer === 0, 'Con trỏ: Khung sáng VẪN Ở LẠI TỤ 1 vì Tụ 1 vẫn còn thiếu 1 lá (KHÔNG nhảy sang Tụ 2)!');

  // Nhập tiếp lá thứ 3 -> Tụ 1 đủ 3 lá
  app.onCardClick({ id: 'Kd', rank: 13, suit: 'diamonds', sym: 'K', suitIcon: '♦' });
  assert(app.players[0].cards.length === 3, 'Con trỏ: Tụ 1 nhận đủ 3 lá');
  assert(app.isReady() === true, 'Con trỏ: Toàn bộ các tụ đã đủ bài và sẵn sàng so bài');
}

// 14. Test Phỏm: Ù Khan (9 lá không có cạ) & Luật Miền Nam (Móm -4 chi)
{
  // Bài Ù Khan: 9 lá hoàn toàn không cạ (không cùng số, không cùng chất gần nhau)
  const uKhanCards = [
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '5h', rank: 5, suit: 'hearts', sym: '5', suitIcon: '♥' },
    { id: '8h', rank: 8, suit: 'hearts', sym: '8', suitIcon: '♥' },
    { id: '3d', rank: 3, suit: 'diamonds', sym: '3', suitIcon: '♦' },
    { id: '6d', rank: 6, suit: 'diamonds', sym: '6', suitIcon: '♦' },
    { id: '9d', rank: 9, suit: 'diamonds', sym: '9', suitIcon: '♦' },
    { id: '4c', rank: 4, suit: 'clubs', sym: '4', suitIcon: '♣' },
    { id: '7c', rank: 7, suit: 'clubs', sym: '7', suitIcon: '♣' },
    { id: '10s', rank: 10, suit: 'spades', sym: '10', suitIcon: '♠' }
  ];
  const resUKhan = PhomEvaluator.evaluate(uKhanCards);
  assert(resUKhan.isU === true && resUKhan.isUKhan === true, 'Phỏm: Nhận diện chính xác Ù Khan (9 lá không cạ)');

  // So sánh Ù Khan thắng người có điểm
  const normalCards = [
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '3h', rank: 3, suit: 'hearts', sym: '3', suitIcon: '♥' },
    { id: '4h', rank: 4, suit: 'hearts', sym: '4', suitIcon: '♥' },
    { id: '5c', rank: 5, suit: 'clubs', sym: '5', suitIcon: '♣' },
    { id: '6d', rank: 6, suit: 'diamonds', sym: '6', suitIcon: '♦' },
    { id: '7s', rank: 7, suit: 'spades', sym: '7', suitIcon: '♠' },
    { id: '8c', rank: 8, suit: 'clubs', sym: '8', suitIcon: '♣' },
    { id: '9d', rank: 9, suit: 'diamonds', sym: '9', suitIcon: '♦' },
    { id: '10s', rank: 10, suit: 'spades', sym: '10', suitIcon: '♠' }
  ];
  const momCards = [
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '3h', rank: 3, suit: 'hearts', sym: '3', suitIcon: '♥' }, // Có cạ 2-3♥ -> không phải Ù Khan
    { id: '5d', rank: 5, suit: 'diamonds', sym: '5', suitIcon: '♦' },
    { id: '7c', rank: 7, suit: 'clubs', sym: '7', suitIcon: '♣' },
    { id: '9s', rank: 9, suit: 'spades', sym: '9', suitIcon: '♠' },
    { id: 'Jc', rank: 11, suit: 'clubs', sym: 'J', suitIcon: '♣' },
    { id: 'Qd', rank: 12, suit: 'diamonds', sym: 'Q', suitIcon: '♦' },
    { id: 'Kh', rank: 13, suit: 'hearts', sym: 'K', suitIcon: '♥' },
    { id: 'As', rank: 14, suit: 'spades', sym: 'A', suitIcon: '♠' }
  ];

  const ranked = PhomEvaluator.rankPlayers([
    { name: 'Tụ 1', cards: uKhanCards },
    { name: 'Tụ 2', cards: normalCards },
    { name: 'Tụ 3', cards: momCards }
  ]);

  assert(ranked[0].name === 'Tụ 1' && ranked[0].rank === 1, 'Phỏm: Tụ Ù Khan đạt Hạng 1');
  assert(ranked[0].scoreDelta === 12, 'Phỏm: Ù Khan nhận +6 chi từ mỗi người thua (2 người = +12 chi)');
  assert(ranked[1].scoreDelta === -6 && ranked[2].scoreDelta === -6, 'Phỏm: Người thua đền 6 chi khi có Ù');
}

// 15. Test Phỏm: Ù Tròn 10 Lá (Thắng x2 = 12 chi) & Đánh 10 lá tự bỏ rác
{
  // 10 lá tạo 3 phỏm hoàn chỉnh (3-3-4 lá = 10 lá, 0 rác) -> Ù Tròn
  const uTronCards = [
    // Phỏm 1: 2♥ 3♥ 4♥
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '3h', rank: 3, suit: 'hearts', sym: '3', suitIcon: '♥' },
    { id: '4h', rank: 4, suit: 'hearts', sym: '4', suitIcon: '♥' },
    // Phỏm 2: 7♣ 7♦ 7♠
    { id: '7c', rank: 7, suit: 'clubs', sym: '7', suitIcon: '♣' },
    { id: '7d', rank: 7, suit: 'diamonds', sym: '7', suitIcon: '♦' },
    { id: '7s', rank: 7, suit: 'spades', sym: '7', suitIcon: '♠' },
    // Phỏm 3: 10♠ J♠ Q♠ K♠
    { id: '10s', rank: 10, suit: 'spades', sym: '10', suitIcon: '♠' },
    { id: '11s', rank: 11, suit: 'spades', sym: 'J', suitIcon: '♠' },
    { id: '12s', rank: 12, suit: 'spades', sym: 'Q', suitIcon: '♠' },
    { id: '13s', rank: 13, suit: 'spades', sym: 'K', suitIcon: '♠' }
  ];

  const resUTron = PhomEvaluator.evaluate(uTronCards);
  assert(resUTron.isU === true && resUTron.isUTron === true, 'Phỏm: Nhận diện chính xác Ù Tròn 10 lá (0 rác)');

  const otherCards = [
    { id: '2c', rank: 2, suit: 'clubs', sym: '2', suitIcon: '♣' },
    { id: '3c', rank: 3, suit: 'clubs', sym: '3', suitIcon: '♣' },
    { id: '4c', rank: 4, suit: 'clubs', sym: '4', suitIcon: '♣' },
    { id: '5h', rank: 5, suit: 'hearts', sym: '5', suitIcon: '♥' },
    { id: '6d', rank: 6, suit: 'diamonds', sym: '6', suitIcon: '♦' },
    { id: '8s', rank: 8, suit: 'spades', sym: '8', suitIcon: '♠' },
    { id: '9c', rank: 9, suit: 'clubs', sym: '9', suitIcon: '♣' },
    { id: '10d', rank: 10, suit: 'diamonds', sym: '10', suitIcon: '♦' },
    { id: 'As', rank: 14, suit: 'spades', sym: 'A', suitIcon: '♠' }
  ];

  const rankedTron = PhomEvaluator.rankPlayers([
    { name: 'Tụ Ù Tròn', cards: uTronCards },
    { name: 'Tụ 2', cards: otherCards }
  ]);
  assert(rankedTron[0].scoreDelta === 12, 'Phỏm: Ù Tròn phạt x2 (thắng 12 chi/người)');
  assert(rankedTron[1].scoreDelta === -12, 'Phỏm: Người thua bị phạt -12 chi khi đối thủ Ù Tròn');

  // Test 10 lá không Ù tròn -> tự động bỏ 1 lá rác tối ưu
  const tenCardsWithTrash = [
    // Phỏm 2♥ 3♥ 4♥
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '3h', rank: 3, suit: 'hearts', sym: '3', suitIcon: '♥' },
    { id: '4h', rank: 4, suit: 'hearts', sym: '4', suitIcon: '♥' },
    // Phỏm 7♣ 7♦ 7♠
    { id: '7c', rank: 7, suit: 'clubs', sym: '7', suitIcon: '♣' },
    { id: '7d', rank: 7, suit: 'diamonds', sym: '7', suitIcon: '♦' },
    { id: '7s', rank: 7, suit: 'spades', sym: '7', suitIcon: '♠' },
    // Rác: 2 lá 2♣ (2đ) và K♠ (13đ) + 2 lá khác
    { id: '2c', rank: 2, suit: 'clubs', sym: '2', suitIcon: '♣' },
    { id: '3d', rank: 3, suit: 'diamonds', sym: '3', suitIcon: '♦' },
    { id: '5s', rank: 5, suit: 'spades', sym: '5', suitIcon: '♠' },
    { id: '13s', rank: 13, suit: 'spades', sym: 'K', suitIcon: '♠' } // Lá rác to nhất 13đ
  ];
  const res10Sub = PhomEvaluator.evaluate(tenCardsWithTrash);
  assert(res10Sub.summary.includes('K♠'), 'Phỏm: Tự động bỏ lá rác tối ưu K♠ khi cầm 10 lá');
}

// 16. Test Poker: Tự Động Nhảy Lên Bài Chung khi Các Tụ Đủ 2 Lá
{
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: setTimeout
  };
  vm.createContext(sandbox);
  vm.runInContext(appCode, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const appPoker = new AppCtrl();
  appPoker.currentGameType = 'texasHoldem';
  appPoker.initPlayers(); // 3 players, 2 cards each, 5 community

  // Chia lần lượt 6 lá cho 3 tụ
  const cards6 = [
    { id: 'Ah', rank: 14, suit: 'hearts', sym: 'A', suitIcon: '♥' },
    { id: 'Kh', rank: 13, suit: 'hearts', sym: 'K', suitIcon: '♥' },
    { id: 'Qh', rank: 12, suit: 'hearts', sym: 'Q', suitIcon: '♥' },
    { id: 'Jh', rank: 11, suit: 'hearts', sym: 'J', suitIcon: '♥' },
    { id: '10h', rank: 10, suit: 'hearts', sym: '10', suitIcon: '♥' },
    { id: '9h', rank: 9, suit: 'hearts', sym: '9', suitIcon: '♥' }
  ];
  cards6.forEach(c => appPoker.onCardClick(c));

  assert(appPoker.players[0].cards.length === 2 && appPoker.players[1].cards.length === 2 && appPoker.players[2].cards.length === 2, 'Poker: Cả 3 tụ đã đủ 2 lá bài tẩy');
  assert(appPoker.isSelectingCommunity === true, 'Poker: Tự động chuyển trạng thái isSelectingCommunity sang true');

  // Nhập lá thứ 7 -> Tự động rơi vào Bài Chung
  appPoker.onCardClick({ id: '2c', rank: 2, suit: 'clubs', sym: '2', suitIcon: '♣' });
  assert(appPoker.communityCards.length === 1 && appPoker.communityCards[0].id === '2c', 'Poker: Lá thứ 7 tự động vào Bài Chung');
}

// 17. Test Phỏm: Bấm 'Ván Mới' tự động gán 10 lá và lượt đi đầu cho người về Nhất ván trước
{
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: setTimeout
  };
  vm.createContext(sandbox);
  vm.runInContext(appCode, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const app = new AppCtrl();
  app.currentGameType = 'phom9';
  app.playerCount = 3;
  app.initPlayers();

  // Giả lập kết quả ván 1: Tụ 2 (index 1) về Nhất (Ù)
  app.players[0].cards = [
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '3h', rank: 3, suit: 'hearts', sym: '3', suitIcon: '♥' },
    { id: '4h', rank: 4, suit: 'hearts', sym: '4', suitIcon: '♥' },
    { id: '5c', rank: 5, suit: 'clubs', sym: '5', suitIcon: '♣' },
    { id: '6d', rank: 6, suit: 'diamonds', sym: '6', suitIcon: '♦' },
    { id: '7s', rank: 7, suit: 'spades', sym: '7', suitIcon: '♠' },
    { id: '8c', rank: 8, suit: 'clubs', sym: '8', suitIcon: '♣' },
    { id: '9d', rank: 9, suit: 'diamonds', sym: '9', suitIcon: '♦' },
    { id: '10s', rank: 10, suit: 'spades', sym: '10', suitIcon: '♠' }
  ];
  // Tụ 2 Ù Tròn 10 lá
  app.players[1].cards = [
    { id: '2c', rank: 2, suit: 'clubs', sym: '2', suitIcon: '♣' },
    { id: '3c', rank: 3, suit: 'clubs', sym: '3', suitIcon: '♣' },
    { id: '4c', rank: 4, suit: 'clubs', sym: '4', suitIcon: '♣' },
    { id: '7h', rank: 7, suit: 'hearts', sym: '7', suitIcon: '♥' },
    { id: '7d', rank: 7, suit: 'diamonds', sym: '7', suitIcon: '♦' },
    { id: '7s', rank: 7, suit: 'spades', sym: '7', suitIcon: '♠' },
    { id: '10c', rank: 10, suit: 'clubs', sym: '10', suitIcon: '♣' },
    { id: 'Jc', rank: 11, suit: 'clubs', sym: 'J', suitIcon: '♣' },
    { id: 'Qc', rank: 12, suit: 'clubs', sym: 'Q', suitIcon: '♣' },
    { id: 'Kc', rank: 13, suit: 'clubs', sym: 'K', suitIcon: '♣' }
  ];
  app.players[2].cards = [
    { id: '5h', rank: 5, suit: 'hearts', sym: '5', suitIcon: '♥' },
    { id: '6h', rank: 6, suit: 'hearts', sym: '6', suitIcon: '♥' },
    { id: '7h', rank: 7, suit: 'hearts', sym: '7', suitIcon: '♥' },
    { id: '8d', rank: 8, suit: 'diamonds', sym: '8', suitIcon: '♦' },
    { id: '9s', rank: 9, suit: 'spades', sym: '9', suitIcon: '♠' },
    { id: '10h', rank: 10, suit: 'hearts', sym: '10', suitIcon: '♥' },
    { id: 'Jh', rank: 11, suit: 'hearts', sym: 'J', suitIcon: '♥' },
    { id: 'Qh', rank: 12, suit: 'hearts', sym: 'Q', suitIcon: '♥' },
    { id: 'Kh', rank: 13, suit: 'hearts', sym: 'K', suitIcon: '♥' }
  ];

  // Tính kết quả ván 1
  app.calculate();

  assert(app.players[1].rankOrder === 1, 'Ván Mới: Tụ 2 đạt Hạng 1 (Nhất ván 1)');
  assert(app.lastPhomWinnerIndex === 1, 'Ván Mới: Hệ thống ghi nhận Tụ 2 (index 1) là người chiến thắng');

  // Bấm nút "Ván Mới"
  app.startNewRound();

  // Kiểm tra trạng thái ván 2
  assert(app.players.every(p => p.cards.length === 0), 'Ván Mới: Tất cả bài trên bàn đã được thu hồi');
  assert(app.players.every(p => p.rankOrder === null), 'Ván Mới: Kết quả ván cũ đã được xóa sạch');
  assert(app.phomTenCardPlayerIndex === 1, 'Ván Mới: Tụ 2 (người thắng ván trước) TỰ ĐỘNG LÀ 10 LÁ');
  assert(app.targetCards(1) === 10, 'Ván Mới: targetCards(1) của Tụ 2 là 10 lá');
  assert(app.targetCards(0) === 9 && app.targetCards(2) === 9, 'Ván Mới: Các tụ còn lại target là 9 lá');
  assert(app.roundRobinPointer === 1, 'Ván Mới: Con trỏ chia bài TỰ ĐỘNG CHUYỂN VỀ TỤ 2 để nhận lá đi đầu tiên');

  // Bấm nút Xóa thùng rác (reset sạch)
  app.resetTable();
  assert(app.phomTenCardPlayerIndex === null, 'Nút Xóa: Reset hoàn toàn cả tụ 10 lá về mặc định');
  assert(app.roundRobinPointer === 0, 'Nút Xóa: Con trỏ chia bài quay về Tụ 1');
}

console.log(`\n=== TỔNG KẾT: ${passed}/${total} TESTS ĐẠT CHUẨN 100% ===`);





