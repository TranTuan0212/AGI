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
    
    // Server 2 3-Card Evaluation & State
    @Published public var server2HandResults: [Server2HandResult] = []
    @Published public var server2LeaderboardChain: String = ""
    @Published public var server2WinnerTitle: String = ""
    @Published public var server2CompleteCount: Int = 0
    
    // Action History for Undo
    private var actionHistory: [(card: Card, target: String)] = []
    public var canUndo: Bool { !actionHistory.isEmpty }
    
    // Voice Recognition - Realtime Confirmed Cards Snapshot
    @Published public var voiceService = SpeechRecognitionService()
    @Published public var sherpaService = SherpaSpeechRecognitionService.shared
    @Published public var voiceBannerText: String? = nil
    public private(set) var confirmedVoiceCards: [Card] = []
    public private(set) var currentSegmentConfirmedCards: [Card] = []
    private var pendingTenCard: ParsedVoiceCard? = nil
    private var pendingTenWorkItem: DispatchWorkItem? = nil
    private var processedVoiceCardsCount: Int = 0
    private var currentVoiceSegmentID: Int = 0
    private var lastVoiceCardPlacedTime: CFAbsoluteTime = 0
    private var lastProcessedTokenIndex: Int = -1
    private var lastProcessedVoiceText: String = ""
    
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

    // Online Remote Live Keypad Session (Nhập từ màn hình Live Web truyền về App)
    @Published public var isOnlineRemoteMode: Bool = false {
        didSet {
            if isOnlineRemoteMode {
                startOnlineRemoteSession()
            } else {
                stopOnlineRemoteSession()
            }
        }
    }
    @Published public var isOnlineRemoteConnected: Bool = false

    // Live Web Sync Switch (Công tắc đồng bộ bài giọng nói và reset/hoàn tác 2 chiều với Web Live)
    @Published public var isLiveSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLiveSyncEnabled, forKey: "isLiveSyncEnabled")
            if isLiveSyncEnabled {
                startLiveSyncSession()
            } else if !isOnlineRemoteMode {
                stopLiveSyncSession()
            }
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
        return isRankOnlyMode
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
        self.isVoiceMode = LicenseService.shared.isVoiceUnlocked && savedVoice
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
        if UserDefaults.standard.object(forKey: "isLiveSyncEnabled") != nil {
            self.isLiveSyncEnabled = UserDefaults.standard.bool(forKey: "isLiveSyncEnabled")
        } else {
            self.isLiveSyncEnabled = true // Mặc định BẬT để sẵn sàng đồng bộ sang Web
        }
        setupInitialPlayers()
        setupVoiceServiceObservation()
        if self.isLiveSyncEnabled {
            startLiveSyncSession()
        }
    }
    
    private func setupVoiceServiceObservation() {
        voiceService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        sherpaService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.sherpaService.isRecording {
                    self.voiceService.isRecording = true
                    self.voiceService.audioLevel = self.sherpaService.audioLevel
                    self.voiceService.clarityStatus = self.sherpaService.clarityStatus
                    self.voiceService.clarityColor = self.sherpaService.clarityColor
                    self.voiceService.recognizedText = self.sherpaService.recognizedText
                } else if !self.voiceService.isAcceptingAudio {
                    self.voiceService.isRecording = false
                }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupInitialPlayers() {
        players = (0..<numberOfPlayers).map { i in
            Player(name: "Tụ \(i + 1)")
        }
        updateServer2Evaluation()
    }
    
    private func updatePlayerCount() {
        if players.count < numberOfPlayers {
            for i in players.count..<numberOfPlayers {
                players.append(Player(name: "Tụ \(i + 1)"))
            }
        } else if players.count > numberOfPlayers {
            players = Array(players.prefix(numberOfPlayers))
        }
        resetServer2Table()
    }
    
    public func resetTable(isFromRemote: Bool = false) {
        LicenseService.shared.checkLicenseOffline()
        let shouldAutoRecord = LicenseService.shared.isVoiceUnlocked && (isVoiceMode || voiceService.isRecording || sherpaService.isRecording)
        if voiceService.isRecording || sherpaService.isRecording {
            sherpaService.stopRecording()
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
        lastProcessedVoiceText = ""
        
        if shouldAutoRecord {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.autoStartVoiceForNewRound()
            }
        }
        if !isFromRemote && (isLiveSyncEnabled || isOnlineRemoteMode) && LiveRemoteSocketService.shared.isConnected {
            LiveRemoteSocketService.shared.sendRemoteCard(cardValue: nil, action: "CLEAR")
        }
    }
    
    public func startNewRound() {
        LicenseService.shared.checkLicenseOffline()
        let shouldAutoRecord = LicenseService.shared.isVoiceUnlocked && (isVoiceMode || voiceService.isRecording || sherpaService.isRecording)
        if voiceService.isRecording || sherpaService.isRecording {
            sherpaService.stopRecording()
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
        lastProcessedVoiceText = ""
        
        if shouldAutoRecord {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.autoStartVoiceForNewRound()
            }
        }
        if (isLiveSyncEnabled || isOnlineRemoteMode) && LiveRemoteSocketService.shared.isConnected {
            LiveRemoteSocketService.shared.sendRemoteCard(cardValue: nil, action: "CLEAR")
        }
    }
    
    public func autoStartVoiceForNewRound() {
        LicenseService.shared.checkLicenseOffline()
        guard LicenseService.shared.isVoiceUnlocked else {
            self.isVoiceMode = false
            self.sherpaService.stopRecording()
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
        lastProcessedVoiceText = ""
        if sherpaService.isModelLoaded {
            self.voiceBannerText = "🎙️ Đang nghe [AI Offline]... Hãy đọc bài"
            self.sherpaService.startRecording(
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
                            if self?.voiceService.isRecording == false && self?.sherpaService.isRecording == false {
                                self?.voiceBannerText = nil
                            }
                        }
                    }
                }
            )
            return
        }

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
                            if self?.voiceService.isRecording == false && self?.sherpaService.isRecording == false {
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
        let allPlayersFull = !players.isEmpty && players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
        
        if (isSelectingCommunity || allPlayersFull) && commTargetCount > 0 && communityCards.count < commTargetCount {
            communityCards.append(card)
            actionHistory.append((card: card, target: "COMMUNITY"))
            isSelectingCommunity = communityCards.count < commTargetCount
            if isReadyToCalculate {
                calculateResults()
            }
            return
        } else if inputMode == .roundRobin {
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
            if !dealtToPlayer && commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
                isSelectingCommunity = communityCards.count < commTargetCount
            }
            
        } else {
            // Manual selection mode
            if isSelectingCommunity {
                if communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                    isSelectingCommunity = communityCards.count < commTargetCount
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
        let allPlayersFull = !players.isEmpty && players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
        
        if (isSelectingCommunity || allPlayersFull) && commTargetCount > 0 && communityCards.count < commTargetCount {
            communityCards.append(card)
            actionHistory.append((card: card, target: "COMMUNITY"))
            isSelectingCommunity = communityCards.count < commTargetCount
            if isReadyToCalculate {
                calculateResults()
            }
            return
        } else if inputMode == .roundRobin {
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
                
                let allFull = players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
                if allFull && commTargetCount > 0 && communityCards.count < commTargetCount {
                    isSelectingCommunity = true
                } else {
                    isSelectingCommunity = false
                }
            } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
                isSelectingCommunity = communityCards.count < commTargetCount
            }
        } else {
            if isSelectingCommunity {
                if communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                    isSelectingCommunity = communityCards.count < commTargetCount
                }
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
                    isSelectingCommunity = communityCards.count < commTargetCount
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
        let allPlayersFull = !players.isEmpty && players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
        
        if (isSelectingCommunity || allPlayersFull) && commTargetCount > 0 && communityCards.count < commTargetCount {
            communityCards.append(card)
            actionHistory.append((card: card, target: "COMMUNITY"))
            isSelectingCommunity = communityCards.count < commTargetCount
            if isReadyToCalculate {
                calculateResults()
            }
            return
        } else if inputMode == .roundRobin {
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
                
                let allFull = players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
                if allFull && commTargetCount > 0 && communityCards.count < commTargetCount {
                    isSelectingCommunity = true
                } else {
                    isSelectingCommunity = false
                }
            } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
                isSelectingCommunity = communityCards.count < commTargetCount
            }
        } else {
            if isSelectingCommunity {
                if communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                    isSelectingCommunity = communityCards.count < commTargetCount
                }
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
                    isSelectingCommunity = communityCards.count < commTargetCount
                }
            }
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // MARK: - Online Remote Live Keypad Session & Live Web Sync
    public func toggleOnlineRemoteMode() {
        isOnlineRemoteMode.toggle()
    }

    public func startLiveSyncSession() {
        startRemoteSocketConnection()
    }

    public func stopLiveSyncSession() {
        if !isOnlineRemoteMode {
            LiveRemoteSocketService.shared.disconnect()
            isOnlineRemoteConnected = false
        }
    }

    public func startOnlineRemoteSession() {
        startRemoteSocketConnection()
    }

    public func stopOnlineRemoteSession() {
        if !isLiveSyncEnabled {
            LiveRemoteSocketService.shared.disconnect()
            isOnlineRemoteConnected = false
        }
    }

    private func startRemoteSocketConnection() {
        let auth = AppAuthManager.shared
        guard auth.isAuthenticated else { return }
        LiveRemoteSocketService.shared.onRemoteCardReceived = { [weak self] cardValue, action in
            guard let self = self, self.isOnlineRemoteMode || self.isLiveSyncEnabled else { return }
            if action == "DELETE" {
                self.undoLastAction(isFromRemote: true)
            } else if action == "CLEAR" {
                self.resetTable(isFromRemote: true)
            } else if let cardVal = cardValue {
                self.processRemoteCardInput(cardVal)
            }
        }
        LiveRemoteSocketService.shared.onConnectionStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isOnlineRemoteConnected = connected
            }
        }
        let targetRoom = auth.currentUserId ?? auth.currentUsername
        LiveRemoteSocketService.shared.connect(
            serverURL: auth.serverURL,
            token: auth.authToken,
            roomId: targetRoom
        )
    }

    public func processRemoteCardInput(_ rawValue: String) {
        let clean = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean == "0" || clean == "__hidden__" {
            onHiddenCardTapped()
        } else if let num = Int(clean) {
            let rank: Rank?
            switch num {
            case 1: rank = .ace
            case 2: rank = .two
            case 3: rank = .three
            case 4: rank = .four
            case 5: rank = .five
            case 6: rank = .six
            case 7: rank = .seven
            case 8: rank = .eight
            case 9: rank = .nine
            case 10: rank = .ten
            case 11: rank = .jack
            case 12: rank = .queen
            case 13: rank = .king
            default: rank = nil
            }
            if let r = rank {
                onRankTapped(r)
            }
        }
    }

    // MARK: - Voice Recognition Handling
    public func toggleVoiceRecognition() {
        if voiceService.isRecording || sherpaService.isRecording {
            sherpaService.stopRecording()
            voiceService.stopRecording(callEndAudio: false)
            voiceBannerText = "⏹️ Đã dừng ghi âm"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if self?.voiceService.isRecording == false && self?.sherpaService.isRecording == false {
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

            if sherpaService.isModelLoaded {
                self.voiceBannerText = "🎙️ Đang nghe [AI Offline]... Hãy đọc bài"
                self.sherpaService.startRecording(
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
                                if self?.voiceService.isRecording == false && self?.sherpaService.isRecording == false {
                                    self?.voiceBannerText = nil
                                }
                            }
                        }
                    }
                )
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
                                    if self?.voiceService.isRecording == false && self?.sherpaService.isRecording == false {
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
            lastProcessedVoiceText = ""
        }
        
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanText != lastProcessedVoiceText else { return }
        lastProcessedVoiceText = cleanText
        
        let displaySpoken = VietnameseCardVoiceParser.separateDigits(text)
        if currentSegmentConfirmedCards.isEmpty && !displaySpoken.isEmpty {
            voiceBannerText = "🎙️ \"\(displaySpoken)\""
        }
        
        if isReadyToCalculate {
            if voiceService.isRecording || sherpaService.isRecording {
                sherpaService.stopRecording()
                voiceService.stopRecording(callEndAudio: false)
                self.voiceBannerText = "✅ Đã chia đủ bài - Xong ván!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    if self?.voiceService.isRecording == false && self?.sherpaService.isRecording == false {
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
            
            // Hiển thị trực tiếp luồng bài đã chốt trên banner để không bị giật lùi/nhảy chữ
            let cardsFlow = currentSegmentConfirmedCards.map { $0.rank.displaySymbol }.joined(separator: " ➔ ")
            self.voiceBannerText = "🎙️ Đã nhận: \(cardsFlow)"
            
            // Đồng bộ tức thì sang Web Live nếu đang kết nối Online Remote hoặc bật Live Sync
            if (isLiveSyncEnabled || isOnlineRemoteMode) && LiveRemoteSocketService.shared.isConnected {
                let cardValStr: String
                if item.isHidden {
                    cardValStr = "__hidden__"
                } else {
                    switch lastAction.card.rank {
                    case .ace: cardValStr = "1"
                    case .jack: cardValStr = "11"
                    case .queen: cardValStr = "12"
                    case .king: cardValStr = "13"
                    default: cardValStr = "\(lastAction.card.rank.rawValue)"
                    }
                }
                LiveRemoteSocketService.shared.sendRemoteCard(cardValue: cardValStr, action: "ADD")
            }
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
    public func undoLastAction(isFromRemote: Bool = false) {
        guard let last = actionHistory.popLast() else { return }
        removeCard(last.card)
        if !isFromRemote && (isLiveSyncEnabled || isOnlineRemoteMode) && LiveRemoteSocketService.shared.isConnected {
            LiveRemoteSocketService.shared.sendRemoteCard(cardValue: nil, action: "DELETE")
        }
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
        case .binh9NoStraight:
            calculateBinh9NoStraight()
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

    // MARK: - ( 9 lá không liên ) Evaluator: 2 Giai đoạn (6 lá trước, 9 lá sau)
    private func calculateBinh9NoStraight() {
        var phase6Arrangements = [Int: Binh9NoStraightArrangement]()
        var phase9Arrangements = [Int: Binh9NoStraightArrangement]()
        var phase6Indices = [Int]()
        var phase9Indices = [Int]()
        
        for i in 0..<players.count {
            players[i].score = 0
            if players[i].cards.contains(where: { $0.isHidden }) {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = "???"
                players[i].resultDetail = "Chưa rõ quân bài • Loại khỏi BXH"
            } else if players[i].cards.count >= 9 {
                // Giai đoạn 2: Đủ 9 lá
                let cards9 = Array(players[i].cards.prefix(9))
                let arr = Binh9NoStraightEvaluator.autoArrange9(cards: cards9)
                phase9Arrangements[i] = arr
                players[i].cards = arr.chi1 + arr.chi2 + arr.chi3
                players[i].isLung = arr.isLung
                phase9Indices.append(i)
                
                let s3Desc = arr.score3?.descriptionVN ?? ""
                if let win = arr.instantWin {
                    players[i].resultTitle = win
                    players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN) | Chi 2: \(arr.score2.descriptionVN) | Chi 3: \(s3Desc)"
                } else if arr.isLung {
                    players[i].resultTitle = "⚠️ BỊ LỦNG (9 lá)"
                    players[i].resultDetail = "Chi trước yếu hơn chi sau (Xử thua)!"
                } else {
                    players[i].resultTitle = "C1: \(arr.score1.descriptionVN) | C2: \(arr.score2.descriptionVN) | C3: \(s3Desc)"
                    players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN) | Chi 2: \(arr.score2.descriptionVN) | Chi 3: \(s3Desc)"
                }
            } else if players[i].cards.count >= 6 {
                // Giai đoạn 1: Đủ 6 lá (nhưng chưa đủ 9 lá)
                let cards6 = Array(players[i].cards.prefix(6))
                let arr = Binh9NoStraightEvaluator.autoArrange6(cards: cards6)
                phase6Arrangements[i] = arr
                let extra = players[i].cards.count > 6 ? Array(players[i].cards.suffix(from: 6)) : []
                players[i].cards = arr.chi1 + arr.chi2 + extra
                players[i].isLung = arr.isLung
                phase6Indices.append(i)
                
                if arr.isLung {
                    players[i].resultTitle = "⚠️ BỊ LỦNG (6 lá)"
                    players[i].resultDetail = "Chi 1 yếu hơn Chi 2 (Xử thua)!"
                } else {
                    players[i].resultTitle = "6 lá: C1[\(arr.score1.descriptionVN)] • C2[\(arr.score2.descriptionVN)]"
                    players[i].resultDetail = "GĐ1: Chi 1 [\(arr.score1.descriptionVN)] | Chi 2 [\(arr.score2.descriptionVN)]"
                }
            } else {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].isLung = false
                players[i].resultTitle = players[i].cards.isEmpty ? "" : "\(players[i].cards.count)/6 lá"
                players[i].resultDetail = "Chưa đủ 6 lá (Giai đoạn 1)"
            }
        }
        
        // So sánh xếp hạng
        if !phase9Indices.isEmpty {
            // Có tụ đã đủ 9 lá
            if phase9Indices.count == 1 {
                let i = phase9Indices[0]
                players[i].rankOrder = 1
                showdownSummary = "⏳ Tụ \(players[i].name) đã đủ 9 lá. Chờ các tụ khác..."
            } else {
                for a in 0..<phase9Indices.count {
                    let i = phase9Indices[a]
                    guard let arrI = phase9Arrangements[i] else { continue }
                    for b in (a + 1)..<phase9Indices.count {
                        let j = phase9Indices[b]
                        guard let arrJ = phase9Arrangements[j] else { continue }
                        let res = Binh9NoStraightEvaluator.compareMatch9(a: arrI, b: arrJ)
                        if res.scoreA > 0 {
                            players[i].score += 1
                        } else if res.scoreA < 0 {
                            players[j].score += 1
                        }
                    }
                }
                
                var sorted9 = phase9Indices
                sorted9.sort { p1, p2 in
                    if players[p1].score != players[p2].score {
                        return players[p1].score > players[p2].score
                    }
                    if let arr1 = phase9Arrangements[p1], let arr2 = phase9Arrangements[p2] {
                        let match = Binh9NoStraightEvaluator.compareMatch9(a: arr1, b: arr2)
                        if match.scoreA != 0 {
                            return match.scoreA > 0
                        }
                        if arr1.score1 != arr2.score1 {
                            return arr1.score1 > arr2.score1
                        }
                        if arr1.score2 != arr2.score2 {
                            return arr1.score2 > arr2.score2
                        }
                        if let s3_1 = arr1.score3, let s3_2 = arr2.score3 {
                            if s3_1 != s3_2 {
                                return s3_1 > s3_2
                            }
                        }
                    }
                    return p1 < p2
                }
                var currentRank = 1
                for k in 0..<sorted9.count {
                    let idx = sorted9[k]
                    if k > 0 {
                        let prevIdx = sorted9[k - 1]
                        let isExactTie: Bool
                        if let arrCurr = phase9Arrangements[idx], let arrPrev = phase9Arrangements[prevIdx] {
                            isExactTie = (players[idx].score == players[prevIdx].score) &&
                                         (arrCurr.score1 == arrPrev.score1) &&
                                         (arrCurr.score2 == arrPrev.score2) &&
                                         (arrCurr.score3 == arrPrev.score3)
                        } else {
                            isExactTie = players[idx].score == players[prevIdx].score
                        }
                        if !isExactTie {
                            currentRank = k + 1
                        }
                    }
                    players[idx].rankOrder = currentRank
                }
                
                let rank1Players = players.filter { $0.rankOrder == 1 }
                if rank1Players.count > 1 {
                    let names = rank1Players.map { $0.name }.joined(separator: ", ")
                    showdownSummary = "👑 Đồng Hạng 1 (9 lá): \(names)"
                } else if let winner = rank1Players.first {
                    showdownSummary = "🏆 \(winner.name) Thắng 9 lá!"
                }
            }
        } else if !phase6Indices.isEmpty {
            // Chưa có tụ nào đủ 9 lá, nhưng đã có tụ đủ 6 lá -> So sánh Phase 1 (6 lá)!
            if phase6Indices.count == 1 {
                let i = phase6Indices[0]
                players[i].rankOrder = 1
                showdownSummary = "⏳ Tụ \(players[i].name) đã đủ 6 lá (Giai đoạn 1)"
            } else {
                for a in 0..<phase6Indices.count {
                    let i = phase6Indices[a]
                    guard let arrI = phase6Arrangements[i] else { continue }
                    for b in (a + 1)..<phase6Indices.count {
                        let j = phase6Indices[b]
                        guard let arrJ = phase6Arrangements[j] else { continue }
                        let res = Binh9NoStraightEvaluator.compareMatch6(a: arrI, b: arrJ)
                        if res.scoreA > 0 {
                            players[i].score += 1
                        } else if res.scoreA < 0 {
                            players[j].score += 1
                        }
                    }
                }
                
                var sorted6 = phase6Indices
                sorted6.sort { p1, p2 in
                    if players[p1].score != players[p2].score {
                        return players[p1].score > players[p2].score
                    }
                    if let arr1 = phase6Arrangements[p1], let arr2 = phase6Arrangements[p2] {
                        let match = Binh9NoStraightEvaluator.compareMatch6(a: arr1, b: arr2)
                        if match.scoreA != 0 {
                            return match.scoreA > 0
                        }
                        if arr1.score1 != arr2.score1 {
                            return arr1.score1 > arr2.score1
                        }
                        if arr1.score2 != arr2.score2 {
                            return arr1.score2 > arr2.score2
                        }
                    }
                    return p1 < p2
                }
                var currentRank = 1
                for k in 0..<sorted6.count {
                    let idx = sorted6[k]
                    if k > 0 {
                        let prevIdx = sorted6[k - 1]
                        let isExactTie: Bool
                        if let arrCurr = phase6Arrangements[idx], let arrPrev = phase6Arrangements[prevIdx] {
                            isExactTie = (players[idx].score == players[prevIdx].score) &&
                                         (arrCurr.score1 == arrPrev.score1) &&
                                         (arrCurr.score2 == arrPrev.score2)
                        } else {
                            isExactTie = players[idx].score == players[prevIdx].score
                        }
                        if !isExactTie {
                            currentRank = k + 1
                        }
                    }
                    players[idx].rankOrder = currentRank
                }
                
                let rank1Players = players.filter { $0.rankOrder == 1 }
                if rank1Players.count > 1 {
                    let names = rank1Players.map { $0.name }.joined(separator: ", ")
                    showdownSummary = "👑 Đồng Hạng 1 (6 lá): \(names)"
                } else if let winner = rank1Players.first {
                    showdownSummary = "⚡ \(winner.name) Dẫn đầu 6 lá (Giai đoạn 1)!"
                }
            }
        } else {
            showdownSummary = ""
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
            } else if players[i].cards.count == 9 {
                let arr = Binh9Evaluator.autoArrange(cards: players[i].cards)
                arrangements[i] = arr
                players[i].cards = arr.chi1 + arr.chi2 + arr.chi3
                players[i].isLung = arr.isLung
                players[i].score = 0
                validIndices.append(i)
            } else {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].isLung = false
                players[i].resultTitle = players[i].cards.isEmpty ? "" : "\(players[i].cards.count)/9 lá"
                players[i].resultDetail = "Chưa đủ 9 lá bài"
            }
        }
        
        // Nếu chưa có tụ nào đủ 9 lá
        guard !validIndices.isEmpty else {
            showdownSummary = ""
            return
        }
        
        // Nếu mới chỉ có 1 tụ đủ 9 lá (các tụ khác đang chia bài)
        if validIndices.count == 1 {
            let i = validIndices[0]
            guard let arr = arrangements[i] else { return }
            if let win = arr.instantWin {
                players[i].resultTitle = win
                players[i].resultDetail = "Thắng trắng toàn bàn!"
            } else if arr.isLung {
                players[i].resultTitle = "⚠️ BỊ LỦNG"
                players[i].resultDetail = "Chi trước yếu hơn chi sau (Xử thua)!"
            } else {
                players[i].resultTitle = "Đã đủ 9 lá"
                players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN) | Chi 2: \(arr.score2.descriptionVN) | Chi 3: \(arr.score3.descriptionVN)"
            }
            players[i].rankOrder = 1
            showdownSummary = "⏳ Chờ các tụ khác nhập đủ 9 lá để so điểm..."
            return
        }
        
        // So chéo giữa các nhà hợp lệ (khi có >= 2 nhà đủ 9 lá)
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
        sortedIndices.sort { p1, p2 in
            if players[p1].score != players[p2].score {
                return players[p1].score > players[p2].score
            }
            if let arr1 = arrangements[p1], let arr2 = arrangements[p2] {
                let match = Binh9Evaluator.compareMatch(a: arr1, b: arr2)
                if match.scoreA != 0 {
                    return match.scoreA > 0
                }
                if arr1.score1 != arr2.score1 {
                    return arr1.score1 > arr2.score1
                }
                if arr1.score2 != arr2.score2 {
                    return arr1.score2 > arr2.score2
                }
                if arr1.score3 != arr2.score3 {
                    return arr1.score3 > arr2.score3
                }
            }
            return p1 < p2
        }
        var currentRank = 1
        for i in 0..<sortedIndices.count {
            let idx = sortedIndices[i]
            if i > 0 {
                let prevIdx = sortedIndices[i - 1]
                let isExactTie: Bool
                if let arrCurr = arrangements[idx], let arrPrev = arrangements[prevIdx] {
                    isExactTie = (players[idx].score == players[prevIdx].score) &&
                                 (arrCurr.score1 == arrPrev.score1) &&
                                 (arrCurr.score2 == arrPrev.score2) &&
                                 (arrCurr.score3 == arrPrev.score3)
                } else {
                    isExactTie = players[idx].score == players[prevIdx].score
                }
                if !isExactTie {
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
                showdownSummary = "🏆 \(winner.name) Thắng ván đấu!"
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
            } else if p.cards.count == 6 {
                let s = Binh6Evaluator.evaluatePoker6(p.cards)
                scores.append((index: i, score: s))
                players[i].resultTitle = s.descriptionVN
                players[i].resultDetail = "Bộ 5 lá tốt nhất từ 6 lá: \(s.cards.map { $0.displayName }.joined(separator: " "))"
            } else {
                players[i].rankOrder = nil
                players[i].score = -1
                players[i].resultTitle = p.cards.isEmpty ? "" : "\(p.cards.count)/6 lá"
                players[i].resultDetail = "Chưa đủ 6 lá bài"
            }
        }
        guard !scores.isEmpty else {
            showdownSummary = ""
            return
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
    
    // MARK: - Server 2 Input & Scoring Methods
    public func addServer2Card(rank: Rank, isRo: Bool) {
        let cardId = "s2_\(rank.rawValue)_\(isRo ? "ro" : "norm")_\(UUID().uuidString)"
        let card = Card(rank: rank, suit: isRo ? .diamonds : .spades, customId: cardId, isRankOnly: true, isHidden: false, isRo: isRo)
        insertCardToServer2(card)
    }

    public func addServer2Card(rank: Rank, suit: Suit) {
        let cardId = "s2_\(rank.rawValue)_\(suit.rawValue)_\(UUID().uuidString)"
        let card = Card(rank: rank, suit: suit, customId: cardId, isRankOnly: false, isHidden: false, isRo: suit == .diamonds)
        insertCardToServer2(card)
    }

    public func addServer2CardRankOnly(rank: Rank) {
        let cardId = "s2_\(rank.rawValue)_rank_\(UUID().uuidString)"
        let card = Card(rank: rank, suit: .spades, customId: cardId, isRankOnly: true, isHidden: false, isRo: false)
        insertCardToServer2(card)
    }

    public func addServer2UnknownCard() {
        let cardId = "s2_unk_\(UUID().uuidString)"
        let card = Card(rank: .two, suit: .spades, customId: cardId, isRankOnly: true, isHidden: true, isRo: false)
        insertCardToServer2(card)
    }

    private func insertCardToServer2(_ card: Card) {
        let commTargetCount = gameType.communityCardsCount
        let allPlayersFull = !players.isEmpty && players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
        
        // Nếu đang chọn bài chung hoặc tất cả các tụ đã đủ bài tẩy và game có bài chung (như Poker Texas Hold'em)
        if (isSelectingCommunity || allPlayersFull) && commTargetCount > 0 && communityCards.count < commTargetCount {
            communityCards.append(card)
            actionHistory.append((card: card, target: "COMMUNITY"))
            isSelectingCommunity = communityCards.count < commTargetCount
            updateServer2Evaluation()
            return
        }
        
        if inputMode == .roundRobin {
            // Chia tuần tự: tìm tụ tiếp theo còn thiếu bài
            var targetIdx: Int? = nil
            for i in 0..<players.count {
                let idx = (roundRobinPointer + i) % players.count
                if players[idx].cards.count < targetCards(for: idx) {
                    targetIdx = idx
                    break
                }
            }
            if let idx = targetIdx {
                players[idx].cards.append(card)
                actionHistory.append((card: card, target: players[idx].id))
                roundRobinPointer = (idx + 1) % players.count
                selectedPlayerIndex = roundRobinPointer
                
                let nowAllFull = players.indices.allSatisfy { players[$0].cards.count >= targetCards(for: $0) }
                if nowAllFull && commTargetCount > 0 && communityCards.count < commTargetCount {
                    isSelectingCommunity = true
                }
            } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
                isSelectingCommunity = communityCards.count < commTargetCount
            }
        } else {
            // Chọn thủ công
            if isSelectingCommunity {
                if communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                    isSelectingCommunity = communityCards.count < commTargetCount
                }
            } else if selectedPlayerIndex < players.count {
                let needCount = targetCards(for: selectedPlayerIndex)
                if players[selectedPlayerIndex].cards.count < needCount {
                    players[selectedPlayerIndex].cards.append(card)
                    actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                    
                    if players[selectedPlayerIndex].cards.count == needCount {
                        var nextNeeding: Int? = nil
                        for i in 1..<players.count {
                            let nextIdx = (selectedPlayerIndex + i) % players.count
                            if players[nextIdx].cards.count < targetCards(for: nextIdx) {
                                nextNeeding = nextIdx
                                break
                            }
                        }
                        if let next = nextNeeding {
                            selectedPlayerIndex = next
                        } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                            isSelectingCommunity = true
                        }
                    }
                } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                    isSelectingCommunity = communityCards.count < commTargetCount
                }
            }
        }
        
        updateServer2Evaluation()
    }

    public func undoServer2Action() {
        guard let lastAction = actionHistory.popLast() else { return }
        if lastAction.target == "COMMUNITY" {
            if !communityCards.isEmpty {
                communityCards.removeLast()
                isSelectingCommunity = true
            }
        } else if let playerIdx = players.firstIndex(where: { $0.id == lastAction.target }) {
            if !players[playerIdx].cards.isEmpty {
                players[playerIdx].cards.removeLast()
                roundRobinPointer = playerIdx
                selectedPlayerIndex = playerIdx
                isSelectingCommunity = false
            }
        }
        updateServer2Evaluation()
    }

    public var canUndoServer2: Bool {
        return !actionHistory.isEmpty
    }

    public func moveToNextPlayer() {
        guard !players.isEmpty else { return }
        let commCount = gameType.communityCardsCount
        if isSelectingCommunity {
            isSelectingCommunity = false
            selectedPlayerIndex = 0
            roundRobinPointer = 0
        } else if selectedPlayerIndex == players.count - 1 && commCount > 0 {
            isSelectingCommunity = true
        } else {
            selectedPlayerIndex = (selectedPlayerIndex + 1) % players.count
            roundRobinPointer = selectedPlayerIndex
        }
    }

    public func resetServer2Table() {
        for i in 0..<players.count {
            players[i].clearCards()
        }
        communityCards.removeAll()
        actionHistory.removeAll()
        roundRobinPointer = 0
        selectedPlayerIndex = 0
        isSelectingCommunity = false
        updateServer2Evaluation()
    }

    public func updateServer2Evaluation() {
        if gameType == .lieng3 {
            var results: [Server2HandResult] = []
            var completeCount = 0
            
            for i in 0..<players.count {
                let res = Server2ThreeCardEvaluator.evaluate(cards: players[i].cards)
                results.append(res)
                players[i].resultTitle = res.label
                players[i].score = res.score
                if res.isComplete {
                    completeCount += 1
                }
            }
            self.server2HandResults = results
            self.server2CompleteCount = completeCount
            
            // Tính toán Bảng Đối Chiếu Thứ Hạng Realtime (Cross-Check Leaderboard)
            var playerScores: [(index: Int, score: Int, isComplete: Bool)] = []
            for (i, res) in results.enumerated() {
                if !res.hasUnknown && res.isComplete {
                    playerScores.append((index: i, score: res.score, isComplete: true))
                }
            }
            
            playerScores.sort { $0.score > $1.score }
            
            var currentRank = 1
            for i in 0..<playerScores.count {
                if i > 0 && playerScores[i].score < playerScores[i - 1].score {
                    currentRank = i + 1
                }
                players[playerScores[i].index].rankOrder = currentRank
            }
            
            for i in 0..<players.count {
                if !playerScores.contains(where: { $0.index == i }) {
                    players[i].rankOrder = nil
                }
            }
            
            if !playerScores.isEmpty {
                var chainParts: [String] = []
                for i in 0..<playerScores.count {
                    let pIdx = playerScores[i].index
                    let pName = players[pIdx].name
                    if i > 0 {
                        let isTie = playerScores[i].score == playerScores[i - 1].score
                        chainParts.append(isTie ? "=" : ">")
                    }
                    chainParts.append(pName)
                }
                self.server2LeaderboardChain = chainParts.joined(separator: " ")
                
                let winners = players.filter { $0.rankOrder == 1 }
                if winners.count > 1 {
                    let names = winners.map { $0.name }.joined(separator: ", ")
                    self.server2WinnerTitle = "👑 Đồng Hạng 1: \(names) (\(winners[0].resultTitle))"
                } else if let winner = winners.first {
                    self.server2WinnerTitle = "👑 \(winner.name) Thắng: \(winner.resultTitle)"
                } else {
                    self.server2WinnerTitle = ""
                }
            } else {
                self.server2LeaderboardChain = ""
                self.server2WinnerTitle = ""
            }
        } else {
            switch gameType {
            case .texasHoldem:
                calculateTexasHoldem()
            case .xiDach2:
                calculateXiDach()
            case .phom9:
                calculatePhom()
            case .samLoc10:
                calculateSamLoc()
            case .binh9:
                calculateBinh9()
            case .binh9NoStraight:
                calculateBinh9NoStraight()
            case .binh6Poker:
                calculateBinh6Poker()
            default:
                calculateLieng()
            }
            self.server2WinnerTitle = showdownSummary
            updateServer2LeaderboardChainFromRankOrder()
        }
    }
    
    private func updateServer2LeaderboardChainFromRankOrder() {
        var ranked = players.filter { $0.rankOrder != nil }
        ranked.sort { ($0.rankOrder ?? 99) < ($1.rankOrder ?? 99) }
        if !ranked.isEmpty {
            var chainParts: [String] = []
            for i in 0..<ranked.count {
                if i > 0 {
                    let isTie = ranked[i].rankOrder == ranked[i - 1].rankOrder
                    chainParts.append(isTie ? "=" : ">")
                }
                chainParts.append(ranked[i].name)
            }
            self.server2LeaderboardChain = chainParts.joined(separator: " ")
        } else {
            self.server2LeaderboardChain = ""
        }
    }
}
