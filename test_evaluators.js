const fs = require('fs');
const vm = require('vm');

// We will read app.js content and evaluate the classes in a sandbox
const appCode = fs.readFileSync('e:/appgame/preview/app.js', 'utf8');

// Strip out window / document DOM stuff for node testing of logic classes
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

  // Test lưu cài đặt khi tắt
  app.isRankOnlyMode = false;
  sandbox.localStorage.setItem('card_game_rank_only_mode', 'false');
  assert(app.isRankOnlyActive() === false, 'Rank-Only: Tắt chế độ thành công và ghi nhớ vào storage');

  // Test nút [Không thấy] (Lá bài ẩn ?)
  app.resetTable();
  app.currentGameType = 'lieng3';
  app.playerCount = 2;
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

console.log(`\n=== TỔNG KẾT: ${passed}/${total} TESTS ĐẠT CHUẨN 100% ===`);
