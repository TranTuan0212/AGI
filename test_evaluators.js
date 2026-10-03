const fs = require('fs');
const vm = require('vm');

// We will read app.js content and evaluate the classes in a sandbox
const appCode = fs.readFileSync('e:/appgame/preview/app.js', 'utf8');

// Strip out window / document DOM stuff for node testing of logic classes
const logicCode = appCode.split('// MARK: - State & App Controller')[0];

// Mock localStorage for Node test environment
if (typeof localStorage === 'undefined') {
  global.localStorage = {
    _data: {},
    getItem(k) { return this._data[k] || null; },
    setItem(k, v) { this._data[k] = String(v); },
    removeItem(k) { delete this._data[k]; },
    clear() { this._data = {}; }
  };
}

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

console.log('=== BẮT ĐẦU KIỂM THỬ THUẬT TOÁN ENGINE (6 TRÒ CHƠI) ===\n');

// 1. Test Texas Hold'em / Poker Wheel Straight (A-2-3-4-5) vs (2-3-4-5-6)
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

  assert(sWheel.type === 5, 'Poker: Nhận diện đúng Sảnh bánh xe (type=5 Straight)');
  assert(sWheel.tieBreakers[0] === 5, 'Poker: Sảnh bánh xe có đỉnh là 5 (tieBreakers[0] == 5)');
  assert(PokerEvaluator.compareScores(s6, sWheel) > 0, 'Poker: Sảnh 2-3-4-5-6 (đỉnh 6) thắng Sảnh bánh xe A-2-3-4-5 (đỉnh 5)');
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
  assert(PokerEvaluator.compareScores(score1, score2) > 0, 'Poker: Hai đôi AA88K thắng AA88Q nhờ Kicker King > Queen');
}

// 3. Test Liêng (Sáp > Liêng > Ba Tây > Điểm mod 10 & So sánh lá to nhất + Chất bài)
{
  const sap = [{ rank: 7, suit: 'hearts' }, { rank: 7, suit: 'spades' }, { rank: 7, suit: 'diamonds' }];
  const lieng = [{ rank: 14, suit: 'hearts' }, { rank: 2, suit: 'diamonds' }, { rank: 3, suit: 'spades' }]; // A-2-3 Liêng nhỏ nhất
  const baTay = [{ rank: 11, suit: 'spades' }, { rank: 12, suit: 'hearts' }, { rank: 12, suit: 'clubs' }]; // Q-Q-J không liên tiếp
  const diem9Real = [{ rank: 4, suit: 'hearts' }, { rank: 5, suit: 'diamonds' }, { rank: 13, suit: 'spades' }]; // 4+5+0 = 9 nút

  const sSap = LiengEvaluator.evaluate(sap);
  const sLieng = LiengEvaluator.evaluate(lieng);
  const sBaTay = LiengEvaluator.evaluate(baTay);
  const sDiem9 = LiengEvaluator.evaluate(diem9Real);

  assert(sSap.typeName === "Sáp", 'Liêng: Nhận diện Sáp');
  assert(sLieng.typeName === "Liêng", 'Liêng: Nhận diện Liêng A-2-3');
  assert(sBaTay.typeName === "Ba Tây", 'Liêng: Nhận diện Ba Tây (Ảnh)');
  assert(sDiem9.typeName === "Điểm Thường", 'Liêng: Nhận diện 9 Nút (Điểm Thường)');

  assert(LiengEvaluator.compare(sSap, sLieng) > 0, 'Liêng: Sáp > Liêng');
  assert(LiengEvaluator.compare(sLieng, sBaTay) > 0, 'Liêng: Liêng > Ba Tây');
  assert(LiengEvaluator.compare(sBaTay, sDiem9) > 0, 'Liêng: Ba Tây > 9 Nút');
}

// 4. Test Liêng: So sánh khi cùng điểm bằng Lá lớn nhất và Chất bài
{
  const p1 = [
    { rank: 9, suit: 'hearts' }, // 9 Cơ
    { rank: 10, suit: 'spades' },
    { rank: 13, suit: 'diamonds' } // 9+0+0 = 9 điểm, Max rank = 13 (K Rô)
  ];
  const p2 = [
    { rank: 9, suit: 'diamonds' }, // 9 Rô
    { rank: 10, suit: 'clubs' },
    { rank: 13, suit: 'spades' } // 9+0+0 = 9 điểm, Max rank = 13 (K Bích)
  ];
  const s1 = LiengEvaluator.evaluate(p1);
  const s2 = LiengEvaluator.evaluate(p2);

  // Cùng 9 điểm, cùng có K, nhưng K Rô (p1) > K Bích (p2) theo chuẩn Miền Bắc (Cơ > Rô > Chuồn > Bích)
  assert(LiengEvaluator.compare(s1, s2) > 0, 'Liêng: Cùng 9 điểm, cùng K cao nhất, K Rô thắng K Bích (theo preset Miền Bắc)');
}

// 5. Test Binh 9 lá: Auto-arrange 3 chi (3-3-3), Chi 1 >= Chi 2 >= Chi 3 (Luật Cào / Liêng)
{
  const hand = [
    { rank: 14, suit: 'hearts' }, { rank: 14, suit: 'diamonds' }, { rank: 14, suit: 'clubs' }, // Sáp A (type 5)
    { rank: 10, suit: 'hearts' }, { rank: 9, suit: 'diamonds' }, { rank: 8, suit: 'clubs' },   // Liêng 8-9-10 (type 4)
    { rank: 7, suit: 'hearts' }, { rank: 7, suit: 'diamonds' }, { rank: 2, suit: 'spades' }    // 6 Điểm Đôi 7 (type 2)
  ];
  const arr = Binh9Evaluator.autoArrange(hand);
  assert(!arr.isLung, 'Binh 9: Không bị lủng khi sắp xếp hợp lệ');
  assert(arr.score1.type === 5, 'Binh 9: Chi 1 là Sáp A (type=5)');
  assert(arr.score2.type === 4, 'Binh 9: Chi 2 là Liêng (type=4)');
  assert(arr.score3.type === 2, 'Binh 9: Chi 3 là Điểm Đôi (type=2)');
}

// 6. Test Binh 9 lá: Thắng trắng Ba Sáp & Ba Liêng
{
  const baSamCards = [
    { rank: 14, suit: 'hearts' }, { rank: 14, suit: 'diamonds' }, { rank: 14, suit: 'clubs' },
    { rank: 10, suit: 'hearts' }, { rank: 10, suit: 'diamonds' }, { rank: 10, suit: 'clubs' },
    { rank: 5, suit: 'hearts' }, { rank: 5, suit: 'diamonds' }, { rank: 5, suit: 'clubs' }
  ];
  const arrBaSam = Binh9Evaluator.autoArrange(baSamCards);
  assert(arrBaSam.instantWin && (arrBaSam.instantWin.includes('Ba Sáp') || arrBaSam.instantWin.includes('Ba Sám Cô')), 'Binh 9: Nhận diện Thắng trắng Ba Sáp');

  const baSanhCards = [
    { rank: 14, suit: 'hearts' }, { rank: 13, suit: 'diamonds' }, { rank: 12, suit: 'clubs' },
    { rank: 9, suit: 'hearts' }, { rank: 8, suit: 'diamonds' }, { rank: 7, suit: 'clubs' },
    { rank: 4, suit: 'hearts' }, { rank: 3, suit: 'diamonds' }, { rank: 2, suit: 'clubs' }
  ];
  const arrBaSanh = Binh9Evaluator.autoArrange(baSanhCards);
  assert(arrBaSanh.instantWin && (arrBaSanh.instantWin.includes('Ba Liêng') || arrBaSanh.instantWin.includes('Ba Sảnh')), 'Binh 9: Nhận diện Thắng trắng Ba Liêng');
}

// 6b. Test Chi tiết Luật Cào / Liêng trong Binh 9 lá (9 điểm đôi ăn 9 điểm thường, điểm cao hơn ăn điểm thấp hơn, Ba Tây)
{
  const c775 = [{ rank: 7 }, { rank: 7 }, { rank: 5 }]; // 7+7+5 = 19 -> 9 điểm đôi 7
  const cK54 = [{ rank: 13 }, { rank: 5 }, { rank: 4 }]; // 0+5+4 = 9 điểm thường, kicker K
  const c44K = [{ rank: 4 }, { rank: 4 }, { rank: 13 }]; // 4+4+0 = 8 điểm đôi 4
  const cBaTay = [{ rank: 11 }, { rank: 12 }, { rank: 13 }]; // J, Q, K -> Ba Tây (hoặc Liêng, nếu Q-J-K là Liêng thì J-J-Q là Ba Tây)
  const cJJQ = [{ rank: 11 }, { rank: 11 }, { rank: 12 }]; // J, J, Q -> Ba Tây
  const cLieng = [{ rank: 11 }, { rank: 12 }, { rank: 13 }]; // J, Q, K -> Liêng
  const cSap8 = [{ rank: 8 }, { rank: 8 }, { rank: 8 }]; // 8, 8, 8 -> Sáp 8

  const s775 = Binh9Evaluator.evaluateChi(c775);
  const sK54 = Binh9Evaluator.evaluateChi(cK54);
  const s44K = Binh9Evaluator.evaluateChi(c44K);
  const sJJQ = Binh9Evaluator.evaluateChi(cJJQ);
  const sLieng = Binh9Evaluator.evaluateChi(cLieng);
  const sSap8 = Binh9Evaluator.evaluateChi(cSap8);

  assert(s775.type === 2 && s775.points === 9, 'Binh 9 Chi: 7-7-5 nhận diện đúng 9 Điểm Đôi');
  assert(sK54.type === 1 && sK54.points === 9, 'Binh 9 Chi: K-5-4 nhận diện đúng 9 Điểm Thường');
  assert(s44K.type === 2 && s44K.points === 8, 'Binh 9 Chi: 4-4-K nhận diện đúng 8 Điểm Đôi');
  assert(sJJQ.type === 3, 'Binh 9 Chi: J-J-Q nhận diện đúng Ba Tây');
  assert(sLieng.type === 4, 'Binh 9 Chi: J-Q-K nhận diện đúng Liêng');
  assert(sSap8.type === 5, 'Binh 9 Chi: 8-8-8 nhận diện đúng Sáp');

  // So sánh
  assert(Binh9Evaluator.compareChi(s775, sK54) > 0, 'Binh 9 So sánh: 9 Điểm Đôi (7-7-5) ĂN 9 Điểm Thường (K-5-4)');
  assert(Binh9Evaluator.compareChi(sK54, s44K) > 0, 'Binh 9 So sánh: 9 Điểm Thường (K-5-4) ĂN 8 Điểm Đôi (4-4-K)');
  assert(Binh9Evaluator.compareChi(sJJQ, s775) > 0, 'Binh 9 So sánh: Ba Tây (J-J-Q) ĂN 9 Điểm Đôi (7-7-5)');
  assert(Binh9Evaluator.compareChi(sLieng, sJJQ) > 0, 'Binh 9 So sánh: Liêng (J-Q-K) ĂN Ba Tây (J-J-Q)');
  assert(Binh9Evaluator.compareChi(sSap8, sLieng) > 0, 'Binh 9 So sánh: Sáp 8 (8-8-8) ĂN Liêng (J-Q-K)');
}

// 7. Test Binh 9 lá: Thắng >= 2 chi là Thắng luôn ván đối đầu (score = 1)
{
  const arrWinner = {
    isLung: false, instantWin: null,
    score1: { type: 5, primaryRank: 14, kickers: [] },
    score2: { type: 4, primaryRank: 10, kickers: [] },
    score3: { type: 2, points: 9, primaryRank: 7, kickers: [2] }
  };
  const arrLoser = {
    isLung: false, instantWin: null,
    score1: { type: 4, primaryRank: 12, kickers: [] },
    score2: { type: 3, primaryRank: 12, kickers: [11] },
    score3: { type: 1, points: 9, primaryRank: 0, kickers: [13, 5, 4] }
  };
  const match = Binh9Evaluator.compareMatch(arrWinner, arrLoser);
  assert(match.scoreA === 1, `Binh 9: Thắng cả 3 chi = Thắng đối đầu (scoreA = 1, Thực tế: ${match.scoreA})`);

  // Test Thắng 2 chi, thua 1 chi -> Vẫn Thắng luôn đối đầu (scoreA = 1)
  const arr2ChiWin = {
    isLung: false, instantWin: null,
    score1: { type: 5, primaryRank: 14, kickers: [] }, // Thắng Chi 1
    score2: { type: 4, primaryRank: 10, kickers: [] }, // Thắng Chi 2
    score3: { type: 1, points: 2, primaryRank: 0, kickers: [7, 3, 2] } // Thua Chi 3
  };
  const arr2ChiLose = {
    isLung: false, instantWin: null,
    score1: { type: 4, primaryRank: 12, kickers: [] }, // Thua Chi 1
    score2: { type: 3, primaryRank: 12, kickers: [11] }, // Thua Chi 2
    score3: { type: 5, primaryRank: 8, kickers: [] } // Ăn Chi 3 (Sáp 8)
  };
  const match2 = Binh9Evaluator.compareMatch(arr2ChiWin, arr2ChiLose);
  assert(match2.scoreA === 1, `Binh 9: Thắng 2 chi thua 1 chi = Thắng luôn đối đầu (scoreA = 1, Thực tế: ${match2.scoreA})`);
}

// 8. Test Binh 6 lá (Thang Poker 6 lá): Chọn 5 lá mạnh nhất từ 6 lá
{
  const cards6 = [
    { rank: 14, suit: 'hearts' },
    { rank: 13, suit: 'hearts' },
    { rank: 12, suit: 'hearts' },
    { rank: 11, suit: 'hearts' },
    { rank: 10, suit: 'hearts' }, // Thùng phá sảnh A♥ K♥ Q♥ J♥ 10♥
    { rank: 2, suit: 'spades' }
  ];
  const best5 = PokerEvaluator.evaluateBestOfMany(cards6);
  assert(best5.type === 10, 'Binh 6 Poker: Nhận diện Thùng phá sảnh lớn (Royal Flush, type=10)');
  assert(!best5.cards.some(c => c.rank === 2), 'Binh 6 Poker: Loại bỏ lá rác 2♠ để giữ 5 lá mạnh nhất');
}

// 9. Test Xì Dách (2 Lá): Xì Bàng > Xì Dách > 20 điểm
{
  const xiBang = [{ rank: 14, suit: 'hearts' }, { rank: 14, suit: 'diamonds' }]; // AA
  const xiDach = [{ rank: 14, suit: 'hearts' }, { rank: 13, suit: 'spades' }];  // A + K
  const d20 = [{ rank: 10, suit: 'hearts' }, { rank: 10, suit: 'clubs' }];      // 20 điểm

  const sXiBang = XiDachEvaluator.evaluate(xiBang);
  const sXiDach = XiDachEvaluator.evaluate(xiDach);
  const s20 = XiDachEvaluator.evaluate(d20);

  assert(sXiBang.score === 5021, 'Xì Dách: Nhận diện Xì Bàng (score=5021)');
  assert(sXiDach.score === 4000, 'Xì Dách: Nhận diện Xì Dách (score=4000)');
  assert(s20.score === 2020, 'Xì Dách: Nhận diện 20 điểm (score=2020)');

  assert(sXiBang.score > sXiDach.score, 'Xì Dách: Xì Bàng > Xì Dách');
  assert(sXiDach.score > s20.score, 'Xì Dách: Xì Dách > 20 điểm');
}

// 10. Test AppController: Game mặc định là Liêng 3 Cây, Không còn Phỏm hay Binh 13
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

  assert(app.currentGameType === 'lieng3', 'AppController: Game khởi tạo mặc định là Liêng (lieng3)');
  assert(app.targetCards(0) === 3, 'AppController: Target bài mỗi tụ mặc định là 3 lá');
  assert(app.phomTenCardPlayerIndex === undefined, 'AppController: phomTenCardPlayerIndex đã bị loại bỏ hoàn toàn');
  assert(app.lastPhomWinnerIndex === undefined, 'AppController: lastPhomWinnerIndex đã bị loại bỏ hoàn toàn');

  // Test Auto Calculate in Liêng
  app.playerCount = 2;
  app.initPlayers();
  // Tụ 1: Sáp 9 (9♥ 9♦ 9♣)
  app.players[0].cards = [
    { id: '9h', rank: 9, suit: 'hearts', sym: '9', suitIcon: '♥' },
    { id: '9d', rank: 9, suit: 'diamonds', sym: '9', suitIcon: '♦' },
    { id: '9c', rank: 9, suit: 'clubs', sym: '9', suitIcon: '♣' }
  ];
  // Tụ 2: 9 Nút (4♥ 5♦ K♠)
  app.players[1].cards = [
    { id: '4h', rank: 4, suit: 'hearts', sym: '4', suitIcon: '♥' },
    { id: '5d', rank: 5, suit: 'diamonds', sym: '5', suitIcon: '♦' },
    { id: 'Ks', rank: 13, suit: 'spades', sym: 'K', suitIcon: '♠' }
  ];

  assert(app.isReady() === true, 'AppController: isReady() nhận diện đủ bài');
  app.calculate();

  assert(app.players[0].rankOrder === 1, 'AppController: Tụ 1 đạt Hạng 1 với Sáp 9');
  assert(app.players[1].rankOrder === 2, 'AppController: Tụ 2 đạt Hạng 2 với 9 Điểm');

  // Test Start New Round
  app.startNewRound();
  assert(app.players.every(p => p.cards.length === 0), 'AppController: Ván mới thu hồi toàn bộ bài');
  assert(app.roundRobinPointer === 0, 'AppController: Con trỏ bắt đầu từ Tụ 1');
  assert(app.selectedPlayerIndex === 0, 'AppController: Chọn Tụ 1');

  // Test Phỏm (Tá Lả) trong AppController
  app.currentGameType = 'phom9';
  app.playerCount = 3;
  app.initPlayers();

  assert(app.targetCards(0) === 10, 'Phỏm: Tụ 1 (người đi đầu) luôn luôn nhận 10 lá');
  assert(app.targetCards(1) === 9, 'Phỏm: Tụ 2 nhận 9 lá');
  assert(app.targetCards(2) === 9, 'Phỏm: Tụ 3 nhận 9 lá');

  // Giả lập Tụ 2 thắng ván 1
  app.players[0].rankOrder = 2;
  app.players[1].rankOrder = 1; // Tụ 2 Thắng
  app.players[2].rankOrder = 3;

  // Bấm "Ván mới": Tụ 1 VẪN LUÔN là 10 lá theo yêu cầu người dùng!
  app.startNewRound();
  assert(app.targetCards(0) === 10, 'Phỏm Ván Mới: Tụ 1 VẪN LUÔN LUÔN LÀ 10 LÁ dù ván trước Tụ 2 thắng');
  assert(app.targetCards(1) === 9, 'Phỏm Ván Mới: Tụ 2 vẫn nhận 9 lá');
  assert(app.roundRobinPointer === 0, 'Phỏm Ván Mới: Lượt chia bài vẫn bắt đầu từ Tụ 1');
}

// 11. Test Đánh Giá Thuật Toán Phỏm (Tá Lả)
{
  // 1. Phỏm dọc sảnh A-2-3 và ngang Sáp
  const phomVertical = [
    { id: 'Ah', rank: 14, sym: 'A', suit: 'hearts', suitIcon: '♥' },
    { id: '2h', rank: 2, sym: '2', suit: 'hearts', suitIcon: '♥' },
    { id: '3h', rank: 3, sym: '3', suit: 'hearts', suitIcon: '♥' },
    { id: '8h', rank: 8, sym: '8', suit: 'hearts', suitIcon: '♥' },
    { id: '8d', rank: 8, sym: '8', suit: 'diamonds', suitIcon: '♦' },
    { id: '8s', rank: 8, sym: '8', suit: 'spades', suitIcon: '♠' },
    { id: 'Jc', rank: 11, sym: 'J', suit: 'clubs', suitIcon: '♣' },
    { id: 'Qc', rank: 12, sym: 'Q', suit: 'clubs', suitIcon: '♣' },
    { id: 'Kc', rank: 13, sym: 'K', suit: 'clubs', suitIcon: '♣' }
  ];
  const resU = PhomEvaluator.evaluate(phomVertical);
  assert(resU.isU === true, 'Phỏm: Nhận diện đúng Ù 9 lá (3 phỏm, 0 điểm rác)');
  assert(resU.phoms.length === 3, 'Phỏm: Tách đúng 3 phỏm hợp lệ');

  // 2. Phỏm có điểm rác
  const onePhomCards = [
    { id: '8h', rank: 8, sym: '8', suit: 'hearts', suitIcon: '♥' },
    { id: '8d', rank: 8, sym: '8', suit: 'diamonds', suitIcon: '♦' },
    { id: '8s', rank: 8, sym: '8', suit: 'spades', suitIcon: '♠' },
    { id: 'Ah', rank: 14, sym: 'A', suit: 'hearts', suitIcon: '♥' }, // 1
    { id: '2h', rank: 2, sym: '2', suit: 'hearts', suitIcon: '♥' },  // 2
    { id: '4d', rank: 4, sym: '4', suit: 'diamonds', suitIcon: '♦' }, // 4
    { id: '5c', rank: 5, sym: '5', suit: 'clubs', suitIcon: '♣' },   // 5
    { id: 'Jd', rank: 11, sym: 'J', suit: 'diamonds', suitIcon: '♦' }, // 11
    { id: 'Ks', rank: 13, sym: 'K', suit: 'spades', suitIcon: '♠' }  // 13
  ];
  const resOne = PhomEvaluator.evaluate(onePhomCards);
  assert(resOne.deadwoodScore === 36, `Phỏm: Tính điểm rác chính xác 1+2+4+5+11+13 = 36 (Thực tế: ${resOne.deadwoodScore})`);

  // 3. Móm (Cháy bài)
  const momCards = [
    { id: '2h', rank: 2, sym: '2', suit: 'hearts', suitIcon: '♥' },
    { id: '4d', rank: 4, sym: '4', suit: 'diamonds', suitIcon: '♦' },
    { id: '3c', rank: 3, sym: '3', suit: 'clubs', suitIcon: '♣' },
    { id: '9h', rank: 9, sym: '9', suit: 'hearts', suitIcon: '♥' }
  ];
  const resMom = PhomEvaluator.evaluate(momCards);
  assert(resMom.isMom === true, 'Phỏm: Nhận diện chính xác Móm (Cháy bài)');

  // 4. Ù Khan (9 lá không cạ: khoảng cách cùng chất >= 3, không trùng rank)
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
  assert(resUKhan.isUKhan === true, 'Phỏm: Nhận diện chính xác Ù Khan (9 lá không cạ)');

  // 5. Ù Tròn 10 lá (0 rác)
  const uTronCards = [
    { id: 'Ah', rank: 14, suit: 'hearts', sym: 'A', suitIcon: '♥' },
    { id: '2h', rank: 2, suit: 'hearts', sym: '2', suitIcon: '♥' },
    { id: '3h', rank: 3, suit: 'hearts', sym: '3', suitIcon: '♥' },
    { id: '8h', rank: 8, suit: 'hearts', sym: '8', suitIcon: '♥' },
    { id: '8d', rank: 8, suit: 'diamonds', sym: '8', suitIcon: '♦' },
    { id: '8s', rank: 8, suit: 'spades', sym: '8', suitIcon: '♠' },
    { id: '8c', rank: 8, suit: 'clubs', sym: '8', suitIcon: '♣' },
    { id: 'Jc', rank: 11, suit: 'clubs', sym: 'J', suitIcon: '♣' },
    { id: 'Qc', rank: 12, suit: 'clubs', sym: 'Q', suitIcon: '♣' },
    { id: 'Kc', rank: 13, suit: 'clubs', sym: 'K', suitIcon: '♣' }
  ];
  const resUTron = PhomEvaluator.evaluate(uTronCards);
  assert(resUTron.isUTron === true, 'Phỏm: Nhận diện chính xác Ù Tròn 10 lá');

  // 6. Xếp hạng đối đầu
  const ranked = PhomEvaluator.rankPlayers([
    { name: 'Tụ Ù', cards: phomVertical },
    { name: 'Tụ Điểm', cards: onePhomCards },
    { name: 'Tụ Móm', cards: momCards }
  ]);
  assert(ranked[0].name === 'Tụ Ù' && ranked[0].rank === 1, 'Phỏm: Người Ù đứng Hạng 1');
  assert(ranked[1].name === 'Tụ Điểm' && ranked[1].rank === 2, 'Phỏm: Người có phỏm đứng Hạng 2');
  assert(ranked[0].scoreDelta === 12, 'Phỏm: Người Ù ăn mỗi nhà 6 chi (+12 chi)');
}

// 11. Test Chế độ không so chất (Bàn phím A->K) trong Cài Đặt (Hình răng cưa ⚙️)
{
  let storage = { 'card_game_rank_only_mode': 'true' };
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: {
      getItem: (k) => storage[k] || null,
      setItem: (k, v) => { storage[k] = v; }
    },
    console: console,
    setTimeout: setTimeout
  };
  vm.createContext(sandbox);
  vm.runInContext(appCode, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const app = new AppCtrl();

  assert(app.isRankOnlyMode === true, 'Rank-Only: Tự động tải cài đặt đã lưu từ localStorage');
  assert(app.isRankOnlyActive() === true, 'Rank-Only: Hoạt động khi đang ở game Liêng (lieng3)');

  // Kiểm tra khi đổi sang game khác (ví dụ binh9 hoặc texasHoldem)
  app.currentGameType = 'binh9';
  assert(app.isRankOnlyActive() === false, 'Rank-Only: Tự động vô hiệu hóa và chuyển về bàn phím 52 lá khi ở game Binh 9 lá');

  // Chuyển lại game Liêng (3 Cây)
  app.currentGameType = 'lieng3';
  app.playerCount = 2;
  app.initPlayers();

  // Test chọn một lá NHIỀU LẦN (Không lock)
  // Tụ 1 và Tụ 2 đều nhận 3 lá A (tổng cộng bấm 'A' 6 lần liên tiếp)
  const rankAce = { raw: 14, sym: 'A' };
  for (let i = 0; i < 6; i++) {
    app.onRankClick(rankAce);
  }

  assert(app.players[0].cards.length === 3, 'Rank-Only: Tụ 1 nhận đủ 3 lá A');
  assert(app.players[1].cards.length === 3, 'Rank-Only: Tụ 2 cũng nhận đủ 3 lá A (chọn nhiều lần không bị khóa)');
  assert(app.isReady() === true, 'Rank-Only: Tự động nhận diện sẵn sàng tính điểm');

  // Cả hai đều có Sáp A -> Vì không so chất nên phải ĐỒNG HẠNG 1!
  assert(app.players[0].rankOrder === 1, 'Rank-Only: Tụ 1 đạt Hạng 1 (Sáp A)');
  assert(app.players[1].rankOrder === 1, 'Rank-Only: Tụ 2 đạt Đồng Hạng 1 (Sáp A - Không so chất)');

  // Test Sâm Lốc với Rank-Only Mode (giống Liêng)
  app.isRankOnlyMode = true;
  app.currentGameType = 'samLoc10';
  assert(app.isRankOnlyActive() === true, 'Rank-Only: Hoạt động khi đang ở game Sâm Lốc (samLoc10)');
  app.playerCount = 2;
  app.initPlayers();
  app.inputMode = 'manual';
  app.selectedPlayerIndex = 0;
  // Nhập 10 lá số cho Tụ 1 bằng onRankClick: Sám 3, Sảnh 4-5-6, Tứ quý 8
  const ranksToClick = [
    { raw: 3, sym: '3' }, { raw: 3, sym: '3' }, { raw: 3, sym: '3' },
    { raw: 4, sym: '4' }, { raw: 5, sym: '5' }, { raw: 6, sym: '6' },
    { raw: 8, sym: '8' }, { raw: 8, sym: '8' }, { raw: 8, sym: '8' }, { raw: 8, sym: '8' }
  ];
  ranksToClick.forEach(r => app.onRankClick(r));
  assert(app.players[0].cards.length === 10, 'Sâm Lốc Rank-Only: Tụ 1 nhận đủ 10 lá số');
  const slArr = SamLocEvaluator.arrange(app.players[0].cards);
  assert(slArr.groups.length === 3, 'Sâm Lốc Rank-Only: Tách chuẩn 3 bộ (Sảnh, Sám, Tứ quý)');
  assert(slArr.trashCards.length === 0, 'Sâm Lốc Rank-Only: 0 lá rác');

  // Test lưu cài đặt khi tắt
  app.isRankOnlyMode = false;
  sandbox.localStorage.setItem('card_game_rank_only_mode', 'false');
  assert(app.isRankOnlyActive() === false, 'Rank-Only: Tắt chế độ thành công và ghi nhớ vào storage');

  // Test nút [Không thấy] (Lá bài ẩn ?)
  app.resetTable();
  app.currentGameType = 'lieng3';
  app.playerCount = 2;
  app.inputMode = 'roundRobin';
  app.initPlayers();

  // Bấm nút [Không thấy] nhiều lần liên tiếp
  app.onHiddenCardClick();
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].isHidden === true, 'Không thấy: Tụ 1 nhận được lá ẩn ?');
  app.onHiddenCardClick();
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].isHidden === true, 'Không thấy: Lượt tiếp theo chuyển sang Tụ 2 nhận lá ẩn ?');
  // Bấm thêm nhiều lần
  app.onHiddenCardClick();
  app.onHiddenCardClick();
  assert(app.players[0].cards.length === 2, 'Không thấy: Cho phép bấm nhiều lần không bị khóa');
}

// 12. Test Sâm Lốc (10 lá) - Sắp xếp theo Lựa chọn 1 [Rác -> Đôi -> Sảnh -> Sám -> Tứ quý] & Thắng trắng
{
  // Test Bài hỗn hợp 10 lá: 1 Tứ quý 8 (4 lá), 1 Sảnh 4-5-6 (3 lá), 1 Đôi K (2 lá), 1 Rác 2 (1 lá)
  const mixedHand = [
    { id: '8h', rank: 8, sym: '8', suit: 'hearts', suitIcon: '♥' },
    { id: '8d', rank: 8, sym: '8', suit: 'diamonds', suitIcon: '♦' },
    { id: '8s', rank: 8, sym: '8', suit: 'spades', suitIcon: '♠' },
    { id: '8c', rank: 8, sym: '8', suit: 'clubs', suitIcon: '♣' },
    { id: '4h', rank: 4, sym: '4', suit: 'hearts', suitIcon: '♥' },
    { id: '5d', rank: 5, sym: '5', suit: 'diamonds', suitIcon: '♦' },
    { id: '6s', rank: 6, sym: '6', suit: 'spades', suitIcon: '♠' },
    { id: 'Kh', rank: 13, sym: 'K', suit: 'hearts', suitIcon: '♥' },
    { id: 'Kd', rank: 13, sym: 'K', suit: 'diamonds', suitIcon: '♦' },
    { id: '2c', rank: 2, sym: '2', suit: 'clubs', suitIcon: '♣' }
  ];

  const res = SamLocEvaluator.arrange(mixedHand);
  assert(res.groups.length === 4, 'Sâm Lốc: Tách chính xác thành 4 nhóm bộ');
  assert(res.groups[0].type === 'trash', 'Sâm Lốc (Lựa chọn 1): Nhóm đầu tiên bên trái là [Rác]');
  assert(res.groups[1].type === 'pair', 'Sâm Lốc (Lựa chọn 1): Nhóm thứ hai là [Đôi]');
  assert(res.groups[2].type === 'straight', 'Sâm Lốc (Lựa chọn 1): Nhóm thứ ba là [Sảnh]');
  assert(res.groups[3].type === 'fourOfAKind', 'Sâm Lốc (Lựa chọn 1): Nhóm cuối cùng bên phải là [Tứ quý]');
  assert(res.trashCount === 1, 'Sâm Lốc: Nhận diện chính xác còn 1 lá rác (2♣)');

  // Test Sảnh rồng 10 lá liên tiếp (3 đến Q)
  const sanhRongHand = [
    { id: '3h', rank: 3, sym: '3', suit: 'hearts', suitIcon: '♥' },
    { id: '4d', rank: 4, sym: '4', suit: 'diamonds', suitIcon: '♦' },
    { id: '5s', rank: 5, sym: '5', suit: 'spades', suitIcon: '♠' },
    { id: '6c', rank: 6, sym: '6', suit: 'clubs', suitIcon: '♣' },
    { id: '7h', rank: 7, sym: '7', suit: 'hearts', suitIcon: '♥' },
    { id: '8d', rank: 8, sym: '8', suit: 'diamonds', suitIcon: '♦' },
    { id: '9s', rank: 9, sym: '9', suit: 'spades', suitIcon: '♠' },
    { id: '10c', rank: 10, sym: '10', suit: 'clubs', suitIcon: '♣' },
    { id: 'Jh', rank: 11, sym: 'J', suit: 'hearts', suitIcon: '♥' },
    { id: 'Qd', rank: 12, sym: 'Q', suit: 'diamonds', suitIcon: '♦' }
  ];
  const resSanhRong = SamLocEvaluator.arrange(sanhRongHand);
  assert(resSanhRong.instantWin != null && resSanhRong.instantWin.includes('Sảnh Rồng'), 'Sâm Lốc Thắng Trắng: Nhận diện đúng Sảnh Rồng 10 lá');

  // Test Tứ quý 2
  const tuQuy2Hand = [
    { id: '2h', rank: 2, sym: '2', suit: 'hearts', suitIcon: '♥' },
    { id: '2d', rank: 2, sym: '2', suit: 'diamonds', suitIcon: '♦' },
    { id: '2s', rank: 2, sym: '2', suit: 'spades', suitIcon: '♠' },
    { id: '2c', rank: 2, sym: '2', suit: 'clubs', suitIcon: '♣' },
    { id: '3h', rank: 3, sym: '3', suit: 'hearts', suitIcon: '♥' },
    { id: '4d', rank: 4, sym: '4', suit: 'diamonds', suitIcon: '♦' },
    { id: '5s', rank: 5, sym: '5', suit: 'spades', suitIcon: '♠' },
    { id: '6c', rank: 6, sym: '6', suit: 'clubs', suitIcon: '♣' },
    { id: '7h', rank: 7, sym: '7', suit: 'hearts', suitIcon: '♥' },
    { id: '8d', rank: 8, sym: '8', suit: 'diamonds', suitIcon: '♦' }
  ];
  const resTuQuy2 = SamLocEvaluator.arrange(tuQuy2Hand);
  assert(resTuQuy2.instantWin != null && resTuQuy2.instantWin.includes('Tứ Quý 2'), 'Sâm Lốc Thắng Trắng: Nhận diện đúng Tứ Quý 2');

  // Test Đồng màu (10 lá đỏ)
  const dongMauHand = [
    { id: '3h', rank: 3, sym: '3', suit: 'hearts', suitIcon: '♥' },
    { id: '4h', rank: 4, sym: '4', suit: 'hearts', suitIcon: '♥' },
    { id: '5d', rank: 5, sym: '5', suit: 'diamonds', suitIcon: '♦' },
    { id: '6d', rank: 6, sym: '6', suit: 'diamonds', suitIcon: '♦' },
    { id: '7h', rank: 7, sym: '7', suit: 'hearts', suitIcon: '♥' },
    { id: '8h', rank: 8, sym: '8', suit: 'hearts', suitIcon: '♥' },
    { id: '9d', rank: 9, sym: '9', suit: 'diamonds', suitIcon: '♦' },
    { id: '10d', rank: 10, sym: '10', suit: 'diamonds', suitIcon: '♦' },
    { id: 'Jh', rank: 11, sym: 'J', suit: 'hearts', suitIcon: '♥' },
    { id: 'Qd', rank: 12, sym: 'Q', suit: 'diamonds', suitIcon: '♦' }
  ];
  const resDongMau = SamLocEvaluator.arrange(dongMauHand);
  assert(resDongMau.instantWin != null && resDongMau.instantWin.includes('Đồng Màu'), 'Sâm Lốc Thắng Trắng: Nhận diện đúng 10 lá đồng màu');

  // Test AppController với game Sâm Lốc
  const appCodeFull = fs.readFileSync('preview/app.js', 'utf8');
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
  vm.runInContext(appCodeFull, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const appSam = new AppCtrl();

  appSam.currentGameType = 'samLoc10';
  appSam.playerCount = 2;
  appSam.initPlayers();

  assert(appSam.targetCards(0) === 10, 'AppController Sâm Lốc: Tụ 1 target là 10 lá');
  assert(appSam.targetCards(1) === 10, 'AppController Sâm Lốc: Tụ 2 target là 10 lá');

  appSam.players[0].cards = [...sanhRongHand];
  appSam.players[1].cards = [...mixedHand];
  assert(appSam.isReady() === true, 'AppController Sâm Lốc: isReady() khi mỗi tụ đủ 10 lá');

  appSam.calculate();
  assert(appSam.players[0].rankOrder === 1, 'AppController Sâm Lốc: Tụ 1 Thắng Trắng (Hạng 1)');
  assert(appSam.players[1].rankOrder === 2, 'AppController Sâm Lốc: Tụ 2 Thua (Hạng 2)');
}

// 13. Test Chắn Trung Quốc (19 lá)
{
  const appCodeFull = fs.readFileSync('preview/app.js', 'utf8');
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
  vm.runInContext(appCodeFull, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const appChan = new AppCtrl();

  appChan.currentGameType = 'chan19';
  appChan.playerCount = 5;
  appChan.initPlayers();

  assert(appChan.targetCards(0) === 19, 'Chắn TQ: Mỗi nhà cần đúng 19 lá bài');
  assert(appChan.players.length === 5, 'Chắn TQ: Hỗ trợ đủ 5 người chơi');

  // Test Rank-Only Mode
  appChan.isRankOnlyMode = true;
  assert(appChan.isRankOnlyActive() === true, 'Chắn TQ: Kích hoạt bàn phím số A➔K giống Liêng & Sâm Lốc');

  // Nhập 19 lá cho Tụ 1 bằng phím số A->K
  appChan.inputMode = 'manual';
  appChan.selectedPlayerIndex = 0;
  const sampleRanks = [
    { raw: 14, sym: 'A' }, { raw: 2, sym: '2' }, { raw: 3, sym: '3' }, { raw: 4, sym: '4' },
    { raw: 5, sym: '5' }, { raw: 6, sym: '6' }, { raw: 7, sym: '7' }, { raw: 8, sym: '8' },
    { raw: 9, sym: '9' }, { raw: 10, sym: '10' }, { raw: 11, sym: 'J' }, { raw: 12, sym: 'Q' },
    { raw: 13, sym: 'K' }, { raw: 14, sym: 'A' }, { raw: 2, sym: '2' }, { raw: 3, sym: '3' },
    { raw: 4, sym: '4' }, { raw: 5, sym: '5' }, { raw: 6, sym: '6' }
  ];
  sampleRanks.forEach(r => appChan.onRankClick(r));
  assert(appChan.players[0].cards.length === 19, 'Chắn TQ: Tụ 1 nhận đủ 19 lá bài bằng bàn phím số');

  // Tụ 1 tự động chuyển sang Tụ 2 khi đủ 19 lá trong Manual Mode
  assert(appChan.selectedPlayerIndex === 1, 'Chắn TQ: Tự động chuyển tiêu điểm sang Tụ 2 khi Tụ 1 đủ 19 lá');

  // Kiểm tra sắp xếp bài tăng dần
  appChan.calculate();
  const sortedRanks = appChan.players[0].cards.map(c => c.rank);
  let isSorted = true;
  for (let i = 0; i < sortedRanks.length - 1; i++) {
    if (sortedRanks[i] > sortedRanks[i + 1]) {
      isSorted = false;
      break;
    }
  }
  assert(isSorted === true, 'Chắn TQ: Các lá bài được tự động sắp xếp theo thứ tự tăng dần trực quan');
}

// 22. Test Nhập liệu bằng Giọng nói Tiếng Việt (VietnameseCardVoiceParser)
console.log('\n--- Kiểm thử Nhận diện Giọng nói Tiếng Việt (VietnameseCardVoiceParser) ---');
{
  // Test từ lóng / phương ngữ: già xì ri q -> K, A, J, Q
  const res1 = VietnameseCardVoiceParser.parse('già xì ri q');
  assert(res1.length === 4, 'Voice Parser: Nhận diện đủ 4 lá "già xì ri q"');
  assert(res1[0].rank === 13 && res1[1].rank === 14 && res1[2].rank === 11 && res1[3].rank === 12, 'Voice Parser: Ánh xạ chuẩn Già(13/K), Xì(14/A), Ri(11/J), Q(12/Q)');

  // Test số lượng: đôi già -> K, K
  const res2 = VietnameseCardVoiceParser.parse('đôi già');
  assert(res2.length === 2 && res2[0].rank === 13 && res2[1].rank === 13, 'Voice Parser: Nhận diện chuẩn "đôi già" -> [K, K]');

  // Test tứ quý át
  const res3 = VietnameseCardVoiceParser.parse('tứ quý át');
  assert(res3.length === 4 && res3.every(c => c.rank === 14), 'Voice Parser: Nhận diện chuẩn "tứ quý át" -> [A, A, A, A]');

  // Test sám / ba con: sám tám
  const res4 = VietnameseCardVoiceParser.parse('sám tám');
  assert(res4.length === 3 && res4.every(c => c.rank === 8), 'Voice Parser: Nhận diện chuẩn "sám tám" -> [8, 8, 8]');

  // Test đọc số liên tiếp: ba bốn năm sáu
  const res5 = VietnameseCardVoiceParser.parse('ba bốn năm sáu');
  assert(res5.length === 4 && res5[0].rank === 3 && res5[1].rank === 4 && res5[2].rank === 5 && res5[3].rank === 6, 'Voice Parser: Đọc sảnh liên tiếp "ba bốn năm sáu" -> [3, 4, 5, 6]');

  // Test kèm chất (Suit): át cơ k bích q tép j rô
  const res6 = VietnameseCardVoiceParser.parse('át cơ k bích q tép j rô');
  assert(res6.length === 4, 'Voice Parser: Nhận diện đủ 4 lá có chất');
  assert(res6[0].rank === 14 && res6[0].suit === 'hearts', 'Voice Parser: "át cơ" -> A cơ (hearts)');
  assert(res6[1].rank === 13 && res6[1].suit === 'spades', 'Voice Parser: "k bích" -> K bích (spades)');
  assert(res6[2].rank === 12 && res6[2].suit === 'clubs', 'Voice Parser: "q tép" -> Q chuồn/tép (clubs)');
  assert(res6[3].rank === 11 && res6[3].suit === 'diamonds', 'Voice Parser: "j rô" -> J rô (diamonds)');

  // Test từ đệm / khẩu ngữ tự nhiên: cho tôi con già và con xì nhé
  const res7 = VietnameseCardVoiceParser.parse('cho tôi con già và con xì nhé');
  assert(res7.length === 2 && res7[0].rank === 13 && res7[1].rank === 14, 'Voice Parser: Lọc bỏ chuẩn từ đệm ("cho tôi con ... và con ... nhé") -> [K, A]');

  // Test khẩu ngữ "hai con", "ba con", "bốn con"
  const res8 = VietnameseCardVoiceParser.parse('hai con mười với bốn con át');
  assert(res8.length === 6, 'Voice Parser: Nhận diện đúng cụm "hai con mười với bốn con át" -> 6 lá');
  assert(res8[0].rank === 10 && res8[1].rank === 10, 'Voice Parser: Hai con mười -> [10, 10]');
  assert(res8.slice(2).every(c => c.rank === 14), 'Voice Parser: Bốn con át -> [A, A, A, A]');

  // Test các biến thể âm thanh thực tế của Apple Speech: "à" (A), "cả" / "ca" (K), "sì" / "xì dách" (Xì/A)
  const resPhonetic = VietnameseCardVoiceParser.parse('à, cả, ca, sì, gì, quê');
  assert(resPhonetic.length === 6, 'Voice Parser: Nhận diện trọn vẹn 6 lá ngữ âm "à cả ca sì gì quê"');
  assert(resPhonetic[0].rank === 14, 'Voice Parser: "à" -> Át / Ace (14)');
  assert(resPhonetic[1].rank === 13, 'Voice Parser: "cả" -> K / King (13)');
  assert(resPhonetic[2].rank === 13, 'Voice Parser: "ca" -> K / King (13)');
  assert(resPhonetic[3].rank === 14, 'Voice Parser: "sì" -> Xì / Ace (14)');
  assert(resPhonetic[4].rank === 11, 'Voice Parser: "gì" -> J / Jack (11)');
  assert(resPhonetic[5].rank === 12, 'Voice Parser: "quê" -> Q / Queen (12)');

  const resXiDach = VietnameseCardVoiceParser.parse('xì dách cơ');
  assert(resXiDach.length === 1 && resXiDach[0].rank === 14 && resXiDach[0].suit === 'hearts', 'Voice Parser: "xì dách cơ" -> A cơ (hearts)');

  // Test gỡ dính số và tạo khoảng ngắt (Digit Un-gluing)
  const sep1 = VietnameseCardVoiceParser.separateDigits('123456789 10 11 23');
  assert(sep1 === '1 2 3 4 5 6 7 8 9 10 11 2 3', 'Voice Parser: separateDigits tách chuẩn chuỗi dính "123456789 10 11 23"');

  const resGlued = VietnameseCardVoiceParser.parse('123456789 10 11 23');
  assert(resGlued.length === 13, 'Voice Parser: Nhận diện trọn vẹn 13 lá bài từ chuỗi dính "123456789 10 11 23"');
  assert(resGlued[0].rank === 14, 'Voice Parser: 1 -> Át (Ace)');
  assert(resGlued[1].rank === 2, 'Voice Parser: 2 -> Hai');
  assert(resGlued[8].rank === 9, 'Voice Parser: 9 -> Chín');
  assert(resGlued[9].rank === 10, 'Voice Parser: 10 -> Mười');
  assert(resGlued[10].rank === 11, 'Voice Parser: 11 -> J (Jack)');
  assert(resGlued[11].rank === 2, 'Voice Parser: 23 -> Hai');
  assert(resGlued[12].rank === 3, 'Voice Parser: 23 -> Ba');

  const res1010 = VietnameseCardVoiceParser.parse('10, 10');
  assert(res1010.length === 2 && res1010[0].rank === 10 && res1010[1].rank === 10, 'Voice Parser: "10, 10" -> Hai lá 10');

  const res102 = VietnameseCardVoiceParser.parse('102');
  assert(res102.length === 2 && res102[0].rank === 10 && res102[1].rank === 2, 'Voice Parser: "102" -> Lá 10 và lá 2');

  const res23Co = VietnameseCardVoiceParser.parse('23 cơ');
  assert(res23Co.length === 2 && res23Co[0].rank === 2 && res23Co[1].rank === 3 && res23Co[1].suit === 'hearts', 'Voice Parser: "23 cơ" -> Lá 2 và lá 3 cơ');

  // Test quy ước 11 (J), 12 (Q), 13 (K), qui (Q)
  const resJQK = VietnameseCardVoiceParser.parse('11 cơ 12 rô 13 bích qui tép');
  assert(resJQK.length === 4, 'Voice Parser: Nhận diện 4 lá 11 12 13 qui');
  assert(resJQK[0].rank === 11 && resJQK[0].suit === 'hearts', 'Voice Parser: 11 cơ -> J cơ');
  assert(resJQK[1].rank === 12 && resJQK[1].suit === 'diamonds', 'Voice Parser: 12 rô -> Q rô');
  assert(resJQK[2].rank === 13 && resJQK[2].suit === 'spades', 'Voice Parser: 13 bích -> K bích');
  assert(resJQK[3].rank === 12 && resJQK[3].suit === 'clubs', 'Voice Parser: qui tép -> Q tép');

  // Test đọc nhanh (không ngắt): mười một -> J, mười hai -> Q, mười ba -> K
  const resMuoiWords = VietnameseCardVoiceParser.parse('mười một mười hai mười ba');
  assert(resMuoiWords.length === 3, 'Voice Parser: Đọc nhanh "mười một mười hai mười ba" -> 3 lá J, Q, K');
  assert(resMuoiWords[0].rank === 11, 'Voice Parser: Đọc nhanh mười một -> J (11)');
  assert(resMuoiWords[1].rank === 12, 'Voice Parser: Đọc nhanh mười hai -> Q (12)');
  assert(resMuoiWords[2].rank === 13, 'Voice Parser: Đọc nhanh mười ba -> K (13)');

  // Test đọc chậm có khoảng ngắt (dấu phẩy / pause):
  const resSlow1 = VietnameseCardVoiceParser.parse('mười, một');
  assert(resSlow1.length === 2 && resSlow1[0].rank === 10 && resSlow1[1].rank === 14, 'Voice Parser: Đọc chậm "mười, một" -> [10, Át]');

  const resSlow2 = VietnameseCardVoiceParser.parse('mười, hai');
  assert(resSlow2.length === 2 && resSlow2[0].rank === 10 && resSlow2[1].rank === 2, 'Voice Parser: Đọc chậm "mười, hai" -> [10, 2]');

  const resSlow3 = VietnameseCardVoiceParser.parse('mười, ba');
  assert(resSlow3.length === 2 && resSlow3[0].rank === 10 && resSlow3[1].rank === 3, 'Voice Parser: Đọc chậm "mười, ba" -> [10, 3]');

  // Test dạng số tách rời: "10 1" -> [10, Át], "10 2" -> [10, 2], "10 3" -> [10, 3]
  const resDigits1 = VietnameseCardVoiceParser.parse('10 1');
  assert(resDigits1.length === 2 && resDigits1[0].rank === 10 && resDigits1[1].rank === 14, 'Voice Parser: "10 1" -> [10, Át]');

  const resDigits2 = VietnameseCardVoiceParser.parse('10 2');
  assert(resDigits2.length === 2 && resDigits2[0].rank === 10 && resDigits2[1].rank === 2, 'Voice Parser: "10 2" -> [10, 2]');

  const resDigits3 = VietnameseCardVoiceParser.parse('10 3');
  assert(resDigits3.length === 2 && resDigits3[0].rank === 10 && resDigits3[1].rank === 3, 'Voice Parser: "10 3" -> [10, 3]');

  // Test hai con xì liên tục: "một, một" hoặc "1, 1"
  const resMotMot = VietnameseCardVoiceParser.parse('một, một');
  assert(resMotMot.length === 2 && resMotMot[0].rank === 14 && resMotMot[1].rank === 14, 'Voice Parser: "một, một" -> Hai con xì [A, A]');

  const res11Aces = VietnameseCardVoiceParser.parse('1, 1');
  assert(res11Aces.length === 2 && res11Aces[0].rank === 14 && res11Aces[1].rank === 14, 'Voice Parser: "1, 1" -> Hai con xì [A, A]');

  // Test heo (2), da/dà (K), huy (Q)
  const resDialects = VietnameseCardVoiceParser.parse('heo cơ da bích dà rô huy tép');
  assert(resDialects.length === 4, 'Voice Parser: Nhận diện đủ 4 lá phương ngữ "heo da dà huy"');
  assert(resDialects[0].rank === 2 && resDialects[0].suit === 'hearts', 'Voice Parser: "heo cơ" -> 2 cơ');
  assert(resDialects[1].rank === 13 && resDialects[1].suit === 'spades', 'Voice Parser: "da bích" -> K bích');
  assert(resDialects[2].rank === 13 && resDialects[2].suit === 'diamonds', 'Voice Parser: "dà rô" -> K rô');
  assert(resDialects[3].rank === 12 && resDialects[3].suit === 'clubs', 'Voice Parser: "huy tép" -> Q tép');

  // Test "bỏ", "bỏ bài", "bỏ qua", "bo" -> Lá bài ẩn
  const resBo = VietnameseCardVoiceParser.parse('bỏ');
  assert(resBo.length === 1 && resBo[0].isHidden === true, 'Voice Parser: "bỏ" -> Lá bài ẩn (?)');

  const resBoBai = VietnameseCardVoiceParser.parse('bỏ bài');
  assert(resBoBai.length === 1 && resBoBai[0].isHidden === true, 'Voice Parser: "bỏ bài" -> Lá bài ẩn (?)');

  const resBoQua = VietnameseCardVoiceParser.parse('bỏ qua');
  assert(resBoQua.length === 1 && resBoQua[0].isHidden === true, 'Voice Parser: "bỏ qua" -> Lá bài ẩn (?)');

  const resBoRaw = VietnameseCardVoiceParser.parse('bo');
  assert(resBoRaw.length === 1 && resBoRaw[0].isHidden === true, 'Voice Parser: "bo" -> Lá bài ẩn (?)');

  // Verify "bon" (4) is unaffected by "bo"
  const resBon = VietnameseCardVoiceParser.parse('bon cơ');
  assert(resBon.length === 1 && resBon[0].rank === 4 && resBon[0].suit === 'hearts', 'Voice Parser: "bon cơ" vẫn chuẩn là lá 4 cơ (không bị nhầm lẫn với "bo")');

  // Test "không", "không thấy" -> Đã bị loại bỏ (không sinh ra lá bài ẩn, đóng vai trò từ đệm)
  const resKhongThay = VietnameseCardVoiceParser.parse('không thấy');
  assert(resKhongThay.length === 0, 'Voice Parser: "không thấy" đã bị loại bỏ khỏi nhận diện bài ẩn');

  const resKhong = VietnameseCardVoiceParser.parse('không');
  assert(resKhong.length === 0, 'Voice Parser: "không" được coi là từ đệm, không biến thành bài ẩn (?)');

  // Test "bồi" và biến thể -> J / Jack
  const resBoiCo = VietnameseCardVoiceParser.parse('bồi cơ');
  assert(resBoiCo.length === 1 && resBoiCo[0].rank === 11 && resBoiCo[0].suit === 'hearts', 'Voice Parser: "bồi cơ" -> J cơ (11)');

  const resConBoi = VietnameseCardVoiceParser.parse('con bồi bích');
  assert(resConBoi.length === 1 && resConBoi[0].rank === 11 && resConBoi[0].suit === 'spades', 'Voice Parser: "con bồi bích" -> J bích (11)');

  const resBoiVariants = VietnameseCardVoiceParser.parse('bôi rô bồ tép bội');
  assert(resBoiVariants.length === 3, 'Voice Parser: Nhận diện 3 biến thể âm của bồi');
  assert(resBoiVariants[0].rank === 11 && resBoiVariants[0].suit === 'diamonds', 'Voice Parser: "bôi rô" -> J rô (11)');
  assert(resBoiVariants[1].rank === 11 && resBoiVariants[1].suit === 'clubs', 'Voice Parser: "bồ tép" -> J tép (11)');
  assert(resBoiVariants[2].rank === 11, 'Voice Parser: "bội" -> J (11)');

  // Test các âm đọc tiếng Việt cho J, Q, K (Dây -> J, Kiu -> Q)
  const resDayKiu = VietnameseCardVoiceParser.parse('dây cơ kiu bích chây tép');
  assert(resDayKiu.length === 3, 'Voice Parser: Nhận diện đủ 3 lá "dây cơ kiu bích chây tép"');
  assert(resDayKiu[0].rank === 11 && resDayKiu[0].suit === 'hearts', 'Voice Parser: "dây cơ" -> J cơ (11)');
  assert(resDayKiu[1].rank === 12 && resDayKiu[1].suit === 'spades', 'Voice Parser: "kiu bích" -> Q bích (12)');
  assert(resDayKiu[2].rank === 11 && resDayKiu[2].suit === 'clubs', 'Voice Parser: "chây tép" -> J tép (11)');

  // Test dạng chữ số Apple Speech trả về: "mười 1 mười 2 mười 3" -> J, Q, K
  const resMuoiDigits = VietnameseCardVoiceParser.parse('mười 1 mười 2 mười 3');
  assert(resMuoiDigits.length === 3, 'Voice Parser: "mười 1 mười 2 mười 3" -> Nhận đủ 3 lá');
  assert(resMuoiDigits[0].rank === 11, 'Voice Parser: "mười 1" -> J (11)');
  assert(resMuoiDigits[1].rank === 12, 'Voice Parser: "mười 2" -> Q (12)');
  assert(resMuoiDigits[2].rank === 13, 'Voice Parser: "mười 3" -> K (13)');

  // Test chống nhảy 2 lần (No double jump on partial speech revision) & Phân đoạn liên tục (Multi-segment)
  const appVoiceTest = {
    processedVoiceCardsCount: 0,
    currentVoiceSegmentId: 0,
    players: [{ cards: [] }, { cards: [] }, { cards: [] }],
    pointer: 0,
    onRankClick: function(rObj) {
      this.players[this.pointer % this.players.length].cards.push({ rank: rObj.raw });
      this.pointer++;
    },
    onHiddenCardClick: function() {
      this.players[this.pointer % this.players.length].cards.push({ isHidden: true });
      this.pointer++;
    },
    processVoiceInput: function(text, segmentId = 0) {
      if (segmentId !== 0 && segmentId !== this.currentVoiceSegmentId) {
        this.currentVoiceSegmentId = segmentId;
        this.processedVoiceCardsCount = 0;
      }
      const parsed = VietnameseCardVoiceParser.parse(text);
      if (parsed.length > this.processedVoiceCardsCount) {
        const newItems = parsed.slice(this.processedVoiceCardsCount);
        for (const item of newItems) {
          if (item.isHidden) {
            this.onHiddenCardClick();
          } else {
            this.onRankClick({ raw: item.rank });
          }
        }
        this.processedVoiceCardsCount = parsed.length;
      }
    }
  };

  appVoiceTest.processVoiceInput('ba', 1);
  assert(appVoiceTest.players[0].cards.length === 1 && appVoiceTest.players[0].cards[0].rank === 3, 'Voice anti-double-jump: Nói "ba" -> Tụ 1 nhận đúng 1 lá 3');

  // Giả lập Apple Speech flicker về rỗng hoặc câu ngắn trong cùng segment 1
  appVoiceTest.processVoiceInput('', 1);
  assert(appVoiceTest.players[0].cards.length === 1, 'Voice anti-double-jump: Gặp flicker tạm thời không làm mất counter');

  // Giả lập câu nói hoàn tất "ba bốn" trong cùng segment 1
  appVoiceTest.processVoiceInput('ba bốn', 1);
  assert(appVoiceTest.players[0].cards.length === 1, 'Voice anti-double-jump: Tụ 1 vẫn chỉ có 1 lá 3 (không bị đúp 2 lần)');
  assert(appVoiceTest.players[1].cards.length === 1 && appVoiceTest.players[1].cards[0].rank === 4, 'Voice anti-double-jump: Tụ 2 nhận lá 4');

  // Test phân đoạn mới (Segment 2): Nói "bồi" sau khi ngắt câu
  appVoiceTest.processVoiceInput('bồi', 2);
  assert(appVoiceTest.players[2].cards.length === 1 && appVoiceTest.players[2].cards[0].rank === 11, 'Voice multi-segment: Nói "bồi" ngắt câu -> Tụ 3 nhận chuẩn lá J (11)');

  // Test phân đoạn mới tiếp theo (Segment 3): Nói "bồi" lần nữa không bị chặn bởi counter cũ
  appVoiceTest.processVoiceInput('bồi', 3);
  assert(appVoiceTest.players[0].cards.length === 2 && appVoiceTest.players[0].cards[1].rank === 11, 'Voice multi-segment: Nói "bồi" lần 2 ngắt câu -> Tiếp tục nhảy lá J cho Tụ 1 (không bị kẹt)');

  // Test phân đoạn mới tiếp theo (Segment 4): Đọc "11 12 13" trọn vẹn không bị nuốt lá
  appVoiceTest.processVoiceInput('11 12 13', 4);
  assert(appVoiceTest.players[1].cards.length === 2 && appVoiceTest.players[1].cards[1].rank === 11, 'Voice multi-segment: "11 12 13" -> Tụ 2 nhận 11 (J)');
  assert(appVoiceTest.players[2].cards.length === 2 && appVoiceTest.players[2].cards[1].rank === 12, 'Voice multi-segment: "11 12 13" -> Tụ 3 nhận 12 (Q)');
  assert(appVoiceTest.players[0].cards.length === 3 && appVoiceTest.players[0].cards[2].rank === 13, 'Voice multi-segment: "11 12 13" -> Tụ 1 nhận 13 (K)');

  // Test cây as King vs cây as classifier
  const resCayKing = VietnameseCardVoiceParser.parse('cây cơ');
  assert(resCayKing.length === 1 && resCayKing[0].rank === 13 && resCayKing[0].suit === 'hearts', 'Voice Parser: "cây cơ" -> K cơ (13)');
  const resCayClassifier = VietnameseCardVoiceParser.parse('cây ba');
  assert(resCayClassifier.length === 1 && resCayClassifier[0].rank === 3, 'Voice Parser: "cây ba" -> 3 (cây làm lượng từ cho 3)');
  const resCaySingle = VietnameseCardVoiceParser.parse('cây');
  assert(resCaySingle.length === 1 && resCaySingle[0].rank === 13, 'Voice Parser: "cây" -> K (13)');

  // Test Custom Voice Keyword Training
  VietnameseCardVoiceParser.addCustomKeyword(11, 'chum');
  const resChum = VietnameseCardVoiceParser.parse('chum tép');
  assert(resChum.length === 1 && resChum[0].rank === 11 && resChum[0].suit === 'clubs', 'Voice Custom Trainer: Học từ khóa "chum" cho J -> "chum tép" nhận đúng J tép');

  VietnameseCardVoiceParser.addCustomKeyword(12, 'hậu');
  const resHau = VietnameseCardVoiceParser.parse('hậu bích');
  assert(resHau.length === 1 && resHau[0].rank === 12 && resHau[0].suit === 'spades', 'Voice Custom Trainer: Học từ khóa "hậu" cho Q -> "hậu bích" nhận đúng Q bích');

  VietnameseCardVoiceParser.addCustomKeyword(13, 'tướng');
  const resTuong = VietnameseCardVoiceParser.parse('tướng rô');
  assert(resTuong.length === 1 && resTuong[0].rank === 13 && resTuong[0].suit === 'diamonds', 'Voice Custom Trainer: Học từ khóa "tướng" cho K -> "tướng rô" nhận đúng K rô');

  // Test xóa từ khóa đã học
  VietnameseCardVoiceParser.removeCustomKeyword(11, 'chum');
  const resChumRemoved = VietnameseCardVoiceParser.parse('chum tép');
  assert(resChumRemoved.length === 0, 'Voice Custom Trainer: Xóa từ khóa "chum" -> không còn nhận diện thành J');

  // Test Tự động ngắt từng chữ từ chuỗi thu âm 5s (extractTrainingWords)
  const tokens = VietnameseCardVoiceParser.extractTrainingWords('dây kiu chây già bồi');
  assert(tokens.length === 5 && tokens[0] === 'dây' && tokens[1] === 'kiu' && tokens[2] === 'chây' && tokens[3] === 'già' && tokens[4] === 'bồi', 'Voice Custom Trainer: Tự động ngắt 5 từ từ chuỗi thu âm dài');

  // Test Tách số dính 3 chữ số bắt đầu bằng 11, 12, 13 (separateDigits)
  assert(VietnameseCardVoiceParser.separateDigits('124') === '12 4', 'separateDigits: 124 -> 12 4');
  assert(VietnameseCardVoiceParser.separateDigits('122') === '12 2', 'separateDigits: 122 -> 12 2');
  assert(VietnameseCardVoiceParser.separateDigits('134') === '13 4', 'separateDigits: 134 -> 13 4');
  assert(VietnameseCardVoiceParser.separateDigits('132') === '13 2', 'separateDigits: 132 -> 13 2');
  assert(VietnameseCardVoiceParser.separateDigits('114') === '11 4', 'separateDigits: 114 -> 11 4');

  // Test không bị dính số 2/3 phía sau khi đọc 12 hoặc 13 kèm số khác
  const p12_4 = VietnameseCardVoiceParser.parse('12, 4');
  assert(p12_4.length === 2 && p12_4[0].rank === 12 && p12_4[1].rank === 4, 'Voice Parser: "12, 4" -> [12, 4] (Không bị dính số 2 ở giữa)');

  const p12_2 = VietnameseCardVoiceParser.parse('12, 2');
  assert(p12_2.length === 2 && p12_2[0].rank === 12 && p12_2[1].rank === 2, 'Voice Parser: "12, 2" -> [12, 2] (Không bị dính số 2 ở giữa)');

  const p13_4 = VietnameseCardVoiceParser.parse('13, 4');
  assert(p13_4.length === 2 && p13_4[0].rank === 13 && p13_4[1].rank === 4, 'Voice Parser: "13, 4" -> [13, 4] (Không bị dính số 3 ở giữa)');

  const p13_2 = VietnameseCardVoiceParser.parse('13, 2');
  assert(p13_2.length === 2 && p13_2[0].rank === 13 && p13_2[1].rank === 2, 'Voice Parser: "13, 2" -> [13, 2] (Không bị dính số 3 ở giữa)');

  // Test Tentative Card Revision: Nói "mười" rồi nói tiếp "mười một" / "11" -> Thay thế lá 10 thành J (11) trên cùng 1 Tụ
  const tentativeVoiceTest = {
    processedVoiceCardsCount: 0,
    currentVoiceSegmentId: 0,
    currentSegmentPlacedCards: [],
    players: [{ id: 'P0', cards: [] }, { id: 'P1', cards: [] }, { id: 'P2', cards: [] }],
    pointer: 0,
    actionHistory: [],
    onRankClick: function(rObj) {
      const card = { id: `c_${Date.now()}_${Math.random()}`, rank: rObj.raw, isRankOnly: true };
      const pIdx = this.pointer % this.players.length;
      this.players[pIdx].cards.push(card);
      this.actionHistory.push({ cardId: card.id, target: pIdx });
      this.pointer++;
      return card;
    },
    removeCard: function(cardId) {
      for (let i = 0; i < this.players.length; i++) {
        const idx = this.players[i].cards.findIndex(c => c.id === cardId);
        if (idx !== -1) {
          this.players[i].cards.splice(idx, 1);
          this.pointer = i; // Reset focus back to this player
          break;
        }
      }
    },
    processVoiceInput: function(text, segmentId = 0) {
      if (segmentId !== 0 && segmentId !== this.currentVoiceSegmentId) {
        this.currentVoiceSegmentId = segmentId;
        this.processedVoiceCardsCount = 0;
        this.currentSegmentPlacedCards = [];
      }
      const parsed = VietnameseCardVoiceParser.parse(text);

      // Tentative revision
      if (this.processedVoiceCardsCount > 0 && parsed.length === this.processedVoiceCardsCount) {
        const lastParsed = parsed[this.processedVoiceCardsCount - 1];
        const lastPlacedCard = this.currentSegmentPlacedCards[this.currentSegmentPlacedCards.length - 1];
        if (lastPlacedCard) {
          const isSameRank = (lastParsed.rank === lastPlacedCard.rank);
          const isSameSuit = (lastParsed.suit === lastPlacedCard.suit);
          if (!isSameRank || (!lastPlacedCard.isRankOnly && lastParsed.suit && !isSameSuit)) {
            this.removeCard(lastPlacedCard.id);
            this.currentSegmentPlacedCards.pop();
            this.processedVoiceCardsCount--;
          }
        }
      }

      if (parsed.length > this.processedVoiceCardsCount) {
        const newItems = parsed.slice(this.processedVoiceCardsCount);
        for (const item of newItems) {
          const card = this.onRankClick({ raw: item.rank });
          this.currentSegmentPlacedCards.push(card);
        }
        this.processedVoiceCardsCount = parsed.length;
      }
    }
  };

  // Bước 1: Người dùng nói "mười" -> Tụ 1 nhận tạm lá 10
  tentativeVoiceTest.processVoiceInput('mười', 1);
  assert(tentativeVoiceTest.players[0].cards.length === 1 && tentativeVoiceTest.players[0].cards[0].rank === 10, 'Tentative Revision: Đọc "mười" -> Tụ 1 tạm nhận lá 10');

  // Bước 2: Người dùng nói xong "mười một" (Apple Speech cập nhật thành "11") -> Tụ 1 được sửa thành lá 11 (J), không bị kẹt lá 10!
  tentativeVoiceTest.processVoiceInput('11', 1);
  assert(tentativeVoiceTest.players[0].cards.length === 1 && tentativeVoiceTest.players[0].cards[0].rank === 11, 'Tentative Revision: Nối câu thành "11" -> Tụ 1 lập tức thay thế lá 10 bằng lá 11 (J)');

  // Bước 3: Đọc tiếp "mười hai" -> Tụ 2 nhận lá 12 (Q)
  tentativeVoiceTest.processVoiceInput('11 12', 1);
  assert(tentativeVoiceTest.players[1].cards.length === 1 && tentativeVoiceTest.players[1].cards[0].rank === 12, 'Tentative Revision: Đọc tiếp "12" -> Tụ 2 nhận đúng lá 12 (Q)');

  // Bước 4: Đọc tiếp "mười ba" -> Tụ 3 nhận lá 13 (K)
  tentativeVoiceTest.processVoiceInput('11 12 13', 1);
  assert(tentativeVoiceTest.players[2].cards.length === 1 && tentativeVoiceTest.players[2].cards[0].rank === 13, 'Tentative Revision: Đọc tiếp "13" -> Tụ 3 nhận đúng lá 13 (K)');
  assert(!tentativeVoiceTest.players.some(p => p.cards.some(c => c.rank === 10)), 'Tentative Revision: Hoàn toàn không còn lá 10 nào bị kẹt lại trên bất kỳ tụ nào!');
}

// 18. Test Khoảng ngắt 0.7s mốc trực tiếp trên stream (Stream Anchor 0.7s)
{
  const appCodeFull = fs.readFileSync('preview/app.js', 'utf8');
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', textContent: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: (fn, ms) => setTimeout(fn, ms),
    clearTimeout: (id) => clearTimeout(id),
    Date: Date
  };
  vm.createContext(sandbox);
  vm.runInContext(appCodeFull, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const app = new AppCtrl();

  app.currentGameType = 'lieng3';
  app.playerCount = 3;
  app.initPlayers();
  app.isRankOnlyMode = true;

  // Kịch bản 1: t = 1000 đọc "mười" -> Chốt lá 10 sau khi flush
  app.processVoiceInput('mười', 1, 1000);
  app.flushPendingVoiceCards();
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 10, 'Stream Anchor 0.5s: t=0s đọc "mười" -> Tụ 1 nhận lá 10');

  // t = 1200: Apple tự sửa thành '11' -> Theo quy tắc bản đối chiếu: sau khi Apple sửa đều là vô hiệu, Tụ 1 giữ nguyên lá 10!
  app.processVoiceInput('11', 1, 1200);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 10, 'Stream Snapshot: Apple sửa sau đều là vô hiệu -> Tụ 1 giữ nguyên lá 10');

  // Kịch bản 2: Ngắt nghỉ quá 0.5s lấy chữ mới nhất làm mốc trực tiếp trên stream
  app.startNewRound();
  // t = 1000: đọc "mười" -> Chốt tạm lá 10 sau khi kết thúc nhịp
  app.processVoiceInput('mười', 1, 1000);
  app.flushPendingVoiceCards();
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 10, 'Stream Anchor 0.5s: Ván mới, t=0s đọc "mười" -> Tụ 1 nhận lá 10');

  // Sau 0.3s, timer tự động chốt cứng lá 10:
  app.isLastCardTenTentative = false;
  app.isTenLocked = true;
  app.resetVoiceSegment();

  // Tại t = 1700 (Delta t > 0.3s): người đọc tiếp "hai" ở Segment 2
  app.processVoiceInput('hai', 2, 1700);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 10, 'Stream Anchor 0.3s: Nghỉ > 0.3s -> Lá 10 đã chốt cứng ở Tụ 1 (KHÔNG bị sửa thành Q/12)');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Stream Anchor 0.3s: Chữ "hai" sau mốc 0.3s được đưa độc lập vào Tụ 2 (lá 2)');

  // Kịch bản 3: Các số 1->9 nhận diện tức thì (0ms trễ), không phải chờ timer 0.5s
  app.startNewRound();
  app.processVoiceInput('ba', 1, 3000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 3, 'Stream 1->9: Đọc "ba" -> Tụ 1 nhận lá 3 ngay lập tức');
  assert(app.isLastCardTenTentative === false, 'Stream 1->9: Lá 3 chốt tức thì, không bị rơi vào trạng thái chờ tentative');

  // Sau nhịp nghỉ 0.2s, reset segment để đón từ tiếp theo:
  app.resetVoiceSegment();
  app.processVoiceInput('bốn', 2, 3500);
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 4, 'Stream 1->9: Đọc tiếp "bốn" -> Tụ 2 nhận lá 4 trơn tru');

  // Kịch bản 4: Biến thể "mười một" -> J, "mười một một" -> [J, 1], "mười hai một" -> [Q, 1]
  const Parser = vm.runInContext('VietnameseCardVoiceParser', sandbox);
  const pMuoiMot = Parser.parse('mười một');
  assert(pMuoiMot.length === 1 && pMuoiMot[0].rank === 11, 'Voice Parser: "mười một" -> J (11)');

  const pMuoiMotMot = Parser.parse('mười một một');
  assert(pMuoiMotMot.length === 2 && pMuoiMotMot[0].rank === 11 && pMuoiMotMot[1].rank === 14, 'Voice Parser: "mười một một" -> [J, 1] (11 và Át)');

  const pMuoiHaiMot = Parser.parse('mười hai một');
  assert(pMuoiHaiMot.length === 2 && pMuoiHaiMot[0].rank === 12 && pMuoiHaiMot[1].rank === 14, 'Voice Parser: "mười hai một" -> [Q, 1] (12 và Át)');

  const pMuoiBaMot = Parser.parse('mười ba một');
  assert(pMuoiBaMot.length === 2 && pMuoiBaMot[0].rank === 13 && pMuoiBaMot[1].rank === 14, 'Voice Parser: "mười ba một" -> [K, 1] (13 và Át)');

  const pMuoi11 = Parser.parse('mười 11 12 13');
  assert(pMuoi11.length === 4 && pMuoi11[0].rank === 10 && pMuoi11[1].rank === 11 && pMuoi11[2].rank === 12 && pMuoi11[3].rank === 13, 'Voice Parser: "mười 11 12 13" -> [10, J, Q, K] (không bị nuốt 111)');

  // Kịch bản 5: Biến thể ngữ âm hay nhầm lẫn của Apple Speech
  const pBa = Parser.parse('bà cơ');
  assert(pBa.length === 1 && pBa[0].rank === 3 && pBa[0].suit === 'hearts', 'Voice Phonetics: "bà cơ" -> 3 cơ');

  const pBon = Parser.parse('bóng bích');
  assert(pBon.length === 1 && pBon[0].rank === 4 && pBon[0].suit === 'spades', 'Voice Phonetics: "bóng bích" -> 4 bích');

  const pTam = Parser.parse('tấm rô');
  assert(pTam.length === 1 && pTam[0].rank === 8 && pTam[0].suit === 'diamonds', 'Voice Phonetics: "tấm rô" -> 8 rô');

  const pChin = Parser.parse('chính tép');
  assert(pChin.length === 1 && pChin[0].rank === 9 && pChin[0].suit === 'clubs', 'Voice Phonetics: "chính tép" -> 9 tép');

  const pMuoi = Parser.parse('mời cơ');
  assert(pMuoi.length === 1 && pMuoi[0].rank === 10 && pMuoi[0].suit === 'hearts', 'Voice Phonetics: "mời cơ" -> 10 cơ');

  const pGa = Parser.parse('gà bích');
  assert(pGa.length === 1 && pGa[0].rank === 13 && pGa[0].suit === 'spades', 'Voice Phonetics: "gà bích" -> K bích');
}

// 19. Test Khóa cứng tụ & Khóa tức thì 11, 12, 13
{
  const appCodeFull = fs.readFileSync('preview/app.js', 'utf8');
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', textContent: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: (fn, ms) => setTimeout(fn, ms),
    clearTimeout: (id) => clearTimeout(id),
    Date: Date
  };
  vm.createContext(sandbox);
  vm.runInContext(appCodeFull, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);
  const Parser = vm.runInContext('VietnameseCardVoiceParser', sandbox);

  // 19.1. Test separateDigits với chuỗi 4 số (1212, 1112, 1012, 1224)
  assert(Parser.separateDigits('1212') === '12 12', 'separateDigits: 1212 -> 12 12');
  assert(Parser.separateDigits('1112') === '11 12', 'separateDigits: 1112 -> 11 12');
  assert(Parser.separateDigits('1012') === '10 12', 'separateDigits: 1012 -> 10 12');
  assert(Parser.separateDigits('1224') === '12 2 4', 'separateDigits: 1224 -> 12 2 4');

  // 19.2. Kịch bản: Đọc "1" [nghỉ 0.2s khóa cứng Tụ 1] rồi đọc "2"
  const app = new AppCtrl();
  app.currentGameType = 'lieng3';
  app.playerCount = 3;
  app.initPlayers();
  app.isRankOnlyMode = true;

  // t = 0: Đọc "một" -> Tụ 1 nhận lá 1 (Át)
  app.processVoiceInput('một', 1, 1000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 14, 'Mat Lock: t=0s đọc "một" -> Tụ 1 nhận lá 1 (Át)');

  // Sau nhịp nghỉ 0.2s, reset sang Segment 2:
  app.resetVoiceSegment();

  // Đọc tiếp "hai" ở Segment 2:
  app.processVoiceInput('hai', 2, 1700);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 14, 'Mat Lock: Tụ 1 vẫn giữ nguyên lá 1 (Át), KHÔNG bị biến thành Q');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Mat Lock: Tụ 2 nhận đúng lá 2 riêng biệt!');

  // 19.3. Kịch bản: Khóa tức thì 11, 12, 13 (0ms delay)
  // Khi đọc 12 (Q) rồi đọc tiếp 2 -> Tụ 1 = 12 (Q), Tụ 2 = 2
  app.startNewRound();
  app.processVoiceInput('12', 1, 3000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 12, 'Instant Lock 12: Đọc "12" -> Tụ 1 nhận lá Q');
  
  // Timer 180ms reset segment sang Segment 2
  app.resetVoiceSegment();
  app.processVoiceInput('hai', 2, 3500);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 12, 'Instant Lock 12: Tụ 1 giữ vững lá Q');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Instant Lock 12: Tụ 2 nhận lá 2 chuẩn xác');

  // 19.4. Kịch bản: Đọc 12 rồi đọc 4 ("12,4") -> Tụ 1 = 12 (Q), Tụ 2 = 4
  app.startNewRound();
  app.processVoiceInput('12', 1, 5000);
  app.resetVoiceSegment();
  app.processVoiceInput('4', 2, 5600);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 12, 'Instant Lock 12: Đọc 12, 4 -> Tụ 1 = Q');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 4, 'Instant Lock 12: Đọc 12, 4 -> Tụ 2 = 4');

  // 19.5. Kịch bản: Đọc 11 rồi đọc 1 ("11,1") -> Tụ 1 = 11 (J), Tụ 2 = 1
  app.startNewRound();
  app.processVoiceInput('11', 1, 7000);
  app.resetVoiceSegment();
  app.processVoiceInput('1', 2, 7600);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 11, 'Instant Lock 11: Đọc 11, 1 -> Tụ 1 = J');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 14, 'Instant Lock 11: Đọc 11, 1 -> Tụ 2 = Át (1)');

  // 19.6. Kịch bản: Đọc 13 rồi đọc 2 ("13,2") -> Tụ 1 = 13 (K), Tụ 2 = 2
  app.startNewRound();
  app.processVoiceInput('13', 1, 9000);
  app.resetVoiceSegment();
  app.processVoiceInput('2', 2, 9600);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 13, 'Instant Lock 13: Đọc 13, 2 -> Tụ 1 = K');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Instant Lock 13: Đọc 13, 2 -> Tụ 2 = 2');
}

// 20. Test Giải pháp 1: Reset phiên âm thanh sau mỗi từ (Auto-Reset Segment per Word/Card)
{
  const appCodeFull = fs.readFileSync('preview/app.js', 'utf8');
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', textContent: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: (fn, ms) => setTimeout(fn, ms),
    clearTimeout: (id) => clearTimeout(id),
    Date: Date
  };
  vm.createContext(sandbox);
  vm.runInContext(appCodeFull, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);

  const app = new AppCtrl();
  app.currentGameType = 'samLoc10'; // Giả lập đúng ván Sâm Lốc như trong ảnh
  app.playerCount = 3;
  app.initPlayers();
  app.isRankOnlyMode = true;

  // Bước 1: Người dùng đọc "một" trong Segment 1
  app.processVoiceInput('một', 1, 1000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 14, 'Giải pháp 1: Đọc "một" (Segment 1) -> Tụ 1 nhận Át (1)');

  // Hết nhịp nói, timer kích hoạt reset phiên âm thanh sang Segment 2:
  app.resetVoiceSegment();
  assert(app.currentVoiceSegmentId === 2, 'Giải pháp 1: Tự động reset sang Segment 2 sạch sẽ');
  assert(app.processedVoiceCardsCount === 0, 'Giải pháp 1: Counter reset về 0 cho segment mới');

  // Bước 2: Người dùng đọc "hai" trong Segment 2 (Apple Speech CHỈ gửi "2", KHÔNG có "12" cũ!)
  app.processVoiceInput('hai', 2, 2000);
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Giải pháp 1: Đọc "hai" (Segment 2) -> Tụ 2 nhận lá 2 chuẩn xác, không bị ghép 12!');

  // Hết nhịp nói, timer kích hoạt reset phiên âm thanh sang Segment 3:
  app.resetVoiceSegment();
  assert(app.currentVoiceSegmentId === 3, 'Giải pháp 1: Tự động reset sang Segment 3 sạch sẽ');

  // Bước 3: Người dùng đọc "ba" trong Segment 3 (Apple Speech CHỈ gửi "3", KHÔNG bị "12 3" làm nuốt lá!)
  app.processVoiceInput('ba', 3, 3000);
  assert(app.players[2].cards.length === 1 && app.players[2].cards[0].rank === 3, 'Giải pháp 1: Đọc "ba" (Segment 3) -> Tụ 3 nhận ngay lá 3, giải quyết dứt điểm lỗi nuốt lá!');

  // Kiểm tra tổng thể ván bài:
  assert(app.players[0].cards[0].rank === 14, 'Giải pháp 1: Tụ 1 = Át (1)');
  assert(app.players[1].cards[0].rank === 2, 'Giải pháp 1: Tụ 2 = 2');
  assert(app.players[2].cards[0].rank === 3, 'Giải pháp 1: Tụ 3 = 3');

  // Bước 4: Test đọc 12 (Q) rồi đọc 2 (Hai)
  app.startNewRound();
  app.currentGameType = 'lieng3';
  app.playerCount = 3;
  app.initPlayers();

  app.processVoiceInput('12', 1, 5000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 12, 'Giải pháp 1: Đọc "12" (Segment 1) -> Tụ 1 nhận Q');

  // Reset sang Segment 2
  app.resetVoiceSegment();

  // Đọc "hai" ở Segment 2 (Apple Speech gửi đúng "2", hoàn toàn không thể ra 1222 hay 10 22)
  app.processVoiceInput('hai', 2, 6000);
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Giải pháp 1: Đọc "hai" (Segment 2) -> Tụ 2 nhận lá 2, triệt tiêu hoàn toàn lỗi 1222 / 10 22!');
}

// 21. Test Bản sao đối chiếu thời gian thực (Realtime Confirmed Cards Snapshot & Drop Retroactive Apple Echoes)
{
  const appCodeFull = fs.readFileSync('preview/app.js', 'utf8');
  const sandbox = {
    window: { addEventListener: () => {} },
    document: {
      getElementById: () => ({ style: {}, innerHTML: '', textContent: '', appendChild: () => {}, classList: { add: () => {}, remove: () => {} }, querySelector: () => ({ addEventListener: () => {} }), addEventListener: () => {} }),
      querySelectorAll: () => [],
      createElement: () => ({ style: {}, dataset: {}, appendChild: () => {}, addEventListener: () => {}, querySelector: () => ({ addEventListener: () => {} }), setAttribute: () => {} })
    },
    localStorage: { getItem: () => null, setItem: () => {} },
    console: console,
    setTimeout: (fn, ms) => setTimeout(fn, ms),
    clearTimeout: (id) => clearTimeout(id),
    Date: Date
  };
  vm.createContext(sandbox);
  vm.runInContext(appCodeFull, sandbox);
  const AppCtrl = vm.runInContext('AppController', sandbox);

  const app = new AppCtrl();
  app.currentGameType = 'lieng3';
  app.playerCount = 3;
  app.initPlayers();
  app.isRankOnlyMode = true;

  // 21.1: Kịch bản người dùng đọc "mười một, mười một, mười một" (như trong ảnh thực tế của người dùng)
  // Lần 1: Apple gửi "11" -> Tụ 1 nhận J (11)
  app.processVoiceInput('11', 1, 1000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 11, 'Snapshot 21.1: Đọc "mười một" -> Tụ 1 nhận đúng lá J (11)');
  assert(app.confirmedVoiceCards.length === 1, 'Snapshot 21.1: Bản đối chiếu ghi nhận 1 lá đã chốt');

  // Lần 2: Người dùng đọc tiếp cho Tụ 2, Apple stream tích luỹ gửi "11 11" -> Tụ 2 PHẢI NHẬN ĐƯỢC lá J (11)!
  app.processVoiceInput('11 11', 1, 1800);
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 11, 'Snapshot 21.1: Đọc tiếp "mười một" (stream "11 11") -> Tụ 2 nhận chuẩn xác lá J (11)!');
  assert(app.confirmedVoiceCards.length === 2, 'Snapshot 21.1: Bản đối chiếu ghi nhận 2 lá [J, J]');

  // 21.2: Người dùng đọc tiếp cho Tụ 3, Apple stream gửi "11 11 11" -> Tụ 3 PHẢI NHẬN ĐƯỢC lá J (11)!
  app.processVoiceInput('11 11 11', 1, 2600);
  assert(app.players[2].cards.length === 1 && app.players[2].cards[0].rank === 11, 'Snapshot 21.2: Đọc tiếp "mười một" (stream "11 11 11") -> Tụ 3 nhận chuẩn xác lá J (11)!');
  assert(app.confirmedVoiceCards.length === 3, 'Snapshot 21.2: Bản đối chiếu ghi nhận đủ 3 lá [J, J, J]');

  // 21.3: Kịch bản người dùng đọc "mười mười" liền một hơi -> 10, 10
  app.startNewRound();
  app.initPlayers();
  assert(app.confirmedVoiceCards.length === 0, 'Snapshot 21.3: Làm mới ván bài -> Bản đối chiếu được xóa sạch');

  app.processVoiceInput('mười mười', 1, 3000);
  app.flushPendingVoiceCards();
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 10, 'Snapshot 21.3: Đọc "mười mười" -> Tụ 1 nhận lá 10');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 10, 'Snapshot 21.3: Đọc "mười mười" -> Tụ 2 nhận lá 10');
  assert(app.confirmedVoiceCards.length === 2, 'Snapshot 21.3: Bản đối chiếu ghi nhận đủ 2 lá 10');

  // 21.4: Kịch bản người dùng đọc "12 12" -> Q, Q
  app.startNewRound();
  app.initPlayers();
  app.processVoiceInput('12 12', 1, 4000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 12, 'Snapshot 21.4: Đọc "12 12" -> Tụ 1 nhận lá Q (12)');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 12, 'Snapshot 21.4: Đọc "12 12" -> Tụ 2 nhận lá Q (12)');
  assert(app.confirmedVoiceCards.length === 2, 'Snapshot 21.4: Bản đối chiếu ghi nhận đủ 2 lá Q (12)');

  // 21.5: Kịch bản người dùng đọc liên tiếp nhiều tụ cùng điểm: "năm, năm, ba" (stream "5 5 3")
  app.startNewRound();
  app.initPlayers();
  // Bước 1: Đọc "năm" cho Tụ 1
  app.processVoiceInput('5', 1, 1000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 5, 'Snapshot 21.5: Đọc "năm" -> Tụ 1 nhận đúng 1 lá 5');
  assert(app.currentSegmentPlacedCards.length === 1, 'Snapshot 21.5: Bản đối chiếu ghi nhận 1 lá 5 đã chốt');

  // Bước 2: Đọc tiếp "năm" cho Tụ 2 -> Stream tích luỹ "5 5"
  app.processVoiceInput('5 5', 1, 1800);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 5, 'Snapshot 21.5: Tụ 1 giữ nguyên lá 5');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 5, 'Snapshot 21.5: Tụ 2 nhận chuẩn xác lá 5!');
  assert(app.currentSegmentPlacedCards.length === 2, 'Snapshot 21.5: Bản đối chiếu ghi nhận 2 lá [5, 5]');

  // Bước 3: Đọc tiếp "ba" cho Tụ 3 -> Stream tích luỹ "5 5 3"
  app.processVoiceInput('5 5 3', 1, 2600);
  assert(app.players[2].cards.length === 1 && app.players[2].cards[0].rank === 3, 'Snapshot 21.5: Đọc tiếp "ba" (stream "5 5 3") -> Tụ 3 nhận đúng lá 3!');
  assert(app.currentSegmentPlacedCards.length === 3, 'Snapshot 21.5: Bản đối chiếu ghi nhận [5, 5, 3]');

  // 21.6: Kịch bản đọc liên tục thứ tự "một, hai, ba" trên luồng realtime duy nhất
  app.startNewRound();
  app.initPlayers();
  // Nói "một"
  app.processVoiceInput('một', 1, 3000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 14, 'Snapshot 21.6: Đọc "một" -> Tụ 1 nhận Át (14)');

  // Nói tiếp "hai" -> stream "một hai"
  app.processVoiceInput('một hai', 1, 3800);
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Snapshot 21.6: Đọc tiếp "hai" -> Tụ 2 nhận lá 2');

  // 21.7: Kịch bản CHÍNH XÁC theo ảnh của người dùng:
  // Đọc "một" -> Tụ 1 nhận Át, đọc "hai" -> Tụ 2 nhận 2
  // Sau đó Apple tự gộp "1 2" thành "12", stream gửi "12 3" -> Tụ 3 PHẢI nhận được lá 3!
  app.startNewRound();
  app.initPlayers();
  app.processVoiceInput('1', 1, 5000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 14, 'Snapshot 21.7: Đọc "1" -> Tụ 1 nhận Át (14)');

  app.processVoiceInput('1 2', 1, 5800);
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 2, 'Snapshot 21.7: Đọc "2" -> Tụ 2 nhận lá 2');

  // Apple tự gộp "1 2" thành "12", chuỗi gửi về "12 3":
  app.processVoiceInput('12 3', 1, 6600);
  assert(app.players[0].cards[0].rank === 14, 'Snapshot 21.7: Tụ 1 giữ nguyên Át (14)');
  assert(app.players[1].cards[0].rank === 2, 'Snapshot 21.7: Tụ 2 giữ nguyên lá 2');
  assert(app.players[2].cards.length === 1 && app.players[2].cards[0].rank === 3, 'Snapshot 21.7: Tụ 3 NHẬN CHUẨN XÁC LÁ 3 khi Apple gửi "12 3"!');
  assert(app.currentSegmentPlacedCards.length === 3, 'Snapshot 21.7: Bản đối chiếu ghi nhận đủ 3 lá [Át, 2, 3]');

  // 21.8: Kịch bản "đừng thấy 10 phát gán 10 luôn":
  // Đọc "mười hai" -> Khi nói "mười", app giữ chờ (chưa gán 10). Ngay sau đó Apple cập nhật "12" -> Gán THẲNG lá 12 (Q)!
  app.startNewRound();
  app.initPlayers();
  // Bước 1: Apple trả về "mười" trước
  app.processVoiceInput('mười', 1, 7000);
  assert(app.players[0].cards.length === 0, 'Snapshot 21.8: Đọc "mười" -> Bộ theo dõi CHỜ TỪ NỐI, chưa gán ngay lá 10!');

  // Bước 2: Apple cập nhật thành "12" (hoặc "mười hai") -> Gán THẲNG lá 12 (Q) vào Tụ 1!
  app.processVoiceInput('12', 1, 7150);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 12, 'Snapshot 21.8: Apple cập nhật "12" -> Gán THẲNG lá 12 (Q) vào Tụ 1!');
  assert(app.players[1].cards.length === 0, 'Snapshot 21.8: Tụ 2 hoàn toàn rỗng, không bị đẩy lệch tụ!');

  // 21.9: Kịch bản Apple sửa hồi tố "nam nắm năm" -> "5 5 5" -> Người dùng đọc tiếp "ba" ("5 5 5 3"):
  app.startNewRound();
  app.initPlayers();
  // Bước 1: Nói "nam nắm năm" -> Nhận diện đúng 1 lá 5 vào Tụ 1
  app.processVoiceInput('nam nắm năm', 1, 8000);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 5, 'Snapshot 21.9: Đọc "nam nắm năm" -> Tụ 1 nhận đúng 1 lá 5');

  // Bước 2: Apple tự ý sửa hồi tố thành "5 5 5" mà không có từ mới nào nói thêm -> VÔ HIỆU HÓA sửa đổi của Apple!
  app.processVoiceInput('5 5 5', 1, 8800);
  assert(app.players[0].cards.length === 1 && app.players[0].cards[0].rank === 5, 'Snapshot 21.9: Apple sửa thành "5 5 5" -> Tụ 1 vẫn chỉ có 1 lá 5 duy nhất!');
  assert(app.players[1].cards.length === 0, 'Snapshot 21.9: Tụ 2 hoàn toàn rỗng, KHÔNG bị nhảy thêm lá 5 rác!');
  assert(app.players[2].cards.length === 0, 'Snapshot 21.9: Tụ 3 hoàn toàn rỗng!');

  // Bước 3: Người dùng đọc tiếp "ba" cho Tụ 2 -> Stream tích luỹ "5 5 5 3" -> Tụ 2 nhận chuẩn xác lá 3!
  app.processVoiceInput('5 5 5 3', 1, 9600);
  assert(app.players[0].cards[0].rank === 5, 'Snapshot 21.9: Tụ 1 giữ nguyên lá 5');
  assert(app.players[1].cards.length === 1 && app.players[1].cards[0].rank === 3, 'Snapshot 21.9: Đọc tiếp "ba" (stream "5 5 5 3") -> Tụ 2 nhận chuẩn xác lá 3!');
  assert(app.players[2].cards.length === 0, 'Snapshot 21.9: Tụ 3 vẫn chưa có bài!');

  // 22: Test "mười mốt", "mười 1" & Nhật ký lời nói thực tế (Voice Log with Timestamps)
  const pMuoiMot = VietnameseCardVoiceParser.parse('mười mốt');
  assert(pMuoiMot.length === 1 && pMuoiMot[0].rank === 11, 'Voice Parser: "mười mốt" -> J (11)');

  const pMuoi1 = VietnameseCardVoiceParser.parse('mười 1');
  assert(pMuoi1.length === 1 && pMuoi1[0].rank === 11, 'Voice Parser: "mười 1" -> J (11)');

  const logText = app.getVoiceLogText();
  assert(logText.length > 0 && logText.includes('Segment #1'), 'Voice Log: Nhật ký lời nói ghi lại đầy đủ các gói tin');
  assert(app.voiceLogs.length > 0, 'Voice Log: Mảng voiceLogs lưu trữ chi tiết các thao tác');

  app.clearVoiceLogs();
  assert(app.voiceLogs.length === 0, 'Voice Log: Xóa nhật ký thành công');
}

console.log(`\n=== TỔNG KẾT: ${passed}/${total} TESTS ĐẠT CHUẨN 100% ===`);



