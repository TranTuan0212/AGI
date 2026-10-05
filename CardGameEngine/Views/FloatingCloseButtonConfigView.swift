import SwiftUI

/// Màn hình mô phỏng Bảng Điểm Ảo cho phép người dùng kéo thả
/// vị trí nút đóng thứ 2 và phóng to / thu nhỏ trực quan như trong game.
public struct FloatingCloseButtonConfigView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var tempRatioX: CGFloat
    @State private var tempRatioY: CGFloat
    @State private var tempSize: CGFloat
    @State private var isDragging: Bool = false
    
    public init(viewModel: GameViewModel) {
        self.viewModel = viewModel
        _tempRatioX = State(initialValue: viewModel.floatingCloseButtonRatioX)
        _tempRatioY = State(initialValue: viewModel.floatingCloseButtonRatioY)
        _tempSize = State(initialValue: viewModel.floatingCloseButtonSize)
    }
    
    public var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    // 1. Giao diện mô phỏng Bảng Điểm Ảo (Mock Score Sheet)
                    ScrollView {
                        VStack(spacing: 14) {
                            // Instruction banner
                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.yellow)
                                Text("Chạm giữ và KÉO NÚT ĐÓNG (màu đỏ) đến vị trí bạn muốn đặt, chỉnh to nhỏ ở thanh trượt rồi bấm Lưu.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.85))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Mock Winner Banner
                            VStack(spacing: 6) {
                                Text("🏆 Người chơi 1 THẮNG (9 Điểm)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("BẢNG ĐIỂM MÔ PHỎNG (MINH HỌA)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .padding(.horizontal)
                            
                            // Mock Rankings List
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bảng Xếp Hạng So Bài (Mẫu)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                ForEach(1...4, id: \.self) { rank in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(rank == 1 ? Color.yellow : Color.gray.opacity(0.5))
                                                .frame(width: 32, height: 32)
                                            Text("\(rank)")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Người chơi \(rank)")
                                                .font(.subheadline.bold())
                                            Text(rank == 1 ? "9 Điểm - Thắng lớn" : "\(10 - rank) Điểm")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(rank == 1 ? "HẠNG 1" : "HẠNG \(rank)")
                                            .font(.caption2.bold())
                                            .foregroundColor(rank == 1 ? .orange : .secondary)
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer().frame(height: 140) // Chừa khoảng trống bên dưới cho bảng điều khiển kích thước
                        }
                    }
                    
                    // 2. Nút Đóng Nổi Thứ 2 có thể kéo thả (Draggable Floating Button)
                    let btnX = geo.size.width * tempRatioX
                    let btnY = geo.size.height * tempRatioY
                    
                    VStack(spacing: 2) {
                        Image(systemName: "xmark")
                            .font(.system(size: tempSize * 0.36, weight: .black))
                        if tempSize >= 50 {
                            Text("ĐÓNG")
                                .font(.system(size: max(8, tempSize * 0.18), weight: .black))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: tempSize, height: tempSize)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.red, Color(red: 0.9, green: 0.2, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isDragging ? 3.5 : 2.5)
                    )
                    .shadow(
                        color: Color.black.opacity(isDragging ? 0.6 : 0.35),
                        radius: isDragging ? 10 : 5,
                        x: 0,
                        y: isDragging ? 6 : 3
                    )
                    .scaleEffect(isDragging ? 1.12 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                    .position(x: btnX, y: btnY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let half = tempSize / 2
                                let clampedX = min(max(half + 10, value.location.x), geo.size.width - half - 10)
                                let clampedY = min(max(half + 40, value.location.y), geo.size.height - half - 100)
                                tempRatioX = clampedX / geo.size.width
                                tempRatioY = clampedY / geo.size.height
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    
                    // 3. Khung điều chỉnh kích cỡ cố định ở dưới cùng (Control Bar)
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            HStack {
                                Text("Phóng to / Thu nhỏ:")
                                    .font(.subheadline.bold())
                                Spacer()
                                Text("\(Int(tempSize)) pt")
                                    .font(.subheadline.monospacedDigit().bold())
                                    .foregroundColor(.blue)
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Slider(value: $tempSize, in: 44...96, step: 2)
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Button(action: {
                                    // Đặt lại góc dưới phải mặc định
                                    tempRatioX = 0.82
                                    tempRatioY = 0.75
                                    tempSize = 60
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Vị trí mặc định")
                                    }
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("Đang di chuyển: (\(Int(tempRatioX * 100))%, \(Int(tempRatioY * 100))%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(14)
                        .background(Color(.systemBackground).opacity(0.96))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, y: -2)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                }
            }
            .navigationTitle("Chỉnh Nút Đóng Thứ 2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        viewModel.floatingCloseButtonRatioX = tempRatioX
                        viewModel.floatingCloseButtonRatioY = tempRatioY
                        viewModel.floatingCloseButtonSize = tempSize
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
