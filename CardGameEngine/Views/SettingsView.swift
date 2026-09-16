import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Quy Ước So Chất Bài")) {
                    Picker("Hệ Thống Chất", selection: $viewModel.suitPreset) {
                        ForEach(SuitRulePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                }
                
                Section(header: Text("Luật Chơi Hiện Tại")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.gameType.rawValue)
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text(viewModel.gameType.descriptionVN)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Hướng Dẫn Cơ Chế Chia Bài")) {
                    Text("• Chia Tuần Tự (Round-Robin): Khi bấm lá bài trên lưới 52 lá, lá bài sẽ tự động chia xoay vòng: Lá 1 vào A, Lá 2 vào B, Lá 3 vào C, Lá 4 vào A... đúng như ngoài đời thực.")
                        .font(.caption)
                    Text("• Chọn Thủ Công: Bấm chọn trực tiếp một nhóm để nạp đầy đủ bài cho nhóm đó trước khi chuyển sang nhóm tiếp theo.")
                        .font(.caption)
                    Text("• Chạm lại lá bài đã chia để hoàn tác (Undo) hoặc bấm nút Hoàn Tác trên thanh công cụ.")
                        .font(.caption)
                }
            }
            .navigationTitle("Cài Đặt & Luật Bài")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
