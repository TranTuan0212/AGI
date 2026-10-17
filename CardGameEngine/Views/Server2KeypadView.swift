import SwiftUI

public struct Server2KeypadView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // Quick ranks
    private let allRanks: [Rank] = [
        .ace, .two, .three, .four, .five, .six, .seven,
        .eight, .nine, .ten, .jack, .queen, .king
    ]
    
    private let normalRow1: [Rank] = [.ace, .two, .three, .four, .five, .six, .seven]
    private let normalRow2: [Rank] = [.eight, .nine, .ten, .jack, .queen, .king]
    
    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // 1. HÀNG CHẤT RÔ (♦) - Chuyên biệt như Server 2
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("♦")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.roseAccent)
                    Text("Chất Rô (♦) Ưu Tiên:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.roseAccent)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(allRanks) { rank in
                            Button(action: {
                                viewModel.addServer2Card(rank: rank, isRo: true)
                            }) {
                                Text("\(rank.displaySymbol)♦")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 42, height: 38)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.roseAccent, Color(red: 0.85, green: 0.15, blue: 0.25)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.roseAccent.opacity(0.35), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(ScaleTouchButtonStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }
            .padding(6)
            .background(Color.roseAccent.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.roseAccent.opacity(0.25), lineWidth: 1)
            )
            
            // 2. CÁC HÀNG SỐ THƯỜNG (A - K)
            VStack(spacing: 6) {
                // Hàng A - 7
                HStack(spacing: 5) {
                    ForEach(normalRow1) { rank in
                        Button(action: {
                            viewModel.addServer2Card(rank: rank, isRo: false)
                        }) {
                            Text(rank.displaySymbol)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(red: 0.16, green: 0.20, blue: 0.28))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                        }
                        .buttonStyle(ScaleTouchButtonStyle())
                    }
                }
                
                // Hàng 8 - K
                HStack(spacing: 5) {
                    ForEach(normalRow2) { rank in
                        Button(action: {
                            viewModel.addServer2Card(rank: rank, isRo: false)
                        }) {
                            Text(rank.displaySymbol)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color(red: 0.16, green: 0.20, blue: 0.28))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                        }
                        .buttonStyle(ScaleTouchButtonStyle())
                    }
                }
            }
            
            // 3. HÀNG TIỆN ÍCH DƯỚI CÙNG
            HStack(spacing: 6) {
                // Phím 0 (Không thấy / ?)
                Button(action: {
                    viewModel.addServer2UnknownCard()
                }) {
                    HStack(spacing: 4) {
                        Text("0")
                            .font(.system(size: 14, weight: .black))
                        Text("(Ẩn/?)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color(red: 0.22, green: 0.18, blue: 0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleTouchButtonStyle())
                
                // Hoàn tác
                Button(action: {
                    viewModel.undoServer2Action()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .bold))
                        Text("Hoàn tác")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(viewModel.canUndoServer2 ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color(red: 0.18, green: 0.22, blue: 0.30))
                    .cornerRadius(8)
                }
                .disabled(!viewModel.canUndoServer2)
                .buttonStyle(ScaleTouchButtonStyle())
                
                // Tụ kế tiếp (khi ở chế độ chọn thủ công)
                Button(action: {
                    viewModel.moveToNextPlayer()
                }) {
                    HStack(spacing: 4) {
                        Text("Tụ \(viewModel.selectedPlayerIndex + 1)")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleTouchButtonStyle())
                
                // Ván Mới / Xóa hết
                Button(action: {
                    viewModel.resetServer2Table()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("Ván mới")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(8)
                }
                .buttonStyle(ScaleTouchButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
