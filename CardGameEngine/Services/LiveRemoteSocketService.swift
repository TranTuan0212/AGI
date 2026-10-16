import Foundation
import UIKit

/// LiveRemoteSocketService: Kết nối Realtime 2 chiều với Server (Socket.IO v4 over WebSocket)
/// Lắng nghe số được bấm trực tiếp trên Bảng Nhập Nổi khi phóng to Màn hình Live trên Web
/// và bắn lập tức về App điện thoại với độ trễ ~0ms.
public class LiveRemoteSocketService: NSObject, ObservableObject {
    public static let shared = LiveRemoteSocketService()

    @Published public var isConnected: Bool = false {
        didSet {
            onConnectionStatusChanged?(isConnected)
        }
    }
    @Published public var connectionStatus: String = "Chưa kết nối"
    @Published public var lastReceivedCard: String? = nil

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var isIntentionalDisconnect: Bool = false
    private var activeRoomId: String? = nil

    /// Callback khi nhận số từ Web Live: cardValue ("1"..."13", "0", "__hidden__"), action ("ADD", "DELETE", "CLEAR")
    public var onRemoteCardReceived: ((_ cardValue: String?, _ action: String) -> Void)?
    /// Callback khi trạng thái kết nối thay đổi
    public var onConnectionStatusChanged: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    /// Bắt đầu kết nối Socket.IO tới Server
    public func connect(serverURL: String, token: String?, roomId: String?) {
        disconnect()
        isIntentionalDisconnect = false
        self.activeRoomId = roomId ?? AppAuthManager.shared.currentUserId ?? AppAuthManager.shared.currentUsername

        var wsBase = AppAuthManager.normalizeURL(serverURL)
        if wsBase.hasPrefix("https://") {
            wsBase = "wss://" + wsBase.dropFirst("https://".count)
        } else if wsBase.hasPrefix("http://") {
            wsBase = "ws://" + wsBase.dropFirst("http://".count)
        }

        var fullUrlStr = "\(wsBase)/socket.io/?EIO=4&transport=websocket"
        if let t = token, !t.isEmpty {
            fullUrlStr += "&token=\(t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t)"
        }

        guard let url = URL(string: fullUrlStr) else {
            self.connectionStatus = "URL không hợp lệ"
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        if let t = token, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: OperationQueue.main)
        self.webSocketTask = session.webSocketTask(with: request)
        self.connectionStatus = "Đang kết nối tới Live Server..."
        self.webSocketTask?.resume()

        listenForMessages(roomId: roomId)
    }

    /// Đóng kết nối
    public func disconnect() {
        isIntentionalDisconnect = true
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Đã ngắt kết nối"
        }
    }

    private func listenForMessages(roomId: String?) {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, !self.isIntentionalDisconnect else { return }

            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.connectionStatus = "Lỗi kết nối: \(error.localizedDescription)"
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleSocketIOPacket(text, roomId: roomId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleSocketIOPacket(text, roomId: roomId)
                    }
                @unknown default:
                    break
                }
                // Tiếp tục lắng nghe tin nhắn tiếp theo
                self.listenForMessages(roomId: roomId)
            }
        }
    }

    /// Phân giải các gói tin theo giao thức chuẩn Socket.IO v4 Engine.IO
    private func handleSocketIOPacket(_ packet: String, roomId: String?) {
        guard !packet.isEmpty else { return }

        // Gói tin bắt đầu bằng '0': Server Engine.IO Handshake
        if packet.hasPrefix("0") {
            // Gửi gói '40' (Socket.IO CONNECT)
            sendRaw("40")
            startHeartbeat()
        }
        // Gói tin '2': Ping từ Server -> Phản hồi '3' (Pong)
        else if packet.hasPrefix("2") {
            sendRaw("3")
        }
        // Gói tin '40': Socket.IO Connected thành công
        else if packet.hasPrefix("40") {
            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionStatus = "🟢 Đã kết nối Live Realtime"
            }
            // Gửi lệnh join_room
            let targetRoom = roomId ?? self.activeRoomId ?? AppAuthManager.shared.currentUserId ?? AppAuthManager.shared.currentUsername ?? "viewer"
            let joinPacket = "42[\"join_room\",{\"roomId\":\"\(targetRoom)\"}]"
            sendRaw(joinPacket)
        }
        // Gói tin '42': Socket.IO Event chứa JSON Array: ["event_name", payload]
        else if packet.hasPrefix("42") {
            let jsonPayload = String(packet.dropFirst(2))
            guard let data = jsonPayload.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let eventName = array.first as? String else {
                return
            }

            if eventName == "remote_card_received", array.count > 1, let payload = array[1] as? [String: Any] {
                let cardValue = payload["cardValue"] as? String
                let action = (payload["action"] as? String) ?? "ADD"

                DispatchQueue.main.async {
                    self.lastReceivedCard = cardValue
                    self.onRemoteCardReceived?(cardValue, action)
                }
            }
        }
    }

    private func sendRaw(_ text: String) {
        let msg = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(msg) { error in
            if let err = error {
                print("[LiveRemoteSocketService] Lỗi gửi socket:", err)
            }
        }
    }

    private func startHeartbeat() {
        pingTimer?.invalidate()
        // Gửi ping mỗi 25s để giữ kết nối
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.sendRaw("3")
        }
    }

    /// Gửi một lá bài vừa đọc bằng giọng nói hoặc thao tác lên Server để đồng bộ sang Web
    public func sendRemoteCard(cardValue: String?, action: String = "ADD", roomId: String? = nil) {
        guard isConnected else { return }
        let targetRoom = roomId ?? self.activeRoomId ?? AppAuthManager.shared.currentUserId ?? AppAuthManager.shared.currentUsername ?? "viewer"
        var dict: [String: Any] = [
            "action": action,
            "roomId": targetRoom
        ]
        if let cv = cardValue {
            dict["cardValue"] = cv
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict),
              let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return
        }
        let packet = "42[\"live_remote_card\",\(jsonStr)]"
        sendRaw(packet)
    }
}
