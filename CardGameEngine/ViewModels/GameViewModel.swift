import Foundation
import SwiftUI
import Combine

public enum InputMode: String, CaseIterable, Identifiable {
    case roundRobin = "Chia Tuần Tự (Tụ 1 ➔ Tụ 2 ➔ Tụ 3)"
    case manual = "Chọn Thủ Công Từng Tụ"
    
    public var id: String { rawValue }
    
    public var shortTitle: String {
        switch self {
        case .roundRobin: return "Chia Tuần Tự"
        case .manual: return "Chọn Từng Tụ"
        }
    }
}

public class GameViewModel: ObservableObject {
    @Published public var gameType: GameType = .lieng3 {
        didSet {
            resetTable()
        }
    }
    
    @Published public var suitPreset: SuitRulePreset = .north {
        didSet {
            if hasCalculatedResults {
                calculateResults()
            }
        }
    }
    
    @Published public var inputMode: InputMode = .roundRobin
    @Published public var numberOfPlayers: Int = 3 {
        didSet {
            updatePlayerCount()
        }
    }
    
    @Published public var players: [Player] = []
    @Published public var communityCards: [Card] = []
    @Published public var selectedPlayerIndex: Int = 0
    @Published public var isSelectingCommunity: Bool = false
    @Published public var roundRobinPointer: Int = 0
    
    // Result State
    @Published public var hasCalculatedResults: Bool = false
    @Published public var isShowResultModal: Bool = false
    @Published public var isShowingHistory: Bool = false
    @Published public var showdownSummary: String = ""
    @Published public var confrontationMatrix: [[String]] = []
    
    // Match History
    @Published public var history: [MatchHistoryRecord] = []
    
    // Action History for Undo
    private var actionHistory: [(card: Card, target: String)] = []
    
    // Voice Recognition - Realtime Confirmed Cards Snapshot
    @Published public var voiceService = SpeechRecognitionService()
    @Published public var voiceBannerText: String? = nil
    public private(set) var confirmedVoiceCards: [Card] = []
    public private(set) var currentSegmentConfirmedCards: [Card] = []
    private var pendingTenCard: ParsedVoiceCard? = nil
    private var pendingTenWorkItem: DispatchWorkItem? = nil
    private var processedVoiceCardsCount: Int = 0
    private var currentVoiceSegmentID: Int = 0
    private var lastVoiceCardPlacedTime: CFAbsoluteTime = 0
    private var lastProcessedTokenIndex: Int = -1
    
    // Rank-Only Mode (A->K) for 3 Cây & 2 Lá
    @Published public var isRankOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(isRankOnlyMode, forKey: "isRankOnlyMode")
            if isReadyToCalculate {
                calculateResults()
            }
        }
    }
    
    @Published public var showVoiceLicenseModal: Bool = false
    
    // Voice-Only Mode (Hides keyboard, shows large mic & voice actions)
    @Published public var isVoiceMode: Bool {
        didSet {
            if isVoiceMode && !LicenseService.shared.isVoiceUnlocked {
                DispatchQueue.main.async {
                    self.isVoiceMode = false
                    self.showVoiceLicenseModal = true
                }
                return
            }
            UserDefaults.standard.set(isVoiceMode, forKey: "isVoiceMode")
        }
    }

    // Floating Close Button (Nút Đóng nổi thứ 2 trong Bảng Điểm)
    @Published public var isFloatingCloseButtonEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFloatingCloseButtonEnabled, forKey: "isFloatingCloseButtonEnabled")
        }
    }

    @Published public var floatingCloseButtonRatioX: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(floatingCloseButtonRatioX), forKey: "floatingCloseButtonRatioX")
        }
    }

    @Published public var floatingCloseButtonRatioY: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(floatingCloseButtonRatioY), forKey: "floatingCloseButtonRatioY")
        }
    }

    @Published public var floatingCloseButtonSize: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(floatingCloseButtonSize), forKey: "floatingCloseButtonSize")
        }
    }

    
    public var isRankOnlyActive: Bool {
        return isRankOnlyMode && (gameType == .lieng3 || gameType == .xiDach2 || gameType == .samLoc10 || gameType == .chan19)
    }
    
    public func targetCards(for playerIndex: Int) -> Int {
        if gameType == .phom9 {
            return playerIndex == 0 ? 10 : 9
        }
        return gameType.cardsPerPlayer
    }
    
    public func renamePlayer(at index: Int, to newName: String) {
        guard index >= 0 && index < players.count else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            players[index].name = trimmed
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.isRankOnlyMode = UserDefaults.standard.bool(forKey: "isRankOnlyMode")
        LicenseService.shared.checkLicenseOffline()
        let savedVoice = UserDefaults.standard.bool(forKey: "isVoiceMode")
        if UserDefaults.standard.object(forKey: "isFloatingCloseButtonEnabled") != nil {
            self.isFloatingCloseButtonEnabled = UserDefaults.standard.bool(forKey: "isFloatingCloseButtonEnabled")
        } else {
            self.isFloatingCloseButtonEnabled = true
        }
        let savedRatioX = UserDefaults.standard.double(forKey: "floatingCloseButtonRatioX")
        self.floatingCloseButtonRatioX = savedRatioX > 0 ? CGFloat(savedRatioX) : 0.85
        let savedRatioY = UserDefaults.standard.double(forKey: "floatingCloseButtonRatioY")
        self.floatingCloseButtonRatioY = savedRatioY > 0 ? CGFloat(savedRatioY) : 0.85
        let savedSize = UserDefaults.standard.double(forKey: "floatingCloseButtonSize")
        self.floatingCloseButtonSize = savedSize > 0 ? CGFloat(savedSize) : 60
        setupInitialPlayers()
        setupVoiceServiceObservation()
    }
    
    private func setupVoiceServiceObservation() {
        voiceService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialPlayers() {
        players = (0..<numberOfPlayers).map { i in
            Player(name: "Tụ \(i + 1)")
        }
    }
    
    private func updatePlayerCount() {
        if players.count < numberOfPlayers {
            for i in players.count..<numberOfPlayers {
                players.append(Player(name: "Tụ \(i + 1)"))
            }
        } else if players.count > numberOfPlayers {
            players = Array(players.prefix(numberOfPlayers))
        }
        resetTable()
    }
    
    public func resetTable() {
        LicenseService.shared.checkLicenseOffline()
        let shouldAutoRecord = LicenseService.shared.isVoiceUnlocked && (isVoiceMode || voiceService.isRecording)
        if voiceService.isRecording {
            voiceService.stopRecording(callEndAudio: false)
            voiceBannerText = nil
        }
        for i in 0..<players.count {
            players[i].clearCards()
        }
        communityCards.removeAll()
        roundRobinPointer = 0
        selectedPlayerIndex = 0
        isSelectingCommunity = false
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        actionHistory.removeAll()
        confirmedVoiceCards.removeAll()
        currentSegmentConfirmedCards.removeAll()
        pendingTenWorkItem?.cancel()
        pendingTenWorkItem = nil
        pendingTenCard = nil
        processedVoiceCardsCount = 0
        currentVoiceSegmentID = 0
        
        if shouldAutoRecord {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.autoStartVoiceForNewRound()
            }
        }
    }
    
    public func startNewRound() {
        LicenseService.shared.checkLicenseOffline()
        let shouldAutoRecord = LicenseService.shared.isVoiceUnlocked && (isVoiceMode || voiceService.isRecording)
        if voiceService.isRecording {
            voiceService.stopRecording(callEndAudio: false)
            voiceBannerText = nil
        }
        for i in 0..<players.count {
            players[i].clearCards()
        }
        communityCards.removeAll()
        actionHistory.removeAll()
        isSelectingCommunity = false
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        roundRobinPointer = 0
        selectedPlayerIndex = 0
        confirmedVoiceCards.removeAll()
        currentSegmentConfirmedCards.removeAll()
        pendingTenWorkItem?.cancel()
        pendingTenWorkItem = nil
        pendingTenCard = nil
        processedVoiceCardsCount = 0
        currentVoiceSegmentID = 0
        lastVoiceCardPlacedTime = 0
        lastProcessedTokenIndex = -1
        
        if shouldAutoRecord {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.autoStartVoiceForNewRound()
            }
        }
    }
    
    public func autoStartVoiceForNewRound() {
        LicenseService.shared.checkLicenseOffline()
        guard LicenseService.shared.isVoiceUnlocked else {
            self.isVoiceMode = false
            self.voiceService.stopRecording(callEndAudio: false)
            self.voiceBannerText = nil
            self.showVoiceLicenseModal = true
            return
        }

        confirmedVoiceCards.removeAll()
        currentSegmentConfirmedCards.removeAll()
        pendingTenWorkItem?.cancel()
        pendingTenWorkItem = nil
        pendingTenCard = nil
        processedVoiceCardsCount = 0
        currentVoiceSegmentID = 0
        lastVoiceCardPlacedTime = 0
        lastProcessedTokenIndex = -1
        voiceService.requestAuthorization { [weak self] authorized in
            guard let self = self, authorized else { return }
            self.voiceBannerText = "🎙️ Đang nghe [\(self.voiceService.currentInputDeviceName)]... Hãy đọc bài"
            self.voiceService.startRecording(
                onResult: { [weak self] spokenText, segmentID in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.processSpokenVoice(spokenText, segmentID: segmentID)
                    }
                },
                onError: { [weak self] errorMsg in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.voiceBannerText = errorMsg
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                            if self?.voiceService.isRecording == false {
                                self?.voiceBannerText = nil
                            }
                        }
                    }
                }
            )
        }
    }
    
    // Check if a card is currently assigned
    public func cardOwner(_ card: Card) -> String? {
        for p in players {
            if p.cards.contains(card) {
                return p.name
            }
        }
        if communityCards.contains(card) {
            return "Bài chung"
        }
        return nil
    }
    
    // Handle card click
    public func onCardTapped(_ card: Card) {
        // If already selected, do NOT remove from keypad! (Users must tap the card on the player's mat to remove)
        if cardOwner(card) != nil {
            return
        }
        
        let commTargetCount = gameType.communityCardsCount
        
        if inputMode == .roundRobin {
            // Find next player who still needs cards
            var dealtToPlayer = false
            var attempts = 0
            while attempts < players.count {
                let idx = (roundRobinPointer + attempts) % players.count
                let targetCount = targetCards(for: idx)
                if players[idx].cards.count < targetCount {
                    players[idx].cards.append(card)
                    actionHistory.append((card: card, target: players[idx].id))
                    
                    // Find next player who actually still needs cards!
                    var nextNeedingIdx: Int? = nil
                    for offset in 1...players.count {
                        let checkIdx = (idx + offset) % players.count
                        if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                            nextNeedingIdx = checkIdx
                            break
                        }
                    }
                    
                    if let next = nextNeedingIdx {
                        roundRobinPointer = next
                        isSelectingCommunity = false
                    } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                        // All players full, but community cards still needed
                        isSelectingCommunity = true
                    }
                    
                    dealtToPlayer = true
                    break
                }
                attempts += 1
            }
            
            // If all players have full cards, deal to community cards
            if !dealtToPlayer && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
            }
            
        } else {
            // Manual selection mode
            if isSelectingCommunity {
                if communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            } else if selectedPlayerIndex < players.count {
                let targetCount = targetCards(for: selectedPlayerIndex)
                if players[selectedPlayerIndex].cards.count < targetCount {
                    players[selectedPlayerIndex].cards.append(card)
                    actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                    
                    // Auto-advance to next player who still needs cards if current player is full
                    if players[selectedPlayerIndex].cards.count == targetCards(for: selectedPlayerIndex) {
                        var nextNeedingIdx: Int? = nil
                        for offset in 1..<players.count {
                            let checkIdx = (selectedPlayerIndex + offset) % players.count
                            if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                                nextNeedingIdx = checkIdx
                                break
                            }
                        }
                        
                        if let next = nextNeedingIdx {
                            selectedPlayerIndex = next
                        } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                            isSelectingCommunity = true
                        }
                    }
                } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            }
        }
        
        // Auto-calculate immediately when all cards are dealt (no need to press "So bài")
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Clear Community Cards (Dấu X xóa nhanh bài chung cho Poker)
    public func clearCommunityCards() {
        actionHistory.removeAll { $0.target == "COMMUNITY" }
        communityCards.removeAll()
        isSelectingCommunity = true
        clearResultsState()
    }

    // Rank-Only Tap Handler (allows multiple taps of the same rank without locking)
    public func onRankTapped(_ rank: Rank) {
        clearResultsState()
        
        let cardId = "rank_\(rank.rawValue)_\(UUID().uuidString)"
        let card = Card(rank: rank, suit: .spades, customId: cardId, isRankOnly: true)
        let commTargetCount = gameType.communityCardsCount
        
        if inputMode == .roundRobin {
            var nextNeedingIdx: Int? = nil
            for i in 0..<players.count {
                let checkIdx = (roundRobinPointer + i) % players.count
                if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                    nextNeedingIdx = checkIdx
                    break
                }
            }
            
            if let idx = nextNeedingIdx {
                players[idx].cards.append(card)
                actionHistory.append((card: card, target: players[idx].id))
                roundRobinPointer = (idx + 1) % players.count
                selectedPlayerIndex = roundRobinPointer
            } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
            }
        } else {
            if isSelectingCommunity && commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
            } else {
                let targetCount = targetCards(for: selectedPlayerIndex)
                if players[selectedPlayerIndex].cards.count < targetCount {
                    players[selectedPlayerIndex].cards.append(card)
                    actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                    
                    if players[selectedPlayerIndex].cards.count == targetCount {
                        var nextNeedingIdx: Int? = nil
                        for i in 0..<players.count {
                            let checkIdx = (selectedPlayerIndex + 1 + i) % players.count
                            if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                                nextNeedingIdx = checkIdx
                                break
                            }
                        }
                        if let next = nextNeedingIdx {
                            selectedPlayerIndex = next
                        } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                            isSelectingCommunity = true
                        }
                    }
                } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            }
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Hidden Card Tap Handler ("Không thấy" button - allows multiple taps without locking)
    public func onHiddenCardTapped() {
        clearResultsState()
        
        let cardId = "hidden_\(UUID().uuidString)"
        let card = Card(rank: .two, suit: .spades, customId: cardId, isHidden: true)
        let commTargetCount = gameType.communityCardsCount
        
        if inputMode == .roundRobin {
            var nextNeedingIdx: Int? = nil
            for i in 0..<players.count {
                let checkIdx = (roundRobinPointer + i) % players.count
                if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                    nextNeedingIdx = checkIdx
                    break
                }
            }
            
            if let idx = nextNeedingIdx {
                players[idx].cards.append(card)
                actionHistory.append((card: card, target: players[idx].id))
                roundRobinPointer = (idx + 1) % players.count
                selectedPlayerIndex = roundRobinPointer
            } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
            }
        } else {
            if isSelectingCommunity && commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
            } else {
                let targetCount = targetCards(for: selectedPlayerIndex)
                if players[selectedPlayerIndex].cards.count < targetCount {
                    players[selectedPlayerIndex].cards.append(card)
                    actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                    
                    if players[selectedPlayerIndex].cards.count == targetCount {
                        var nextNeedingIdx: Int? = nil
                        for i in 0..<players.count {
                            let checkIdx = (selectedPlayerIndex + 1 + i) % players.count
                            if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                                nextNeedingIdx = checkIdx
                                break
                            }
                        }
                        if let next = nextNeedingIdx {
                            selectedPlayerIndex = next
                        } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                            isSelectingCommunity = true
                        }
                    }
                } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            }
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // MARK: - Voice Recognition Handling
    public func toggleVoiceRecognition() {
        if voiceService.isRecording {
            voiceService.stopRecording(callEndAudio: false)
            voiceBannerText = "⏹️ Đã dừng ghi âm"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if self?.voiceService.isRecording == false {
                    self?.voiceBannerText = nil
                }
            }
        } else {
            // Kiểm tra Bản quyền giọng nói theo máy (chạy Offline 100%)
            LicenseService.shared.checkLicenseOffline()
            if !LicenseService.shared.isVoiceUnlocked {
                self.showVoiceLicenseModal = true
                return
            }

            voiceService.requestAuthorization { [weak self] authorized in

                guard let self = self else { return }
                if authorized {
                    self.voiceBannerText = "🎙️ Đang nghe [\(self.voiceService.currentInputDeviceName)]... Hãy đọc bài"
                    self.voiceService.startRecording(
                        onResult: { [weak self] spokenText, segmentID in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                self.processSpokenVoice(spokenText, segmentID: segmentID)
                            }
                        },
                        onError: { [weak self] errorMsg in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                self.voiceBannerText = errorMsg
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                                    if self?.voiceService.isRecording == false {
                                        self?.voiceBannerText = nil
                                    }
                                }
                            }
                        }
                    )
                } else {
                    self.voiceBannerText = "Chưa cấp quyền microphone/nhận diện giọng nói."
                }
            }
        }
    }
    
    public func flushPendingVoiceCards() {
        if let workItem = pendingTenWorkItem {
            workItem.cancel()
            pendingTenWorkItem = nil
        }
        if let pending = pendingTenCard {
            executePlaceVoiceCard(pending)
            pendingTenCard = nil
        }
    }

    public func processSpokenVoice(_ text: String, segmentID: Int = 0) {
        if segmentID != 0 && segmentID != currentVoiceSegmentID {
            flushPendingVoiceCards()
            currentVoiceSegmentID = segmentID
            currentSegmentConfirmedCards.removeAll()
            lastProcessedTokenIndex = -1
        }
        
        let displaySpoken = VietnameseCardVoiceParser.separateDigits(text)
        if !displaySpoken.isEmpty {
            voiceBannerText = "🎙️ \"\(displaySpoken)\""
        }
        
        if isReadyToCalculate {
            if voiceService.isRecording {
                voiceService.stopRecording(callEndAudio: false)
                self.voiceBannerText = "✅ Đã chia đủ bài - Xong ván!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    if self?.voiceService.isRecording == false {
                        self?.voiceBannerText = nil
                    }
                }
            }
            return
        }

        let parsedCards = VietnameseCardVoiceParser.parse(text)
        guard !parsedCards.isEmpty else { return }

        // BỘ LỌC REALTIME SONG SONG VỚI APPLE
        // So khớp trực tiếp chuỗi lá bài của Apple với Bản đối chiếu thời gian thực của segment hiện tại (currentSegmentConfirmedCards).
        // Mọi sửa đổi hồi tố của Apple ("nắm năm" -> "5 5", "hai" -> "2 2 2") đều bị hấp thụ/lọc sạch!
        var confirmedIdx = 0
        var newCardsToPlace: [ParsedVoiceCard] = []
        
        var i = 0
        while i < parsedCards.count {
            let candidate = parsedCards[i]
            
            if confirmedIdx < currentSegmentConfirmedCards.count {
                let confirmedCard = currentSegmentConfirmedCards[confirmedIdx]
                let matchesConfirmed = (!candidate.isHidden && candidate.rank == confirmedCard.rank) || (candidate.isHidden && confirmedCard.isHidden)
                
                if matchesConfirmed {
                    confirmedIdx += 1
                    i += 1
                } else if confirmedIdx + 1 < currentSegmentConfirmedCards.count &&
                          !candidate.isHidden &&
                          ((candidate.rank == .queen && currentSegmentConfirmedCards[confirmedIdx].rank == .ace && currentSegmentConfirmedCards[confirmedIdx + 1].rank == .two) ||
                           (candidate.rank == .jack && currentSegmentConfirmedCards[confirmedIdx].rank == .ace && currentSegmentConfirmedCards[confirmedIdx + 1].rank == .ace) ||
                           (candidate.rank == .king && currentSegmentConfirmedCards[confirmedIdx].rank == .ace && currentSegmentConfirmedCards[confirmedIdx + 1].rank == .three)) {
                    // Apple tự động gộp 2 số đã chốt trong quá khứ thành 1 số (ví dụ: [1, 2] -> 12/Q, [1, 1] -> 11/J, [1, 3] -> 13/K)
                    // Token này đại diện cho CẢ 2 LÁ đã chốt trong bản đối chiếu -> Hấp thụ cả 2 lá quá khứ!
                    confirmedIdx += 2
                    lastProcessedTokenIndex = candidate.tokenIndex
                    i += 1
                } else {
                    // Apple sửa đổi từ cũ trong quá khứ -> Theo quy tắc: sau khi Apple sửa đều vô hiệu, giữ nguyên bản đối chiếu
                    confirmedIdx += 1
                    i += 1
                }
            } else {
                // Đã đối chiếu xong toàn bộ các lá trong bản đối chiếu.
                // Các lá còn lại ở đuôi stream là lá MỚI THẬT SỰ xuất hiện theo thời gian thực!
                // Chỉ nhận khi tokenIndex nằm sau vùng từ vựng đã xử lý của các lá trước
                if candidate.tokenIndex > lastProcessedTokenIndex {
                    newCardsToPlace.append(candidate)
                }
                i += 1
            }
        }
        
        // Huỷ bỏ hẹn giờ cũ nếu còn
        if pendingTenWorkItem != nil {
            pendingTenWorkItem?.cancel()
            pendingTenWorkItem = nil
            pendingTenCard = nil
        }

        guard !newCardsToPlace.isEmpty else { return }

        // Chia bài tức thì 0ms cho mọi lá bài (kể cả lá 10)
        for item in newCardsToPlace {
            executePlaceVoiceCard(item)

            if isReadyToCalculate {
                break
            }
        }
    }

    private func executePlaceVoiceCard(_ item: ParsedVoiceCard) {
        let countBefore = actionHistory.count
        if item.isHidden {
            onHiddenCardTapped()
        } else if isRankOnlyActive || item.suit == nil {
            onRankTapped(item.rank)
        } else if let suit = item.suit {
            let card = Card(rank: item.rank, suit: suit)
            if cardOwner(card) == nil {
                onCardTapped(card)
            } else {
                onRankTapped(item.rank)
            }
        }

        if actionHistory.count > countBefore, let lastAction = actionHistory.last {
            confirmedVoiceCards.append(lastAction.card)
            currentSegmentConfirmedCards.append(lastAction.card)
            lastProcessedTokenIndex = max(lastProcessedTokenIndex, item.tokenIndex)
            voiceService.appendActionLog("  ➔ ✅ [CHIA BÀI] Gán lá \(lastAction.card.rank.displaySymbol) vào \(lastAction.target)")
        }
    }
    
    public func getVoiceLogText() -> String {
        return voiceService.getFormattedVoiceLog()
    }
    
    public func clearVoiceLogs() {
        voiceService.clearVoiceLogs()
    }
    
    // Clear calculated results when cards change
    private func clearResultsState() {
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        for i in 0..<players.count {
            players[i].rankOrder = nil
            players[i].score = 0
            players[i].resultTitle = ""
            players[i].resultDetail = ""
            players[i].isLung = false
        }
    }
    
    // Remove specific card: return focus to the exact player that lost the card!
    public func removeCard(_ card: Card) {
        for i in 0..<players.count {
            if let idx = players[i].cards.firstIndex(of: card) {
                players[i].cards.remove(at: idx)
                actionHistory.removeAll { $0.card == card }
                
                // Set focus back to this player so next card tapped goes to this player!
                selectedPlayerIndex = i
                roundRobinPointer = i
                isSelectingCommunity = false
                break
            }
        }
        if let cIdx = communityCards.firstIndex(of: card) {
            communityCards.remove(at: cIdx)
            actionHistory.removeAll { $0.card == card }
            isSelectingCommunity = true
        }
        clearResultsState()
    }
    
    // Undo last card
    public func undoLastAction() {
        guard let last = actionHistory.popLast() else { return }
        removeCard(last.card)
    }
    
    // Random Deal for Testing
    public func autoDealRandom() {
        resetTable()
        var deck = Card.fullDeck52.shuffled()
        
        for i in 0..<players.count {
            let targetCount = targetCards(for: i)
            players[i].cards = Array(deck.prefix(targetCount))
            deck.removeFirst(targetCount)
        }
        
        let commTargetCount = gameType.communityCardsCount
        if commTargetCount > 0 && deck.count >= commTargetCount {
            let commDealt = Array(deck.prefix(commTargetCount))
            communityCards = commDealt
            deck.removeFirst(commTargetCount)
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Check if table is ready for calculation
    public var isReadyToCalculate: Bool {
        if gameType == .phom9 {
            guard !players.isEmpty else { return false }
            return players.indices.allSatisfy { players[$0].cards.count == targetCards(for: $0) }
        }
        let allPlayersFull = players.allSatisfy { $0.cards.count == gameType.cardsPerPlayer }
        let commFull = communityCards.count == gameType.communityCardsCount
        return allPlayersFull && commFull && !players.isEmpty
    }
    
    // Calculate Winner & Results
    public func calculateResults() {
        guard isReadyToCalculate else { return }
        
        switch gameType {
        case .chan19:
            calculateChan19()
        case .samLoc10:
            calculateSamLoc()
        case .phom9:
            calculatePhom()
        case .lieng3:
            calculateLieng()
        case .binh9:
            calculateBinh9()
        case .binh6Poker:
            calculateBinh6Poker()
        case .xiDach2:
            calculateXiDach()
        case .texasHoldem:
            calculateTexasHoldem()
        }
        
        hasCalculatedResults = true
        isShowResultModal = true
        
        // Ghi lại lịch sử ván đấu (Match History)
        recordMatchToHistory()
    }
    
    private func recordMatchToHistory() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        
        let winner = players.min(by: { ($0.rankOrder ?? 99) < ($1.rankOrder ?? 99) })
        let scores = players.map {
            PlayerScoreHistory(name: $0.name, rank: $0.rankOrder ?? 0, score: $0.score, hand: $0.resultTitle)
        }
        let record = MatchHistoryRecord(
            id: UUID(),
            time: timeStr,
            gameName: gameType.rawValue,
            winnerName: winner?.name ?? "—",
            winnerDetail: winner?.resultTitle ?? "",
            playerScores: scores
        )
        history.insert(record, at: 0)
        if history.count > 50 {
            history.removeLast()
        }
    }

    
    // MARK: - Game Calculation Logic
    
    private func calculateChan19() {
        var currentRank = 1
        for i in 0..<players.count {
            if players[i].cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                players[i].rankOrder = currentRank
                players[i].score = 0
                players[i].resultTitle = "\(players[i].cards.count) lá"
                players[i].resultDetail = "Chắn Trung Quốc (19 lá)"
                currentRank += 1
            }
        }
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Chắn với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculateSamLoc() {
        var validPlayers = [(index: Int, name: String, cards: [Card])]()
        for (i, p) in players.enumerated() {
            if p.cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                validPlayers.append((index: i, name: p.name, cards: p.cards))
            }
        }
        
        if !validPlayers.isEmpty {
            let ranked = SamLocEvaluator.rankPlayers(players: validPlayers)
            for item in ranked {
                let idx = item.index
                players[idx].rankOrder = item.rank
                players[idx].score = item.scoreDelta
                if let instant = item.result.instantWin {
                    players[idx].resultTitle = instant.rawValue
                } else if item.result.trashCount == 0 {
                    players[idx].resultTitle = "🎉 Hết Rác (Bài Vào Bộ Hết)"
                } else {
                    players[idx].resultTitle = "Còn \(item.result.trashCount) lá rác"
                }
                players[idx].resultDetail = item.result.summary
            }
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Hòa ván Sâm với \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng ván Sâm với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculatePhom() {
        var validPlayers = [(index: Int, name: String, cards: [Card])]()
        for (i, p) in players.enumerated() {
            if p.cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                validPlayers.append((index: i, name: p.name, cards: p.cards))
            }
        }
        
        if !validPlayers.isEmpty {
            let ranked = PhomEvaluator.rankPlayers(players: validPlayers)
            for item in ranked {
                let idx = item.index
                players[idx].rankOrder = item.rank
                players[idx].score = item.scoreDelta
                if item.result.isUTron {
                    players[idx].resultTitle = "🎉 Ù Tròn (0 điểm)"
                } else if item.result.isUKhan {
                    players[idx].resultTitle = "🎉 Ù Khan (Không cạ)"
                } else if item.result.isU {
                    players[idx].resultTitle = "🎉 Ù (0 điểm)"
                } else if item.result.isMom {
                    players[idx].resultTitle = "💀 Móm / Cháy (\(item.result.deadwoodScore)đ)"
                } else {
                    players[idx].resultTitle = "\(item.result.deadwoodScore) điểm rác (\(item.result.phoms.count) phỏm)"
                }
                players[idx].resultDetail = item.result.summary
            }
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Hòa ván Phỏm với \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng ván Phỏm với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculateLieng() {
        let rule = isRankOnlyActive ? .international : suitPreset
        var scores = [(index: Int, score: LiengHandScore)]()
        for (i, p) in players.enumerated() {
            if p.cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                let score = LiengEvaluator.evaluate(cards: p.cards, suitRule: rule)
                scores.append((index: i, score: score))
                players[i].resultTitle = score.descriptionVN
                players[i].resultDetail = "Loại: \(score.handType.nameVN)"
            }
        }
        
        scores.sort { $0.score > $1.score }
        
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng cuộc với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculateXiDach() {
        var scores = [(index: Int, score: XiDachScore)]()
        for (i, p) in players.enumerated() {
            if p.cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                let score = XiDachEvaluator.evaluate(cards: p.cards)
                scores.append((index: i, score: score))
                players[i].resultTitle = score.title
                players[i].resultDetail = score.detail
            }
        }
        
        scores.sort { $0.score > $1.score }
        
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng cuộc với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculateTexasHoldem() {
        var scores = [(index: Int, score: PokerHandScore)]()
        let commHasHidden = communityCards.contains(where: { $0.isHidden })
        for (i, p) in players.enumerated() {
            let playerHasHidden = p.cards.contains(where: { $0.isHidden })
            if commHasHidden || playerHasHidden {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                let allCards = p.cards + communityCards
                let score = PokerEvaluator.evaluate7Cards(allCards)
                scores.append((index: i, score: score))
                players[i].resultTitle = score.descriptionVN
                players[i].resultDetail = "Bộ bài 5 lá tốt nhất: \(score.cards.map { $0.displayName }.joined(separator: " "))"
            }
        }
        
        scores.sort { $0.score > $1.score }
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1 (Split Pot): \(names) với \(rank1Players[0].resultTitle)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Pot với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculateBinh9() {
        var validIndices = [Int]()
        var arrangements = [Int: Binh9Arrangement]()
        for i in 0..<players.count {
            if players[i].cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                let arr = Binh9Evaluator.autoArrange(cards: players[i].cards)
                arrangements[i] = arr
                players[i].cards = arr.chi1 + arr.chi2 + arr.chi3
                players[i].isLung = arr.isLung
                players[i].score = 0
                validIndices.append(i)
            }
        }
        
        // So chéo giữa các nhà hợp lệ
        for a in 0..<validIndices.count {
            let i = validIndices[a]
            guard let arrI = arrangements[i] else { continue }
            for b in (a + 1)..<validIndices.count {
                let j = validIndices[b]
                guard let arrJ = arrangements[j] else { continue }
                let res = Binh9Evaluator.compareMatch(a: arrI, b: arrJ)
                if res.scoreA > 0 {
                    players[i].score += 1
                } else if res.scoreA < 0 {
                    players[j].score += 1
                }
            }
        }
        
        let totalOpponents = max(1, validIndices.count - 1)
        for i in validIndices {
            guard let arr = arrangements[i] else { continue }
            if let win = arr.instantWin {
                players[i].resultTitle = win
                players[i].resultDetail = "Thắng trắng toàn bàn!"
            } else if arr.isLung {
                players[i].resultTitle = "⚠️ BỊ LỦNG"
                players[i].resultDetail = "Chi trước yếu hơn chi sau (Xử thua)!"
            } else {
                if totalOpponents == 1 {
                    let otherIdx = validIndices.first(where: { $0 != i }) ?? i
                    let otherArr = arrangements[otherIdx]
                    let isTie = otherArr != nil && arr.score1 == otherArr!.score1 && arr.score2 == otherArr!.score2 && arr.score3 == otherArr!.score3
                    players[i].resultTitle = players[i].score > 0 ? "🏆 THẮNG ĐỐI ĐẦU" : (isTie ? "HÒA ĐỐI ĐẦU" : "THUA ĐỐI ĐẦU")
                } else {
                    players[i].resultTitle = "Thắng \(players[i].score)/\(totalOpponents) nhà"
                }
                players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN) | Chi 2: \(arr.score2.descriptionVN) | Chi 3: \(arr.score3.descriptionVN)"
            }
        }
        
        var sortedIndices = validIndices
        sortedIndices.sort { players[$0].score > players[$1].score }
        var currentRank = 1
        for i in 0..<sortedIndices.count {
            let idx = sortedIndices[i]
            if i > 0 {
                let prevIdx = sortedIndices[i - 1]
                if players[idx].score < players[prevIdx].score {
                    currentRank = i + 1
                }
            }
            players[idx].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng thắng \(rank1Players[0].score) nhà)!"
        } else if let winner = rank1Players.first {
            if totalOpponents == 1 {
                showdownSummary = "🏆 \(winner.name) Thắng ván đấu (Ăn ít nhất 2 chi)!"
            } else {
                showdownSummary = "🏆 \(winner.name) Về Nhất Binh 9 lá (Thắng \(winner.score)/\(totalOpponents) nhà)!"
            }
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
    
    private func calculateBinh6Poker() {
        var scores = [(index: Int, score: PokerHandScore)]()
        for (i, p) in players.enumerated() {
            if p.cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài (Không thấy) • Loại khỏi BXH"
            } else {
                let s = Binh6Evaluator.evaluatePoker6(p.cards)
                scores.append((index: i, score: s))
                players[i].resultTitle = s.descriptionVN
                players[i].resultDetail = "Bộ 5 lá tốt nhất từ 6 lá: \(s.cards.map { $0.displayName }.joined(separator: " "))"
            }
        }
        scores.sort { $0.score > $1.score }
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) với \(rank1Players[0].resultTitle)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Binh 6 lá với \(winner.resultTitle)!"
        } else {
            showdownSummary = "⚠️ Không thể xác định người thắng (Có quân bài ẩn)"
        }
    }
}
