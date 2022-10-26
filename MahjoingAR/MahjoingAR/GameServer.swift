//
//  GameServer.swift
//  MahjoingAR
//
//  Created by 雲無心 on 11/22/20.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//
//  This class is used to create a GameServer object that hosts the game.
//

import GameplayKit

enum GameState {
    case startGame
    case awaitingPlayerSelfAction(player: Int)
    case awaitingOtherPlayerAction(originalPlayer: Int, currentPlayer: Int, originalCard: Card, optionList: [[PlayerAction]])
    case endGame
}

enum PlayerAction: Int, Codable {
    case win // 胡
    case kong // 杠
    case pong // 碰
    case chow // 吃
    case play // 出牌
    case pass // 放弃胡/杠/碰/吃
}

enum CardType: String, Comparable, Codable {
    
    case circles
    case bamboo
    case character
    case wind
    case dragon
    case hidden
    
    static func < (lhs: CardType, rhs: CardType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

struct Card: Comparable, Hashable, Codable {
    
    let cardType: CardType
    let cardValue: Int
    
    static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.cardType < rhs.cardType {
            return true
        } else if rhs.cardType < lhs.cardType {
            return false
        } else {
            return lhs.cardValue < rhs.cardValue
        }
    }
}

struct PlayerData {
    let cardPile: [Int]
    let handCards: [Card]
    let playedCards: [Card]
    let playerActions: [PlayerAction]
}

struct GameStart: Codable {
    let dices: [Int]
    let cardPile: [Int]
    let playerHandCards: [[Card]]
}

struct GameEvent: Codable {
    let player: Int // in range 0-3
    let card: Card?
    let playerOptions: [PlayerAction]
    let message: String? // only contains value when card is nil: "WIN" if player wins, "DRAW" if no one can win, error message if error occurs
}

class GameServer {
    
    private var cardPile: [Card?] = []
    private var playerPrivateHandCards: [[Card]] = []
    private var playerHandCardsKong: [[Card]] = [ ]
    private var playerPublicHandCards: [[Card]] = []
    private var playedCards: [Card] = []
    private var gameState: GameState = .startGame
    private var nextCardIndex: Int = 0
    private var nextCustomCardIndex: Int = 0

    init() {
        for i in 1...9 {
            for _ in 1...4 {
                cardPile.append(Card(cardType: .bamboo, cardValue: i))
                cardPile.append(Card(cardType: .character, cardValue: i))
                cardPile.append(Card(cardType: .circles, cardValue: i))
            }
        }
        for _ in 1...4 {
            for i in 1...3 {
                cardPile.append(Card(cardType: .dragon, cardValue: i))
            }
            for i in 1...4 {
                cardPile.append(Card(cardType: .wind, cardValue: i))
            }
        }
        cardPile = GKARC4RandomSource().arrayByShufflingObjects(in: cardPile as [Any]) as! [Card]
    }
    
    // starts the game, assign all the cards
    func startGame() -> GameStart {
        var dices: [Int] = []
        for _ in 1...4 {
            dices.append(GKRandomDistribution.d6().nextInt())
        }
        
        playerPublicHandCards = [[], [], [], []]
        playerPrivateHandCards = [[], [], [], []]
        playerHandCardsKong = [[], [], [], []]
        nextCardIndex = (136 - (((dices[0] + dices[1] - 1) % 4) * 34) + 2 * dices.reduce(0, +) - 1) % 136
        nextCustomCardIndex = nextCardIndex
        for _ in 1...3 {
            for player in 0...3 {
                for _ in 1...4 {
                    playerPrivateHandCards[player].append(takeNextCard(atCustomIndex: nil)!)
                }
            }
        }
        for player in 0...3 {
            playerPrivateHandCards[player].append(takeNextCard(atCustomIndex: nil)!)
        }
        
        var cardPileAppearance: [Int] = []
        for i in 0...67 {
            cardPileAppearance.append(0)
            cardPileAppearance[i] += (cardPile[2 * i] != nil) ? 1 : 0
            cardPileAppearance[i] += (cardPile[2 * i + 1] != nil) ? 1 : 0
        }
        
        for player in 0...3 {
            playerPrivateHandCards[player].sort()
        }
        
        return GameStart(dices: dices, cardPile: cardPileAppearance, playerHandCards: playerPrivateHandCards)
    }
    
    // returns the next game event to happen
    func nextAction() -> GameEvent {
        
        switch gameState {
        
        case .startGame:
            let newCard = takeNextCard(atCustomIndex: nil)!
            playerPrivateHandCards[0].append(newCard)
            playerPrivateHandCards[0].sort()
            
            gameState = .awaitingPlayerSelfAction(player: 0)
            return GameEvent(player: 0, card: newCard, playerOptions: findPlayerOptions(for: 0, withCard: nil, withPreviousPlayer: nil), message: nil)
            
        default:
            return GameEvent(player: -1, card: nil, playerOptions: [], message: nil)
        }
    }
    
    // given player action, returns the next game event to happen
    func nextAction(action: PlayerAction, from player: Int, with cards: [Card]) -> GameEvent? {
        
        switch gameState {
        
        case .awaitingPlayerSelfAction(let expectedPlayer):
            
            guard expectedPlayer == player else {
                let message = "\(gameState) is expecting player \(expectedPlayer) but got player \(player)."
                return GameEvent(player: -1, card: nil, playerOptions: [], message: message)
            }
            guard findPlayerOptions(for: player, withCard: nil, withPreviousPlayer: nil).contains(action) else {
                let message = "\(gameState) got unexpected player action \(action)."
                return GameEvent(player: -1, card: nil, playerOptions: [], message: message)
            }
            
            switch action {
            
            case .win:
                gameState = .endGame
                return GameEvent(player: player, card: nil, playerOptions: [], message: "WIN")
                
            case .play:
                return playCard(from: player, card: cards[0], errorMessage: "--caller: nextAction() --case .awaitingPlayerSelfAction")
                
            case .kong:
                playerHandCardsKong[player].append(cards[0])
                for _ in 1...4 {
                    playerPrivateHandCards[player].remove(at: playerPrivateHandCards[player].firstIndex(of: cards[0])!)
                    playerPublicHandCards[player].append(cards[0])
                }
                return assignNextCard(to: player)
                
            default:
                let message = "\(gameState) got unexpected player action \(action)."
                return GameEvent(player: -1, card: nil, playerOptions: [], message: message)
            }
            
        case .awaitingOtherPlayerAction(let originalPlayer, let currentPlayer, let originalCard, let optionList):
            
            guard currentPlayer == player else {
                let message = "\(gameState) is expecting player \(currentPlayer) but got player \(player)."
                return GameEvent(player: -1, card: nil, playerOptions: [], message: message)
            }
            guard (findPlayerOptions(for: currentPlayer, withCard: originalCard, withPreviousPlayer: originalPlayer).contains(action) || action == .play) else {
                let message = "\(gameState) got unexpected player action \(action)."
                return GameEvent(player: -1, card: nil, playerOptions: [], message: message)
            }
            
            switch action {
            
            case .win:
                gameState = .endGame
                return GameEvent(player: currentPlayer, card: nil, playerOptions: [], message: "WIN")
                
            case .kong:
                playerHandCardsKong[currentPlayer].append(originalCard)
                for _ in 1...3 {
                    playerPublicHandCards[currentPlayer].append(originalCard)
                    playerPrivateHandCards[currentPlayer].remove(at: playerPrivateHandCards[currentPlayer].firstIndex(of: originalCard)!)
                }
                return assignNextCard(to: currentPlayer)
                
            case .pong:
                for _ in 1...3 {
                    playerPublicHandCards[currentPlayer].append(originalCard)
                }
                for _ in 1...2 {
                    playerPrivateHandCards[currentPlayer].remove(at: playerPrivateHandCards[currentPlayer].firstIndex(of: originalCard)!)
                }
                return nil
                
            case .chow:
                playerPublicHandCards[currentPlayer].append(contentsOf: cards)
                playerPrivateHandCards[currentPlayer].append(originalCard)
                for card in cards {
                    playerPrivateHandCards[currentPlayer].remove(at: playerPrivateHandCards[currentPlayer].firstIndex(of: card)!)
                }
                return nil
                
            case .pass:
                return checkFollowUpAction(withCurrentPlayer: currentPlayer, withOriginalPlayer: originalPlayer, withCard: originalCard, otherPlayerOptions: optionList) ?? assignNextCard(to: currentPlayer + 1)
                
            case .play:
                return playCard(from: currentPlayer, card: cards[0], errorMessage: "method nextAction() with gameState = \(gameState), action = \(action)")
            
            }
            
        default:
            let message = "is in unexpected state \(gameState)."
            return GameEvent(player: -1, card: nil, playerOptions: [], message: message)
        }
    }
    
    // Start of helper functions
    
    private func takeNextCard(atCustomIndex customIndex: Int?, findNextInReverse: Bool = true) -> Card? {
        
        if var customCardIndex = customIndex {
            while(cardPile[customCardIndex % 136] == nil && customCardIndex < 136 * 3) {
                customCardIndex += findNextInReverse ? (customCardIndex > 0 ? -1 : 135) : 1
            }
            let card = cardPile[customCardIndex % 136]
            return card
        }
        
        while(cardPile[nextCardIndex % 136] == nil && nextCardIndex < 136 * 3) {
            nextCardIndex += 1
        }
        let card = cardPile[nextCardIndex % 136]
        cardPile[nextCardIndex % 136] = nil
        nextCardIndex += 1
        nextCardIndex %= 136
        return card
    }
    
    private func findPlayerOptions(for player: Int, withCard card: Card?, withPreviousPlayer previousPlayer: Int?) -> [PlayerAction] {
        
        var playerOptions: Set<PlayerAction> = []
        
        var cards = playerPrivateHandCards[player]
        if let extraCard = card {
            cards.append(extraCard)
            cards.sort()
            playerOptions.insert(.pass)
            
            // check pong
            var counter: [Card: Int] = [:]
            for card in cards {
                counter[card] = (counter[card] ?? 0) + 1
            }
            for card in counter.keys {
                if counter[card]! >= 3 && extraCard == card {
                    playerOptions.insert(.pong)
                }
            }
            
            // check chow
            var potential: Set<Int> = []
            if (previousPlayer! + 1) % 4 == player {
                if extraCard.cardType == .circles || extraCard.cardType == .bamboo || extraCard.cardType == .character {
                    for card in playerPrivateHandCards[player] {
                        if card.cardType == extraCard.cardType {
                            potential.insert(card.cardValue)
                        }
                    }
                    let extraValue = extraCard.cardValue
                    if potential.contains(extraValue - 1) && potential.contains(extraValue + 1) {
                        playerOptions.insert(.chow)
                    } else if potential.contains(extraValue - 2) && potential.contains(extraValue - 1) {
                        playerOptions.insert(.chow)
                    } else if potential.contains(extraValue + 1) && potential.contains(extraValue + 2) {
                        playerOptions.insert(.chow)
                    }
                }
            }
            
        } else {
            cards.sort()
            playerOptions.insert(.play)
        }
        
        // check kong
        var cardCounter: [Card: Int] = [:]
        for card in cards {
            cardCounter[card] = (cardCounter[card] ?? 0) + 1
            if cardCounter[card] == 4 {
                playerOptions.insert(.kong)
            }
        }
        
        var pairwiseWin = true
        for i in 0...(cards.count / 2) {
            if cards[2 * i] != cards[2 * i + 1] {
                pairwiseWin = false
                break
            }
        }
        if pairwiseWin {
            playerOptions.insert(.win)
        } else {
            for card in cardCounter.keys {
                if cardCounter[card]! >= 2 {
                    var tmpCards = cards
                    tmpCards.remove(at: tmpCards.firstIndex(of: card)!)
                    tmpCards.remove(at: tmpCards.firstIndex(of: card)!)
                    
                    var cardTypeCounter: [CardType: Int] = [:]
                    for card in tmpCards {
                        cardTypeCounter[card.cardType] = (cardTypeCounter[card.cardType] ?? 0) + 1
                    }
                    
                    var residual = 0
                    for cardType in cardTypeCounter.keys {
                        residual += cardTypeCounter[cardType]! % 3
                    }
                    if residual == 0 && checkWinHelper(for: tmpCards) {
                        playerOptions.insert(.win)
                        break
                    }
                }
            }
        }
        
        return Array(playerOptions)
    }
    
    private func checkWinHelper(for cards: [Card]) -> Bool {
        
        let methodSignature = "checkWinHelper(for:)"
        
        if cards.count == 0 {
            return true
        }
        
        if cards.count % 3 != 0 {
            let message = "cards.count = \(cards.count) and is not divisible by 3"
            printMessage(fromMethod: methodSignature, withMessage: message, asError: true)
            return false
        }
        
        var win = false
        
        var cardValues: Set<Int> = []
        for card in cards {
            if card.cardType == cards[0].cardType {
                cardValues.insert(card.cardValue)
            }
        }
        if cardValues.contains(cards[0].cardValue + 1) && cardValues.contains(cards[0].cardValue + 2) {
            var tmpCards = cards
            for i in 0...2 {
                tmpCards.remove(at: tmpCards.firstIndex(of: Card(cardType: cards[0].cardType, cardValue: cards[0].cardValue + i))!)
            }
            if checkWinHelper(for: tmpCards) {
                win = true
            }
        }
        
        if cards[0] == cards[1] && cards[0] == cards[2] {
            if checkWinHelper(for: Array(cards[3 ..< cards.count])) {
                win = true
            }
        }
        
        return win
    }
    
    private func checkFollowUpAction(withCurrentPlayer currentPlayer: Int, withOriginalPlayer originalPlayer: Int, withCard card: Card, otherPlayerOptions: [[PlayerAction]]) -> GameEvent? {
        
        var optionList = otherPlayerOptions
        
        // check for winning
        for i in 1...3 {
            if optionList[i].contains(.win) {
                optionList[i].remove(at: optionList[i].firstIndex(of: .win)!)
                gameState = .awaitingOtherPlayerAction(originalPlayer: currentPlayer, currentPlayer: (currentPlayer + i) % 4, originalCard: card, optionList: optionList)
                return GameEvent(player: (currentPlayer + i) % 4, card: card, playerOptions: [.win, .pass], message: nil)
            }
        }
        
        // check for kong
        for i in 1...3 {
            if optionList[i].contains(.kong) {
                optionList[i].remove(at: optionList[i].firstIndex(of: .kong)!)
                gameState = .awaitingOtherPlayerAction(originalPlayer: currentPlayer, currentPlayer: (currentPlayer + i) % 4, originalCard: card, optionList: optionList)
                return GameEvent(player: (currentPlayer + i) % 4, card: card, playerOptions: [.kong, .pass], message: nil)
            }
        }
        
        // check for pong
        for i in 1...3 {
            if optionList[i].contains(.pong) {
                optionList[i].remove(at: optionList[i].firstIndex(of: .pong)!)
                gameState = .awaitingOtherPlayerAction(originalPlayer: currentPlayer, currentPlayer: (currentPlayer + i) % 4, originalCard: card, optionList: optionList)
                return GameEvent(player: (currentPlayer + i) % 4, card: card, playerOptions: [.pong, .pass], message: nil)
            }
        }
        
        // check for chow
        if optionList[1].contains(.chow) {
            optionList[1].remove(at: optionList[1].firstIndex(of: .chow)!)
            gameState = .awaitingOtherPlayerAction(originalPlayer: originalPlayer, currentPlayer: (originalPlayer + 1) % 4, originalCard: card, optionList: optionList)
            return GameEvent(player: (originalPlayer + 1) % 4, card: card, playerOptions: [.chow, .pass], message: nil)
        }
        
        return nil
    }
    
    private func playCard(from player: Int, card: Card, errorMessage: String) -> GameEvent {
        
        guard playerPrivateHandCards[player].contains(card) else {
            print(errorMessage)
            let message = "got player \(player) playing card \(card) but card not in player's hand."
            return GameEvent(player: -1, card: nil, playerOptions: [], message: errorMessage + "\n playCard(): " + message)
        }
        playerPrivateHandCards[player].remove(at: playerPrivateHandCards[player].firstIndex(of: card)!)
        playedCards.append(card)
        
        var otherPlayerOptions: [[PlayerAction]] = []
        otherPlayerOptions.append([.pass])
        for i in 1...3 {
            let playerOption = findPlayerOptions(for: (player + i) % 4, withCard: card, withPreviousPlayer: player)
            otherPlayerOptions.append(playerOption)
        }
        
        return checkFollowUpAction(withCurrentPlayer: player, withOriginalPlayer: player, withCard: card, otherPlayerOptions: otherPlayerOptions) ?? assignNextCard(to: player + 1)
    }
    
    private func assignNextCard(to player: Int) -> GameEvent {
        guard let nextCard = takeNextCard(atCustomIndex: nil) else {
            return GameEvent(player: -1, card: nil, playerOptions: [], message: "DRAW")
        }
        playerPrivateHandCards[player % 4].append(nextCard)
        playerPrivateHandCards[player % 4].sort()
        gameState = .awaitingPlayerSelfAction(player: player % 4)
        return GameEvent(player: player % 4, card: nextCard, playerOptions: findPlayerOptions(for: player % 4, withCard: nil, withPreviousPlayer: nil), message: nil)
    }
    
    private func printMessage(fromMethod method: String, withMessage message: String, asError error: Bool) {
        print("\(UIDevice.current.name): \(error ? "Error" : "") GameServer: \(method): \(message)")
    }
}
