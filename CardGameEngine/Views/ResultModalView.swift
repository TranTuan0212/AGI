import SwiftUI

public struct ResultModalView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Winner Banner
                    VStack(spacing: 8) {
                        Text(viewModel.showdownSummary)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(viewModel.gameType.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                    .padding(.horizontal)
                    
                    // Rankings List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bảng Xếp Hạng & Đánh Giá Bài")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let sortedPlayers = viewModel.players.sorted { ($0.rankOrder ?? 99) < ($1.rankOrder ?? 99) }
                        
                        ForEach(sortedPlayers) { player in
                            HStack(alignment: .top, spacing: 12) {
                                // Medal / Rank badge
                                ZStack {
                                    Circle()
                                        .fill(rankBadgeColor(player.rankOrder ?? 0))
                                        .frame(width: 36, height: 36)
                                    
                                    Text("\(player.rankOrder ?? 0)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(player.name)
                                            .font(.headline)
                                        
                                        if player.isLung {
                                            Text("LỦNG")
                                                .font(.caption2)
                                                .fontWeight(.black)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.red)
                                                .cornerRadius(4)
                                        }
                                        
                                        Spacer()
                                        
                                        if viewModel.gameType.category == .binh {
                                            Text("\(player.score > 0 ? "+\(player.score)" : "\(player.score)") chi")
                                                .font(.headline)
                                                .foregroundColor(player.score > 0 ? .green : (player.score < 0 ? .red : .primary))
                                        }
                                    }
                                    
                                    Text(player.resultTitle)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    
                                    Text(player.resultDetail)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Binh 13 Confrontation Matrix
                    if viewModel.gameType == .binh13 && !viewModel.confrontationMatrix.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ma Trận Đối Đầu Chi (A vs B)")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 2) {
                                // Header row
                                HStack {
                                    Text("Nhà")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(width: 60)
                                    ForEach(viewModel.players) { p in
                                        Text(p.name.replacingOccurrences(of: "Nhóm ", with: ""))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.15))
                                
                                ForEach(0..<viewModel.players.count, id: \.self) { i in
                                    HStack {
                                        Text(viewModel.players[i].name.replacingOccurrences(of: "Nhóm ", with: ""))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .frame(width: 60)
                                        
                                        ForEach(0..<viewModel.players.count, id: \.self) { j in
                                            let val = viewModel.confrontationMatrix[i][j]
                                            Text(val)
                                                .font(.caption2)
                                                .foregroundColor(val.contains("+") ? .green : (val.contains("-") ? .red : .primary))
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Kết Quả So Bài")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        viewModel.isShowResultModal = false
                    }
                }
            }
        }
    }
    
    private func rankBadgeColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.brown
        default: return Color.blue.opacity(0.6)
        }
    }
}
