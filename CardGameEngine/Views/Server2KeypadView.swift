import SwiftUI

public struct Server2KeypadView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // Đầy đủ 13 lá từ A đến K (Phương Án 1: 13 phím / 1 hàng ngang)
    private let allRanks: [Rank] = [
        .ace, .two, .three, .four, .five, .six, .seven,
        .eight, .nine, .ten, .jack, .queen, .king
    ]
    
    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 5) {
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
                            .frame(height: 34)
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
                                .frame(height: 34)
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
            
            // 3. HÀNG TIỆN ÍCH DƯỚI CÙNG
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
                
                // Tụ kế tiếp
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
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color(red: 0.08, green: 0.10, blue: 0.14))
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
