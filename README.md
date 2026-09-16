# GiaLapSoBai - Trợ Lý & Trọng Tài So Bài Tây 52 Lá (iOS SwiftUI & Web Simulator)
### Phỏm (Tá Lả) — Binh (Mậu Binh) — Liêng (3 Cây) — Poker (Texas Hold'em)

Ứng dụng chuyên dụng hỗ trợ bàn chơi bài Tây ngoài đời thực: Đóng vai trò là **Trọng tài số hóa** giúp kiểm tra bài, chia bài tuần tự (Round-Robin) hoặc thủ công, tự động nhận diện Phỏm tối ưu, tính điểm rác, bắt Ù/Móm, sảnh bánh xe Poker, kicker 5 bậc, thắng trắng/lục phé bôn, kiểm tra lủng và công bố người thắng thua chuẩn xác 100%.

---

## 📱 Cấu Trúc Dự Án

Dự án gồm 2 phần được xây dựng song hành:

### 1. Mã Nguồn iOS Native (SwiftUI)
Nằm trong thư mục `CardGameEngine/`:
- **Models**:
  - `Card.swift`: 52 lá bài Tây, 4 chất (♠, ♣, ♦, ♥), 13 giá trị (2 đến A), cấu hình 4 preset quy ước chất.
  - `GameType.swift`: Cấu hình 7 thể loại & biến thể game (Phỏm 9 lá, Binh 13 lá, Binh 9 lá, Binh 6 lá, Liêng, Poker Hold'em).
  - `Player.swift`: Thông tin các nhóm người chơi (A, B, C...), lá bài trên tay, điểm số, thứ hạng.
- **Evaluators (Bộ não thẩm định bài)**:
  - `PhomEvaluator.swift`: Tự động tìm tổ hợp Phỏm ngang & Phỏm dọc tối ưu, bắt Ù (0 rác), Móm (Cháy bài), tính điểm rác ($A=1, J=11, Q=12, K=13$) và xếp hạng người chơi.
  - `PokerEvaluator.swift`: Đánh giá 7 lá Poker Texas Hold'em (2 tẩy + 5 chung), 10 cấp bậc từ Mậu thầu đến Sảnh rồng đồng chất, nhận diện sảnh bánh xe $A-2-3-4-5$, vector kicker 5 bậc.
  - `LiengEvaluator.swift`: Sáp > Liêng > Đĩ (Ba Tây) > Điểm mod 10, tiebreak theo preset chất.
  - `Binh13Evaluator.swift`: Thứ tự ưu tiên thắng trắng (Rồng cuốn, Sảnh rồng, Đồng hoa 13 lá, 5 đôi 1 sám, Lục phé bôn), thuật toán tự động xếp 3 chi tối ưu không lủng, bắt sập hầm x2, đè hàng x2, phạt lủng x2.
  - `Binh9Evaluator.swift`: 3 chi 3 lá (Chi 1 $\ge$ Chi 2 $\ge$ Chi 3), Ba sám cô, Ba sảnh.
  - `Binh6Evaluator.swift`: 2 chế độ (Thang Poker 6 lá và Xếp 2 chi 3-3).
- **ViewModels & Views**:
  - `GameViewModel.swift`: Quản lý state, Round-Robin queue, Undo, Deal ngẫu nhiên, Tính toán.
  - `Deck52GridView.swift`: Bàn chọn 52 lá bài tương tác trực quan.
  - `PlayerCardsView.swift`: Chiếu bài từng người chơi và khu vực bài chung.
  - `ResultModalView.swift`: Bảng xếp hạng thắng thua, huy chương, ma trận đối đầu các chi.
  - `SettingsView.swift`: Cài đặt quy ước chất và xem luật bài.
  - `ContentView.swift` & `CardGameApp.swift`: Giao diện chính SwiftUI.

### 2. Web Simulator Trực Quan (Chạy Ngay Trên Windows / iPhone)
Nằm trong thư mục `preview/`:
- `index.html`: Giao diện phong cách Apple iOS (Liquid Retina).
- `style.css`: Thiết kế chuẩn Apple SF Pro, glassmorphism, hiệu ứng quân bài trực quan.
- `app.js`: Bản sao hoàn chỉnh 100% của engine Swift, chạy mượt mà ngay trên mọi trình duyệt.

---

## 🚀 Hướng Dẫn Khởi Chạy

### Cách 1: Chạy Thử Ngay Trên Máy Tính / iPhone (Web Simulator)
1. Nhấp đúp vào file `run_preview.bat` trong thư mục `e:\appgame\`.
2. Mở trình duyệt truy cập: `http://localhost:3000`.
3. Để mở trên iPhone: Kết nối cùng mạng WiFi, mở Safari và nhập `http://<IP_MÁY_TÍNH>:3000`.

### Cách 2: Mở Trong Xcode (Dành Cho Mac)
- Kéo thư mục `CardGameEngine/` vào dự án Xcode (iOS App SwiftUI), chọn target iOS 16+.
- Bấm **Run (Cmd + R)** để chạy trên iPhone Simulator hoặc thiết bị thật.

---

## 🎯 Các Tính Năng Độc Đáo Đã Được Kiểm Thử 100%
- **Bố Cục Zero-Scroll Chuẩn Di Động**: Khu vực người chơi và bàn phím 52 lá cố định trên 1 màn hình, không cần cuộn trang mỏi tay. Các lá bài xếp lớp gối đầu thông minh (fanned cards).
- **Cơ chế Chia Tuần Tự (Round-Robin)**: Khi bấm lá bài trên lưới 52 lá, hệ thống tự động gán lần lượt vào A, B, C, rồi quay lại A... đúng như lúc chia bài ngoài đời thực.
- **Lịch Sử Thắng Thua & Bảng Tổng Sắp**: Lưu chi tiết từng ván đấu và tổng kết điểm/chi ròng lũy kế của từng người chơi.
- **Đổi Tên Nhóm Linh Hoạt**: Chạm vào tên hoặc biểu tượng bút ✏️ để đổi tên người chơi thực tế; badge trên bàn phím bài cập nhật đồng bộ.
- **Sảnh Bánh Xe ($A-2-3-4-5$)**: Đỉnh sảnh là 5, thua sảnh $2-3-4-5-6$ (đỉnh 6).
- **Kicker Poker**: $A-A-8-8-K$ thắng $A-A-8-8-Q$ nhờ Kicker King $>$ Queen.
- **Quy Tắc Omaha 2+3**: Cố tình có 4 lá Cơ trên tay và 1 lá Cơ trên bàn chung $\implies$ Không được tính Thùng (Flush).
- **Bắt Sập Hầm & Đè Hàng Mậu Binh**: Tự động tính sập hầm x2 ($3 \times 2 = 6$ chi), đè hàng x2 (khi cùng loại hàng), và phạt lủng đền toàn bàn.

