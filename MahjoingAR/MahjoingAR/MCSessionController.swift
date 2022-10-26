//
//  MCSessionViewController.swift
//  MahjoingAR
//
//  Created by Helen Jiang.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//

// https://www.hackingwithswift.com/example-code/networking/how-to-create-a-peer-to-peer-network-using-the-multipeer-connectivity-framework


import Foundation
import MultipeerConnectivity

struct UserEvent: Codable {
    let player: Int
    let cards: [Card]
    let playerAction: PlayerAction
}

protocol MCGameSessionControllerDelegate {
    
    // start-of-game delegate call
    func MCGameSession(gameDidStartWithCards cards: [Card], asPlayer playerNumber: Int)
    
    // player is the winner, win is always true
    func MCGameSession(player: Int, didWin win: Bool)
    
    // draw is always true
    func MCGameSession(gameIsDraw draw: Bool)
    
    // currentPlayer received a Card and can only .play Card
    // Expected UserEvent: UserEvent(player: player, cards: [playedCard], playerAction: .play)
    func MCGameSession(currentPlayer player: Int, receivedCard card: Card, withSortedIndex sortedIndex: Int, willPlayerCard playCard: Bool) -> UserEvent
    
    // currentPlayer received a Card and can choose some from actions beside .play
    // Expected UserEvent: UserEvent(player: player, cards: [relevantCard(s)], playerAction: playerAction)
    // actions might contain .kong -- return UserEvent(player: player, cards: [relevantCard(s)], playerAction: .kong)
    func MCGameSession(currentPlayer player: Int, receivedCard card: Card, withSortedIndex sortedIndex: Int, willChooseFromActions actions: [PlayerAction]) -> UserEvent
    
    // The playedCard can be used by currentPlayer to perform actions in actions
    // Expected first UserEvent: UserEvent(player: player, cards: [relevantCard(s)], playerAction: .win/.pong/.chow/.pass)
    // Expected second UserEvent (nil if player choose .kong/.pass for first UserEvent): UserEvent(player: player, cards: [relevantCard(s)], playerAction: .play)
    func MCGameSession(currentPlayer player: Int, willChooseFromActions actions: [PlayerAction], withPlayedCard card: Card, withSortedIndex sortedIndex: Int) -> (UserEvent, UserEvent?)
    
    // otherPlayer played card, this needs to be reflected in UI
    func MCGameSession(otherPlayer player: Int, didPlayCard card: Card)
    
    // otherPlayer didAction withCards, this update need to be reflected in UI
    // PlayerAction will be among .kong, .pong, .chow
    func MCGameSession(otherPlayer player: Int, didAction action: PlayerAction, withCards cards: [Card])
    
}

class MCSessionController: NSObject {

    var isHost: Bool
    var displayName: String
    var peerID: MCPeerID
    var mcSession: MCSession
    var delegate: MCGameSessionControllerDelegate?
    
    private var gameServer: GameServer?
    private var players: [MCPeerID] = []
    private var playerNumber: Int?
    private var cardPile: [Int] = []
    private var publicHandCard: [Card] = []
    private var privateHandCard: [Card] = []
    private var otherPlayerHandCard: [[Card?]] = []
    private var playerKongCard: [[Card]] = []
    private var playedCard: [Card] = []
    
    private var participantGameStartReadyCount: [Bool] = [false, false, false, false]
    private var participantFirstCardReadyCount: [Bool] = [false, false, false, false]
    private var firstCardAssigned: Bool = false
    
    init(deviceIsHost isHost: Bool, playerDisplayName displayName: String, withMCPeerID peerID: MCPeerID, withMCSession mcSession: MCSession) {
        
        self.isHost = isHost
        self.displayName = displayName
        self.peerID = peerID
        self.mcSession = mcSession
        
        super.init()
        
        mcSession.delegate = self
        
        players.append(peerID)
        players.append(contentsOf: mcSession.connectedPeers)
        
        for _ in 1...4 {
            var cards: [Card?] = []
            for _ in 1...20 {
                cards.append(Card(cardType: .hidden, cardValue: 0))
            }
            cards.append(nil)
            
            otherPlayerHandCard.append(cards)
            playerKongCard.append([])
        }
        
        if isHost {
            participantGameStartReadyCount[0] = true
            DispatchQueue.global().async { [self] in
                while !((participantGameStartReadyCount[0] && participantGameStartReadyCount[1]) && (participantGameStartReadyCount[2] && participantGameStartReadyCount[3])) {
                    try? mcSession.send("Respond if ready to start game".data(using: .utf8)!, toPeers: mcSession.connectedPeers, with: .reliable)
                }
                startGame()
            }
        }
    }
    
    func startGame() {
        if isHost {
            
            gameServer = GameServer()
            
            // Assign player index
            for (number, player) in players.enumerated() {
                sendData(number, toPeers: player)
            }
            
            // get and assign initial game data
            let gameStartData = gameServer!.startGame()
            for (number, player) in players.enumerated() {
                let playerStartData = GameStart(dices: gameStartData.dices, cardPile: gameStartData.cardPile, playerHandCards: [gameStartData.playerHandCards[number]])
                sendData(playerStartData, toPeers: player)
            }
        }
    }
    
    func isLegalChow(forCurrentPlayer player: Int, withCards cards: [Card]) -> Bool {
        
        if cards.count == 3 {
            let currentCards = cards.sorted()
            if currentCards[0].cardType == currentCards[1].cardType && currentCards[0].cardType == currentCards[2].cardType {
                if currentCards[0].cardValue + 1 == currentCards[1].cardValue && currentCards[0].cardValue + 2 == currentCards[2].cardValue {
                    return currentCards[0].cardType == .bamboo || currentCards[0].cardType == .circles || currentCards[0].cardType == .character
                }
            }
        }
        return false
    }   
    
    func readyToReceiveCards() {
        if isHost {
            processData(nil, didReceive: "participant ready to receive card".data(using: .utf8)!, fromPeer: peerID)
        } else {
            try? mcSession.send("participant ready to receive card".data(using: .utf8)!, toPeers: mcSession.connectedPeers, with: .reliable)
        }
    }
    
    func getPlayerNumber() -> Int? {
        return playerNumber
    }
    
    private func sendData<T: Codable>(_ data: T, toPeers peer: MCPeerID) {
        try? mcSession.send(JSONEncoder().encode(data), toPeers: [peer], with: .reliable)
        if peer == peerID {
            try? processData(nil, didReceive: JSONEncoder().encode(data), fromPeer: peerID)
        }
    }
    
    private func sendData<T: Codable>(_ data: T) {
        try? mcSession.send(JSONEncoder().encode(data), toPeers: mcSession.connectedPeers, with: .reliable)
        try? processData(nil, didReceive: JSONEncoder().encode(data), fromPeer: peerID)
    }
    
    private func decodeData(_ data: Data) -> (Int?, GameStart?, GameEvent?, UserEvent?) {
        
        if let decodedData = try? JSONDecoder().decode(Int.self, from: data) {
            return (decodedData, nil, nil, nil)
        }
        if let decodedData = try? JSONDecoder().decode(GameStart.self, from: data) {
            return (nil, decodedData, nil, nil)
        }
        if let decodedData = try? JSONDecoder().decode(GameEvent.self, from: data) {
            return (nil, nil, decodedData, nil)
        }
        if let decodedData = try? JSONDecoder().decode(UserEvent.self, from: data) {
            return (nil, nil, nil, decodedData)
        }
        
        return (nil, nil, nil, nil)
    }
    
    private func callServerNextAction(userEvent: UserEvent) -> GameEvent? {
        if isHost {
            return gameServer!.nextAction(action: userEvent.playerAction, from: userEvent.player, with: userEvent.cards)
        } else {
            return GameEvent(player: -1, card: nil, playerOptions: [], message: "callServerNextAction() called when is NOT host")
        }
    }
    
    private func printMessage(fromMethod method: String, withMessage message: String, asError error: Bool) {
        print("\(UIDevice.current.name): \(error ? "Error" : "") MCSC: \(method): \(message)")
    }
    
}

extension MCSessionController: MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        printMessage(fromMethod: "session(session:peer:didChange state:)", withMessage: "\(peerID.displayName) changed with new state \(String(describing: state.rawValue))", asError: false)
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        processData(session, didReceive: data, fromPeer: peerID)
    }
    
    func processData(_ session: MCSession?, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        let methodSignature = "processData(session:didReceive:fromPeer:)"
        
        if String(decoding: data, as: UTF8.self).contains("Respond if ready to start game") {
            try? mcSession.send("participant ready to start game".data(using: .utf8)!, toPeers: [peerID], with: .reliable)
        }
        if String(decoding: data, as: UTF8.self).contains("participant ready to start game") {
            participantGameStartReadyCount[players.firstIndex(of: peerID)!] = true
        }
        if isHost && String(decoding: data, as: UTF8.self).contains("participant ready to receive card") {
            participantFirstCardReadyCount[players.firstIndex(of: peerID)!] = true
            
            if !firstCardAssigned && (participantFirstCardReadyCount[0] && participantFirstCardReadyCount[1]) && (participantFirstCardReadyCount[2] && participantFirstCardReadyCount[3]) {

                firstCardAssigned = true
                let nextAction = gameServer!.nextAction()
                sendData(nextAction, toPeers: players[nextAction.player])
            }
        }
        
        let (intData, gameStartData, gameEventData, userEventData) = decodeData(data)
        
        if let data = intData {
            playerNumber = data
            return
        }
        
        if let data = gameStartData {
            cardPile = data.cardPile
            privateHandCard = data.playerHandCards[0]
            delegate!.MCGameSession(gameDidStartWithCards: privateHandCard, asPlayer: playerNumber!)
        }
        
        if let data = gameEventData {
            
            if data.playerOptions.count == 0 {
                if data.message == "WIN" {
                    delegate!.MCGameSession(player: data.player, didWin: true)
                } else if data.message == "DRAW" {
                    delegate!.MCGameSession(gameIsDraw: true)
                } else {
                    printMessage(fromMethod: methodSignature, withMessage: "received data \(String(describing: data))", asError: true)
                }
                
            } else if data.playerOptions.count == 1 {
                if data.playerOptions[0] == .play && data.player == playerNumber {
                    privateHandCard.append(data.card!)
                    privateHandCard.sort()
                    let userEvent = delegate!.MCGameSession(currentPlayer: data.player, receivedCard: data.card!, withSortedIndex: privateHandCard.firstIndex(of: data.card!)!, willPlayerCard: true)
                    playedCard.append(privateHandCard.remove(at: privateHandCard.firstIndex(of: userEvent.cards[0])!))
                    if userEvent.playerAction != .play {
                        printMessage(fromMethod: methodSignature, withMessage: "playerAction in userEvent \(String(describing: userEvent)) is not .play", asError: true)
                    }
                    sendData(userEvent)
                    
                } else if data.playerOptions[0] == .pass && data.player == playerNumber {
                    
                    let userEvent = UserEvent(player: playerNumber!, cards: [], playerAction: .pass)
                    sendData(userEvent)
                    
                } else {
                    printMessage(fromMethod: methodSignature, withMessage: "received data \(String(describing: data))", asError: true)
                }
                
            } else if data.playerOptions.count > 1 {
                
                if data.player == playerNumber {
                    
                    if data.playerOptions.contains(.play) {
                        
                        privateHandCard.append(data.card!)
                        privateHandCard.sort()
                        
                        let userEvent = delegate!.MCGameSession(currentPlayer: data.player, receivedCard: data.card!, withSortedIndex: privateHandCard.firstIndex(of: data.card!)!, willChooseFromActions: data.playerOptions)
                        switch userEvent.playerAction {
                        case .win:
                            self.delegate!.MCGameSession(player: data.player, didWin: true)
                        case .kong:
                            playerKongCard[playerNumber!].append(userEvent.cards[0])
                            privateHandCard.remove(at: privateHandCard.firstIndex(of: userEvent.cards[0])!)
                            for _ in 1...3 {
                                privateHandCard.remove(at: privateHandCard.firstIndex(of: userEvent.cards[0])!)
                                publicHandCard.append(userEvent.cards[0])
                            }
                        case .play:
                            
                            playedCard.append(privateHandCard.remove(at: privateHandCard.firstIndex(of: userEvent.cards[0])!))

                        default:
                            print()
                        }
                        sendData(userEvent)
                        
                    } else if data.playerOptions.contains(.pass) {
                        
                        var tmpHandCards = privateHandCard
                        tmpHandCards.append(data.card!)
                        tmpHandCards.sort()
                        
                        let (userEvent, userPlayEvent) = delegate!.MCGameSession(currentPlayer: playerNumber!, willChooseFromActions: data.playerOptions, withPlayedCard: data.card!, withSortedIndex: tmpHandCards.firstIndex(of: data.card!)!)
                        
                        switch userEvent.playerAction {
                        case .win:
                            self.delegate!.MCGameSession(player: data.player, didWin: true)
                        case .kong:
                            playerKongCard[playerNumber!].append(userEvent.cards[0])
                            playedCard.remove(at: playedCard.count - 1)
                            for _ in 1...3 {
                                privateHandCard.remove(at: privateHandCard.firstIndex(of: userEvent.cards[0])!)
                                publicHandCard.append(userEvent.cards[0])
                            }
                        case .pong:
                            _ = playedCard.popLast()
                            publicHandCard.append(userEvent.cards[0])
                            for _ in 1...2 {
                                privateHandCard.remove(at: privateHandCard.firstIndex(of: userEvent.cards[0])!)
                                publicHandCard.append(userEvent.cards[0])
                            }
                            playedCard.append(privateHandCard.remove(at: privateHandCard.firstIndex(of: userPlayEvent!.cards[0])!))
                        case .chow:
                            
                            privateHandCard.append(playedCard.popLast()!)
                            for card in userEvent.cards.sorted() {
                                privateHandCard.remove(at: privateHandCard.firstIndex(of: card)!)
                                publicHandCard.append(card)
                            }
                            playedCard.append(privateHandCard.remove(at: privateHandCard.firstIndex(of: userPlayEvent!.cards[0])!))
                        case .pass:
                            print()
                        default:
                            printMessage(fromMethod: methodSignature, withMessage: "playerAction in userEvents \(String(describing: userEvent)), \(String(describing: userPlayEvent)) is not expected", asError: true)
                        }
                        
                        sendData(userEvent)
                        if userPlayEvent != nil {
                            sendData(userPlayEvent)
                        }
                        
                    } else {
                        printMessage(fromMethod: methodSignature, withMessage: "received data \(String(describing: data))", asError: true)
                    }
                }
                
            } else {
                printMessage(fromMethod: methodSignature, withMessage: "received data \(String(describing: data))", asError: true)
            }
        }
        
        if let data = userEventData {
            if data.player != playerNumber {
                switch data.playerAction {
                case .win:
                    delegate!.MCGameSession(player: data.player, didWin: true)
                case .kong:
                    let card = playedCard.popLast()
                    for _ in 1...3 {
                        otherPlayerHandCard[data.player][otherPlayerHandCard[data.player].firstIndex(of: Card(cardType: .hidden, cardValue: 0))!] = card!
                    }
                    playerKongCard[data.player].append(card!)
                    delegate!.MCGameSession(otherPlayer: data.player, didAction: data.playerAction, withCards: data.cards)
                case .pong:
                    let card = playedCard.popLast()
                    for _ in 1...3 {
                        otherPlayerHandCard[data.player][otherPlayerHandCard[data.player].firstIndex(of: Card(cardType: .hidden, cardValue: 0))!] = card!
                    }
                    delegate!.MCGameSession(otherPlayer: data.player, didAction: data.playerAction, withCards: data.cards)
                case .chow:
                    _ = playedCard.popLast()
                    for card in data.cards {
                        otherPlayerHandCard[data.player][otherPlayerHandCard[data.player].firstIndex(of: Card(cardType: .hidden, cardValue: 0))!] = card
                    }
                    delegate!.MCGameSession(otherPlayer: data.player, didAction: data.playerAction, withCards: data.cards)
                case .play:
                    if data.cards.count != 1 {
                        printMessage(fromMethod: methodSignature, withMessage: "received data \(String(describing: data))", asError: true)
                    }
                    playedCard.append(data.cards[0])
                    delegate!.MCGameSession(otherPlayer: data.player, didPlayCard: data.cards[0])
                    
                default:
                    print()
                }
            }
            
            if isHost {
                let gameEvent = callServerNextAction(userEvent: data)
                if gameEvent != nil {
                    sendData(gameEvent)
                }
            }
        }
    }
    
    // added to satisfy protocol requirement
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

