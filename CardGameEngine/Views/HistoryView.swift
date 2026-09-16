import SwiftUI

public struct HistoryView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Compute cumulative scores
    private var cumulativeScores: [(name: String, wins: Int, totalScore: Int)] {
        var dict = [String: (wins: Int, totalScore: Int)]()
        for match in viewModel.history {
            for p in match.playerScores {
                let current = dict[p.name] ?? (wins: 0, totalScore: 0)
                dict[p.name] = (
                    wins: current.wins + (p.rank == 1 ? 1 : 0),
                    totalScore: current.totalScore + p.score
                )
            }
        }
        return dict.map { (name: $0.key, wins: $0.value.wins, totalScore: $0.value.totalScore) }
            .sorted {
                if $0.totalScore != $1.totalScore { return $0.totalScore > $1.totalScore }
                return $0.wins > $1.wins
            }
    }
    
    public var body: some View {
        NavigationView {
            List {
                // Section 1: Cumulative Scoreboard
                Section(header: Label("Bảng Điểm Tích Lũy Toàn Phiên", systemImage: "trophy.fill")) {
                    if cumulativeScores.isEmpty {
                        Text("Chưa có ván đấu nào được ghi nhận.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(cumulativeScores.enumerated()), id: \.offset) { idx, item in
                            HStack {
                                Text("\(idx + 1). \(item.name)")
                                    .fontWeight(.semibold)
                                Text("(\(item.wins) ván Nhất)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(item.totalScore > 0 ? "+\(item.totalScore)" : "\(item.totalScore)") chi")
                                    .fontWeight(.bold)
                                    .foregroundColor(item.totalScore > 0 ? .green : (item.totalScore < 0 ? .red : .primary))
                            }
                        }
                    }
                }
                
                // Section 2: Detailed Matches List
                Section(header: HStack {
                    Label("Chi Tiết Từng Ván", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    if !viewModel.history.isEmpty {
                        Button("Xóa lịch sử") {
                            viewModel.history.removeAll()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }) {
                    if viewModel.history.isEmpty {
                        Text("Chưa có ván bài nào. Hãy bấm 'So Bài' sau mỗi ván để lưu tự động!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.history) { match in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(match.gameName)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text(match.time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("🏆 Nhất: \(match.winnerName) (\(match.winnerDetail))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text(match.playerScores.map { "\($0.name): \($0.score > 0 ? "+\($0.score)" : "\($0.score)")" }.joined(separator: " | "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Lịch Sử Thắng Thua")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
