import SwiftUI

public struct Server2KeypadView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // Đầy đủ 13 lá từ A đến K (13 phím / 1 hàng ngang)
    private let allRanks: [Rank] = [
        .ace, .two, .three, .four, .five, .six, .seven,
        .eight, .nine, .ten, .jack, .queen, .king
    ]
    
    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            if viewModel.gameType == .lieng3 {
                // MARK: - LIÊNG 3 LÁ: BÀN PHÍM CHẤT RÔ ƯU TIÊN + SỐ THƯỜNG
                lieng3KeypadView
            } else if viewModel.gameType == .binh9NoStraight {
                // MARK: - ( 9 lá không liên ): BÀN PHÍM TO BẢN KHÔNG CẦN CHẤT
                binh9NoStraightKeypadView
            } else {
                // MARK: - CÁC GAME KHÁC: ĐỦ 4 CHẤT HOẶC NHẬP CHAY (CÓ NÚT SETTING BẬT TẮT)
                otherGamesKeypadView
            }
            
            // MARK: - HÀNG TIỆN ÍCH DƯỚI CÙNG (DÙNG CHUNG)
            bottomUtilityRow
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color(red: 0.08, green: 0.10, blue: 0.14))
    }
    
    // MARK: - Giao diện bàn phím Liêng 3 Lá
    private var lieng3KeypadView: some View {
        VStack(spacing: 4) {
            // 1. HÀNG CHẤT RÔ (♦) - ĐỦ 13 PHÍM A♦ ➔ K♦ TRÊN 1 HÀNG NGANG
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("♦ CHẤT RÔ ƯU TIÊN:")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.roseAccent)
                    Spacer()
                    Text("A♦ ➔ K♦")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.roseAccent.opacity(0.8))
                }
                .padding(.horizontal, 4)
                
                HStack(spacing: 2) {
                    ForEach(allRanks) { rank in
                        Button(action: {
                            viewModel.addServer2Card(rank: rank, isRo: true)
                        }) {
                            VStack(spacing: 0) {
                                Text(rank.displaySymbol)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .lineLimit(1)
                                Text("♦")
                                    .font(.system(size: 8, weight: .black))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 33)
                            .background(
                                LinearGradient(
                                    colors: [Color.roseAccent, Color(red: 0.82, green: 0.12, blue: 0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(ScaleTouchButtonStyle())
                    }
                }
            }
            .padding(4)
            .background(Color.roseAccent.opacity(0.10))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.roseAccent.opacity(0.28), lineWidth: 1)
            )
            
            // 2. HÀNG SỐ THƯỜNG - ĐỦ 13 PHÍM A ➔ K TRÊN 1 HÀNG NGANG
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("SỐ THƯỜNG:")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("A ➔ K")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
                
                HStack(spacing: 2) {
                    ForEach(allRanks) { rank in
                        Button(action: {
                            viewModel.addServer2Card(rank: rank, isRo: false)
                        }) {
                            Text(rank.displaySymbol)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 33)
                                .background(Color(red: 0.16, green: 0.20, blue: 0.28))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        }
                        .buttonStyle(ScaleTouchButtonStyle())
                    }
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
    }
    
    
    // MARK: - Giao diện bàn phím ( 9 lá không liên ): Phím to bản, 1 hàng A ➔ K, không cần 4 chất
    private var binh9NoStraightKeypadView: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Text("( 9 lá không liên )")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.yellow)
                    Text("• NHẬP SỐ CHAY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("A ➔ K (Phím to)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            
            HStack(spacing: 2.5) {
                ForEach(allRanks) { rank in
                    Button(action: {
                        viewModel.addServer2CardRankOnly(rank: rank)
                    }) {
                        Text(rank.displaySymbol)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.22, blue: 0.32), Color(red: 0.10, green: 0.13, blue: 0.20)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1.2)
                            )
                    }
                    .buttonStyle(ScaleTouchButtonStyle())
                }
            }
            .padding(4)
            .background(Color.yellow.opacity(0.06))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - Giao diện bàn phím Các Game Khác (Có Toggle Setting 4 Chất vs Nhập Chay)
    private var otherGamesKeypadView: some View {
        VStack(spacing: 4) {
            // Thanh tiêu đề + Nút Setting chuyển đổi Đủ 4 chất <-> Nhập chay
            HStack {
                Text("CHẾ ĐỘ NHẬP:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    viewModel.isRankOnlyMode.toggle()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.isRankOnlyMode ? "textformat.123" : "suit.club.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(viewModel.isRankOnlyMode ? "⚡ Nhập Chay (A ➔ K)" : "🃏 Đủ 4 Chất (♥ ♦ ♣ ♠)")
                            .font(.system(size: 10, weight: .black))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(viewModel.isRankOnlyMode ? Color.yellow : Color.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(viewModel.isRankOnlyMode ? Color.yellow.opacity(0.15) : Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(viewModel.isRankOnlyMode ? Color.yellow.opacity(0.4) : Color.cyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleTouchButtonStyle())
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            
            if viewModel.isRankOnlyMode {
                // CHẾ ĐỘ NHẬP CHAY (A ➔ K)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("NHẬP CHAY:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("A ➔ K (Không phân biệt chất)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 4)
                    
                    HStack(spacing: 2) {
                        ForEach(allRanks) { rank in
                            Button(action: {
                                viewModel.addServer2CardRankOnly(rank: rank)
                            }) {
                                Text(rank.displaySymbol)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(Color(red: 0.16, green: 0.20, blue: 0.28))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(ScaleTouchButtonStyle())
                        }
                    }
                }
                .padding(4)
                .background(Color.yellow.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                )
            } else {
                // CHẾ ĐỘ ĐỦ 4 CHẤT: CƠ ♥, RÔ ♦, CHUỒN ♣, BÍCH ♠
                VStack(spacing: 3) {
                    // 1. CƠ ♥ (Đỏ)
                    suitRow(
                        suit: .hearts,
                        title: "♥ CƠ",
                        gradient: LinearGradient(colors: [Color(red: 0.90, green: 0.15, blue: 0.25), Color(red: 0.72, green: 0.08, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // 2. RÔ ♦ (Đỏ Cam)
                    suitRow(
                        suit: .diamonds,
                        title: "♦ RÔ",
                        gradient: LinearGradient(colors: [Color(red: 0.95, green: 0.38, blue: 0.12), Color(red: 0.80, green: 0.22, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // 3. CHUỒN ♣ (Xanh Lục)
                    suitRow(
                        suit: .clubs,
                        title: "♣ CHUỒN",
                        gradient: LinearGradient(colors: [Color(red: 0.15, green: 0.55, blue: 0.38), Color(red: 0.08, green: 0.40, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // 4. BÍCH ♠ (Xanh Indigo)
                    suitRow(
                        suit: .spades,
                        title: "♠ BÍCH",
                        gradient: LinearGradient(colors: [Color(red: 0.20, green: 0.26, blue: 0.42), Color(red: 0.12, green: 0.16, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                .padding(4)
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Row 13 lá của 1 chất
    private func suitRow(suit: Suit, title: String, gradient: LinearGradient) -> some View {
        HStack(spacing: 2) {
            ForEach(allRanks) { rank in
                Button(action: {
                    viewModel.addServer2Card(rank: rank, suit: suit)
                }) {
                    VStack(spacing: 0) {
                        Text(rank.displaySymbol)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .lineLimit(1)
                        Text(suit.rawValue)
                            .font(.system(size: 7.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 27)
                    .background(gradient)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.30), lineWidth: 0.8)
                    )
                }
                .buttonStyle(ScaleTouchButtonStyle())
            }
        }
    }
    
    // MARK: - Hàng Tiện Ích Dưới Cùng (0 Ẩn, Hoàn tác, Tụ tiếp theo, Ván mới)
    private var bottomUtilityRow: some View {
        HStack(spacing: 5) {
            // Phím 0 (Không thấy / ?)
            Button(action: {
                viewModel.addServer2UnknownCard()
            }) {
                HStack(spacing: 3) {
                    Text("0")
                        .font(.system(size: 13, weight: .black))
                    Text("(Ẩn/?)")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.2))
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(Color(red: 0.22, green: 0.18, blue: 0.08))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleTouchButtonStyle())
            
            // Hoàn tác
            Button(action: {
                viewModel.undoServer2Action()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .bold))
                    Text("Hoàn tác")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(viewModel.canUndoServer2 ? .white : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(Color(red: 0.18, green: 0.22, blue: 0.30))
                .cornerRadius(7)
            }
            .disabled(!viewModel.canUndoServer2)
            .buttonStyle(ScaleTouchButtonStyle())
            
            // Tụ kế tiếp / Bài chung
            Button(action: {
                viewModel.moveToNextPlayer()
            }) {
                HStack(spacing: 3) {
                    if viewModel.isSelectingCommunity {
                        Text("Bài Chung")
                            .font(.system(size: 11, weight: .bold))
                    } else {
                        Text("Tụ \(viewModel.selectedPlayerIndex + 1)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(Color.cyan.opacity(0.12))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleTouchButtonStyle())
            
            // Ván Mới
            Button(action: {
                viewModel.resetServer2Table()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                    Text("Ván mới")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(Color.red.opacity(0.85))
                .cornerRadius(7)
            }
            .buttonStyle(ScaleTouchButtonStyle())
        }
    }
}

// Button Touch Animation
public struct ScaleTouchButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

extension Color {
    static let roseAccent = Color(red: 0.95, green: 0.22, blue: 0.38)
}
