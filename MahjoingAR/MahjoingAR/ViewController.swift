//
//  ViewController.swift
//  MahjoingAR
//
//  Created by 雲無心 on 11/20/20.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

var globalNode : SCNNode?
var middlePiece: SCNNode?
var currentCard: [Card]?
var leftCards:[SCNNode] = []
var rightCards:[SCNNode] = []
var frontCards:[SCNNode] = []
var leftPlaces:[SCNVector3] = []
var rightPlaces:[SCNVector3] = []
var frontPlaces:[SCNVector3] = []
var frontPrivate: Int = 12
var leftPrivate: Int = 12
var rightPrivate: Int = 12
var leftNode: [Card] = []
var rightNode: [Card] = []
var frontNode: [Card] = []
//test struct



class ViewController: UIViewController, ARSCNViewDelegate,UIGestureRecognizerDelegate, MCGameSessionControllerDelegate {
    
    var playerIndex: Int?
    var whichNode: Int?
    var myTurn: Bool = false
    var myPeriod: Bool = false
    var canPressButton: Bool = false
    var lastPrivateIndex: Int = 12
    var chowArray: [Card] = []
    var chowIndex: [Int] = []
    func expandPlaces (){
        myPlaces.append(SCNVector3Make(myPlaces[myPlaces.count-1].x + 0.047, 0, myPlaces[myPlaces.count-1].z))
    } // expand myPlaces when kong gives an extra piece.
    
    //create a new Node within the AR view.
    func createNode(imageName: String, spot: SCNVector3) -> SCNNode{
        let box = SCNBox(width: 0.045, height: 0.06, length: 0.03, chamferRadius: 0.005)
        let images = [UIImage(named: imageName), UIColor.white, UIColor.green, UIColor.white, UIColor.white, UIColor.white]
        let sideMaterials = images.map{image -> SCNMaterial in
            let material = SCNMaterial()
            material.diffuse.contents = image
            material.locksAmbientWithDiffuse = true
            return material
        }
        let playerPiece = box
        playerPiece.materials = sideMaterials
        let planeNode = SCNNode(geometry: playerPiece)
        planeNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: playerPiece, options: nil))
        planeNode.physicsBody?.categoryBitMask = 2
        planeNode.position = spot
        globalNode!.addChildNode(planeNode)
        return planeNode
    }
    
    var timer2: Timer? = nil
    func MCGameSession(gameDidStartWithCards cards: [Card], asPlayer playerNumber: Int) {
        //print("VC gameDidStartWithCards \(cards)") // MXT DEBUG
        playerIndex = playerNumber
        currentCard = cards
        notifyHostReadyToReceiveCards()
    }
    
    @objc func notifyHostReadyToReceiveCards() {
        DispatchQueue.global().async { [self] in
            while true {
                if isConfigured {
                    mcSessionController!.readyToReceiveCards()
                    break
                } else {
                    timer2!.invalidate()
                }
            }
        }
    }
    
    var timer: Timer? = nil
    
    //check if the player has made a move
    @objc func checkTurn(){
        while myTurn == true && pongPressed == false && chowPressed == false{
            timer!.invalidate()
        }
    }
    
   // deciding your play/move
    func MCGameSession(currentPlayer player: Int, receivedCard card: Card, withSortedIndex sortedIndex: Int, willPlayerCard playCard: Bool) -> UserEvent {
        currentCard!.insert(card, at: sortedIndex)
        if sortedIndex <= myPieces.count - 1{
            for i in sortedIndex ... myPieces.count-1 {
                myPieces[i].position = myPlaces[i+1]
            }
        }
        myPieces.insert(createNode(imageName: "\(card.cardType)\(card.cardValue)", spot: myPlaces[sortedIndex]),at: sortedIndex)
        myTurn = true
        myPeriod = true
        checkTurn()
        let event = UserEvent(player: playerIndex!, cards: [currentCard![whichNode!]], playerAction: PlayerAction.play)
        currentCard!.remove(at: whichNode!)
        myPeriod = false
        return event
    }
    
    //deciding special moves if can win or kong within your turn
    var buttonDecision: [PlayerAction]?
    func MCGameSession(currentPlayer player: Int, receivedCard card: Card, withSortedIndex sortedIndex: Int, willChooseFromActions actions: [PlayerAction]) -> UserEvent {
        buttonDecision = actions
        currentCard!.insert(card, at: sortedIndex)
        if sortedIndex <= myPieces.count - 1{
            for i in sortedIndex ... myPieces.count-1 {
                myPieces[i].position = myPlaces[i+1]
            }
        }
        myPieces.insert(createNode(imageName: "\(card.cardType)\(card.cardValue)", spot: myPlaces[sortedIndex]),at: sortedIndex)
        DispatchQueue.main.async {
            if(actions.contains(.kong)){
                self.kongButton.alpha = 1.0
            }
            if(actions.contains(.win)){
                self.winButton.alpha = 1.0
            }
        }
        myTurn = true
        myPeriod = true
        canPressButton = true
        checkTurn()
        canPressButton = false
        DispatchQueue.main.async {
            self.kongButton.alpha = 0.0
            self.winButton.alpha = 0.0
        }
        if winPressed == true{
            winPressed = false
            return UserEvent(player: playerIndex!, cards:[], playerAction: PlayerAction.win)
        }else if kongPressed == true {
            kongPressed = false
            let startIndex = sortedIndex
            expandPlaces()
            lastPrivateIndex += 1
            let kongAr = Array(currentCard![startIndex...startIndex+3])
            let kongNode = Array(myPieces[startIndex...startIndex+3])
            if lastPrivateIndex >= startIndex + 4{
                for i in startIndex + 4 ... lastPrivateIndex{
                    myPieces[i].position = myPlaces[i - 4]
                    currentCard![i - 4] = currentCard![i]
                    myPieces[i-4] = myPieces[i]
                }
            }
            for i in (lastPrivateIndex - 3)...lastPrivateIndex{
                currentCard![i] = kongAr[i-(lastPrivateIndex - 3)]
                myPieces[i] = kongNode[i-(lastPrivateIndex - 3)]
                myPieces[i].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
                myPieces[i].position = myPlaces[i]
            }
            middlePiece!.removeFromParentNode()
            lastPrivateIndex -= 4
            return UserEvent(player: playerIndex!, cards: kongAr, playerAction: PlayerAction.kong)
        }else{
            
            let event = UserEvent(player: playerIndex!, cards: [currentCard![whichNode!]], playerAction: PlayerAction.play)
            currentCard!.remove(at: whichNode!)
            myPeriod = false
            return event
        }
        
    }
    
    //alert
    var gameDidFinish:Bool = false
    func createAlert(title:String, message: String){
        //Reference: https://www.youtube.com/watch?v=4EAGIiu7SFU
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:  {(action) in self.presentingViewController!.dismiss(animated: true, completion: nil)
        }))
        self.present(alert,animated: true, completion: nil)
    }
    
    //win
    var alertMessage: String = ""
    func MCGameSession(player: Int, didWin win: Bool) {
        gameDidFinish = true
        DispatchQueue.main.async { [self] in
            alertMessage = "Go Back to the login Page and Replay"
            if player == mcSessionController!.getPlayerNumber() && win == true{
                winLoseLabel.alpha = 1.0
                createAlert(title: "Win", message: alertMessage)
            }else{
                winLoseLabel.text = "Lose"
                winLoseLabel.alpha = 1.0
                createAlert(title: "Lose", message: alertMessage)
            }
            
            
        }
        
    }
    // draw
    func MCGameSession(gameIsDraw draw: Bool) {
        gameDidFinish = true
        DispatchQueue.main.async { [self] in
            winLoseLabel.text = "Draw"
            winLoseLabel.alpha = 1.0
            alertMessage = "Go Back to the login Page and Replay"
            createAlert(title: "Draw", message: alertMessage)
        }
        
    }
    
    // deciding special moves...
    func MCGameSession(currentPlayer player: Int, willChooseFromActions actions: [PlayerAction], withPlayedCard card: Card, withSortedIndex sortedIndex: Int) -> (UserEvent, UserEvent?)  {
        buttonDecision = actions
        DispatchQueue.main.async {
            if(actions.contains(.kong)){
                self.kongButton.alpha = 1.0
            }
            if(actions.contains(.win)){
                self.winButton.alpha = 1.0
            }
            if(actions.contains(.chow)){
                self.chowButton.alpha = 1.0
            }
            if(actions.contains(.pong)){
                self.pongButton.alpha = 1.0
            }
            if(actions.contains(.pass)){
                self.passButton.alpha = 1.0
            }
        }
        var nextMove : UserEvent?
        
        myTurn = true
        canPressButton = true
        checkTurn()
        canPressButton = false
        DispatchQueue.main.async {
            self.passButton.alpha = 0.0
            self.chowButton.alpha = 0.0
            self.kongButton.alpha = 0.0
            self.pongButton.alpha = 0.0
            self.winButton.alpha = 0.0
        }
        if passPressed{
            passPressed = false
            return (UserEvent(player: playerIndex!, cards: [], playerAction: PlayerAction.pass) ,nextMove)
        }else if winPressed == true{
            passPressed = false
            winPressed = false
            return (UserEvent(player: playerIndex!, cards:[], playerAction: PlayerAction.win),nextMove)
        }else if kongPressed == true {
            lastPrivateIndex += 1
            let startIndex = sortedIndex
            currentCard!.insert(card, at: sortedIndex)
            if sortedIndex <= myPieces.count - 1{
                for i in sortedIndex ... myPieces.count-1 {
                    myPieces[i].position = myPlaces[i+1]
                }
            }
            myPieces.insert(createNode(imageName: "\(card.cardType)\(card.cardValue)", spot: myPlaces[sortedIndex]),at: sortedIndex)
            kongPressed = false
            expandPlaces()
            let kongAr = Array(currentCard![startIndex...startIndex+3])
            let kongNode = Array(myPieces[startIndex...startIndex+3])
            if lastPrivateIndex >= startIndex + 4{
                for i in startIndex + 4 ... lastPrivateIndex{
                    myPieces[i].position = myPlaces[i - 4]
                    currentCard![i - 4] = currentCard![i]
                    myPieces[i-4] = myPieces[i]
                }
            }
            for i in (lastPrivateIndex - 3)...lastPrivateIndex{
                currentCard![i] = kongAr[i-(lastPrivateIndex - 3)]
                myPieces[i] = kongNode[i-(lastPrivateIndex - 3)]
                myPieces[i].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
                myPieces[i].position = myPlaces[i]
            }
            middlePiece!.removeFromParentNode()
            lastPrivateIndex -= 4
            return (UserEvent(player: playerIndex!, cards: kongAr, playerAction: PlayerAction.kong),nextMove)
        }else if pongPressed == true{
            currentCard!.insert(card, at: sortedIndex)
            if sortedIndex <= myPieces.count - 1{
                for i in sortedIndex ... myPieces.count-1 {
                    myPieces[i].position = myPlaces[i+1]
                }
            }
            myPieces.insert(createNode(imageName: "\(card.cardType)\(card.cardValue)", spot: myPlaces[sortedIndex]),at: sortedIndex)
            pongPressed = false
            let startIndex = sortedIndex
            let pongAr = Array(currentCard![startIndex...startIndex+2])
            let pongNode = Array(myPieces[startIndex...startIndex+2])
            let pongEvent = UserEvent(player: playerIndex!, cards: pongAr, playerAction: PlayerAction.pong)
            lastPrivateIndex += 1
            if lastPrivateIndex >= startIndex + 3{
                for i in startIndex + 3 ... lastPrivateIndex{
                    myPieces[i].position = myPlaces[i - 3]
                    currentCard![i - 3] = currentCard![i]
                    myPieces[i-3] = myPieces[i]
                }
            }
            for i in (lastPrivateIndex - 2)...lastPrivateIndex{
                currentCard![i] = pongAr[i-(lastPrivateIndex - 2)]
                myPieces[i] = pongNode[i-(lastPrivateIndex - 2)]
                myPieces[i].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
                myPieces[i].position = myPlaces[i]
            }
            middlePiece!.removeFromParentNode()
            lastPrivateIndex -= 3
            myPeriod = true
            checkTurn()
            lastPrivateIndex -= 1
            nextMove = UserEvent(player: playerIndex!, cards: [currentCard![whichNode!]], playerAction: PlayerAction.play)
            //return event
            currentCard!.remove(at: whichNode!)
            myTurn = false
            myPeriod = false
            return(pongEvent, nextMove)
        }else{
            while chowArray.count <= 2{
                if chowArray.count == 2{
                    chowArray.append(card)
                    if mcSessionController!.isLegalChow(forCurrentPlayer: playerIndex!, withCards: chowArray) != true {
                        myPieces[chowIndex[0]].position = SCNVector3(x: myPlaces[chowIndex[0]].x, y: myPlaces[chowIndex[0]].y, z: myPlaces[chowIndex[0]].z)
                        myPieces[chowIndex[1]].position = SCNVector3(x: myPlaces[chowIndex[1]].x, y: myPlaces[chowIndex[1]].y, z: myPlaces[chowIndex[1]].z)
                        // update piece position
                        chowArray = []
                        chowIndex = []
                    }else{
                        myPieces[chowIndex[0]].position = SCNVector3(x: myPlaces[chowIndex[0]].x, y: myPlaces[chowIndex[0]].y, z: myPlaces[chowIndex[0]].z)
                        myPieces[chowIndex[1]].position = SCNVector3(x: myPlaces[chowIndex[1]].x, y: myPlaces[chowIndex[1]].y, z: myPlaces[chowIndex[1]].z)
                    }
                }
                timer!.invalidate()
            }
            
            chowArray = chowArray.sorted()
            middlePiece!.removeFromParentNode()
            var iter = 0;
            let myPiecesMem = myPieces
            let myCards = currentCard
            myPieces[chowIndex[0]].removeFromParentNode()
            myPieces[chowIndex[1]].removeFromParentNode()
            myPieces = []
            for i in 0 ... myPiecesMem.count-1{
                if !chowIndex.contains(i){
                    myPieces.append(myPiecesMem[i])
                    currentCard!.append(myCards![i])
                    iter += 1
                }
            }
            chowPressed = false
            for i in iter ... iter + 2{
                currentCard!.append(chowArray[i - iter])
                myPieces.append(createNode(imageName: "\(chowArray[i - iter].cardType)\(chowArray[i - iter].cardValue)", spot: myPlaces[i]))
                myPieces[i].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
            }
            for i in 0 ... myPieces.count - 1{
                myPieces[i].position = myPlaces[i]
            }
            
            
            let chowEvent = UserEvent(player: playerIndex!, cards:chowArray, playerAction: PlayerAction.chow)
            lastPrivateIndex += 1 //chowed a piece
            lastPrivateIndex -= 3 //publicize three chow pieces
            myPeriod = true
            checkTurn()
            lastPrivateIndex -= 1 //play one piece
            nextMove = UserEvent(player: playerIndex!, cards: [currentCard![whichNode!]], playerAction: PlayerAction.play)
            currentCard!.remove(at: whichNode!)
            myTurn = false
            myPeriod = false
            chowArray = []
            chowIndex = []
            return(chowEvent, nextMove)
        }
    }
    
    //MCGameSession reception: display played card from other players
    func MCGameSession(otherPlayer player: Int, didPlayCard card: Card) {
        if let tempPiece = middlePiece{
            print(tempPiece)
            print("initializing...")
            middlePiece!.removeFromParentNode()
        }
        middlePiece = createNode(imageName: "\(card.cardType)\(card.cardValue)", spot: SCNVector3(x: 0.0, y: 0.0, z: 0.0))
        middlePiece!.transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
        globalNode!.addChildNode(middlePiece!)
    }
    
    //MCGameSession reception: display special moves from other players
    func MCGameSession(otherPlayer player: Int, didAction action: PlayerAction, withCards cards: [Card]) {
        if action == .chow || action == .kong || action == .pong{
            let thisPlayer = (player - playerIndex! + 4)%4
            if thisPlayer == 1{
                rightNode.append(contentsOf: cards)
                if action == .kong{
                    rightCards.append(createNode(imageName: "", spot: rightPlaces[rightCards.count]))
                }
                for i in 0 ... rightNode.count - 1{
                    let index = rightCards.count - 1 - i
                    let card = rightNode[rightNode.count - i - 1]
                    rightCards[index].removeFromParentNode()
                    let rightPiece = SCNBox(width: 0.03, height: 0.06, length: 0.045, chamferRadius: 0.005)
                    let rightMaterial  = [UIColor.white,UIImage(named: "\(card.cardType)\(card.cardValue)"),UIColor.white,UIColor.green, UIColor.white,UIColor.white].map{otherimage -> SCNMaterial in
                        let tempmaterial =  SCNMaterial()
                        tempmaterial.diffuse.contents = otherimage
                        tempmaterial.locksAmbientWithDiffuse = true
                        return tempmaterial
                    }
                    rightPiece.materials = rightMaterial
                    let rightNode = SCNNode(geometry: rightPiece)
                    rightNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: rightPiece, options: nil))
                    rightNode.physicsBody?.categoryBitMask = 2
                    globalNode!.addChildNode(rightNode)
                    rightCards[index] = rightNode
                    rightCards[index].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 0.0, 0.0, -1.0)
                    for i in 0 ... rightCards.count - 1{
                        rightCards[i].position = rightPlaces[i]
                    }
                }
                
            }else if thisPlayer == 2{
                frontNode.append(contentsOf: cards)
                if action == .kong{
                    frontCards.append(createNode(imageName: "", spot: frontPlaces[frontCards.count]))
                }
                for i in 0 ... frontNode.count - 1{
                    let index = frontCards.count - 1 - i
                    let card = frontNode[frontNode.count - i - 1]
                    frontCards[index].removeFromParentNode()
                    let box = SCNBox(width: 0.045, height: 0.06, length: 0.03, chamferRadius: 0.005)
                    let otherPiece = box
                    let otherMaterial = [UIColor.green,UIColor.white,UIImage(named: "\(card.cardType)\(card.cardValue)"),UIColor.white,UIColor.white,UIColor.white]
                    let blankMaterial = otherMaterial.map{otherimage -> SCNMaterial in
                        let tempmaterial =  SCNMaterial()
                        tempmaterial.diffuse.contents = otherimage
                        tempmaterial.locksAmbientWithDiffuse = true
                        return tempmaterial
                    }
                    otherPiece.materials = blankMaterial
                    let otherNode = SCNNode(geometry: otherPiece)
                    otherNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: otherPiece, options: nil))
                    otherNode.physicsBody?.categoryBitMask = 2
                    globalNode!.addChildNode(otherNode)
                    frontCards[index] = otherNode
                    frontCards[index].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), -1.0, 0.0, 0.0)
                    for i in 0 ... frontCards.count - 1{
                        frontCards[i].position = frontPlaces[i]
                    }
                }
            }else if thisPlayer == 3{
                leftNode.append(contentsOf: cards)
                if action == .kong{
                    leftCards.append(createNode(imageName: "", spot: leftPlaces[leftCards.count]))
                }
                for i in 0 ... leftNode.count - 1{
                    let index = leftCards.count - 1 - i
                    let card = leftNode[leftNode.count - i - 1]
                    leftCards[index].removeFromParentNode()
                    let leftPiece = SCNBox(width: 0.03, height: 0.06, length: 0.045, chamferRadius: 0.005)
                    let leftMaterial  = [UIColor.white, UIColor.green,UIColor.white,UIImage(named: "\(card.cardType)\(card.cardValue)"),UIColor.white,UIColor.white].map{otherimage -> SCNMaterial in
                        let tempmaterial =  SCNMaterial()
                        tempmaterial.diffuse.contents = otherimage
                        tempmaterial.locksAmbientWithDiffuse = true
                        return tempmaterial
                    }
                    leftPiece.materials = leftMaterial
                    let leftNode = SCNNode(geometry: leftPiece)
                    leftNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: leftPiece, options: nil))
                    leftNode.physicsBody?.categoryBitMask = 2
                    globalNode!.addChildNode(leftNode)
                    leftCards[index] = leftNode
                    leftCards[index].transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 0.0, 0.0, 1.0)
                    for i in 0 ... leftCards.count - 1{
                        leftCards[i].position = leftPlaces[i]
                    }
                }
                
            }
        }
    }
    
    
    var isHost: Bool?
    var displayName: String?
    var peerID: MCPeerID?
    var mcSession: MCSession?
    var mcSessionController: MCSessionController?
    var grids : Grid?
    //    @IBOutlet var arSceneView: ARSCNView!
    @IBOutlet weak var arSceneView: ARSCNView!
    
    
    @IBOutlet weak var pongButton: UIButton!
    @IBOutlet weak var kongButton: UIButton!
    @IBOutlet weak var winButton: UIButton!
    @IBOutlet weak var passButton: UIButton!
    @IBOutlet weak var chowButton: UIButton!
    @IBOutlet weak var winLoseLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mcSessionController = MCSessionController(deviceIsHost: isHost!, playerDisplayName: displayName!, withMCPeerID: peerID!, withMCSession: mcSession!)
        mcSessionController!.delegate = self
        arSceneView.delegate = self
        arSceneView.showsStatistics = true
        //arSceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        let scene = SCNScene()
        
        
        arSceneView.scene = scene
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleThePan(gestureRecognizer:)))
        arSceneView.addGestureRecognizer(panRecognizer)
        panRecognizer.delegate = self
        pongButton.alpha = 0.0
        chowButton.alpha = 0.0
        passButton.alpha = 0.0
        kongButton.alpha = 0.0
        winButton.alpha = 0.0
        chowButton.alpha = 0.0
        passButton.alpha = 0.0
        winLoseLabel.alpha = 0.0
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkTurn), userInfo: nil, repeats: true)
        timer2 = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(notifyHostReadyToReceiveCards), userInfo: nil, repeats: true)
        
    }
    
    
    var lastPanPosition: SCNVector3?
    var panningNode: SCNNode?
    var panStartZ: CGFloat?
    var number: Int = 0
    // capturing gestures
    //Reference: https://medium.com/@literalpie/dragging-objects-in-scenekit-and-arkit-3568212a90e5
    @objc func handleThePan(gestureRecognizer: UIPanGestureRecognizer){
        
        switch gestureRecognizer.state {
        case .began:
            let location = gestureRecognizer.location(in: arSceneView)
            guard let hitNodeResult = arSceneView.hitTest(location, options: nil).first else { return }
            lastPanPosition = hitNodeResult.worldCoordinates
            panningNode = hitNodeResult.node
            panStartZ = CGFloat(arSceneView.projectPoint(lastPanPosition!).z)
            
            
        case .changed:
            guard lastPanPosition != nil, panningNode != nil, panStartZ != nil else { return }
            let location = gestureRecognizer.location(in: arSceneView)
            let worldTouchPosition = arSceneView.unprojectPoint(SCNVector3(location.x, location.y, panStartZ!))
            
            let movementVector = SCNVector3(worldTouchPosition.x - lastPanPosition!.x,
                                            worldTouchPosition.y - lastPanPosition!.y,
                                            worldTouchPosition.z - lastPanPosition!.z)
            panningNode?.localTranslate(by: movementVector)
            
            self.lastPanPosition = worldTouchPosition
            
        case .ended:
            if myPieces.count >= 13 {
                var tempDistance: Float = 0.0
                for i in 0...myPieces.count-1{
                    let distance = (pow(myPieces[i].position.y - myPlaces[i].y,2) + pow(myPieces[i].position.z - myPlaces[i].z,2)).squareRoot()
                    if (distance > tempDistance){
                        tempDistance = distance
                        whichNode = i
                    }
                }
                if chowPressed{
                    if tempDistance > 0.04{
                        chowIndex.append(whichNode!)
                        myPieces[whichNode!].position = SCNVector3(x: myPlaces[whichNode!].x, y: myPlaces[whichNode!].y + 0.03, z: myPlaces[whichNode!].z)
                        chowArray.append(currentCard![whichNode!])
                    }
                }
                else if myTurn && myPeriod {
                    if (tempDistance > 0.08){
                        
                        if let tempPiece = middlePiece{
                            print(tempPiece)
                            middlePiece!.removeFromParentNode()
                        }
                        middlePiece = createNode(imageName: "\(currentCard![whichNode!].cardType)\(currentCard![whichNode!].cardValue)", spot: SCNVector3(x: 0.0, y: 0.0, z: 0.0))
                        middlePiece!.position = SCNVector3(x: 0, y: 0, z: 0)
                        //if globalNode!.childNodes.contains(middlePiece!){
                        globalNode!.addChildNode(middlePiece!)
                        middlePiece!.transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0)
                        globalNode!.addChildNode(middlePiece!)
                        myPieces[whichNode!].removeFromParentNode()
                        myPieces.remove(at: whichNode!)
                        for i in 0...myPieces.count-1{
                            myPieces[i].position = myPlaces[i]
                        }
                        myTurn = false
                    }
                }else{
                    if (tempDistance > 0.08){
                        for i in 0...myPieces.count-1{
                            myPieces[i].position = myPlaces[i]
                        }
                    }
                }
            }
            (lastPanPosition, panningNode, panStartZ) = (nil, nil, nil)
            
        default:
            return
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        arSceneView.session.run(configuration)
    }
    //touch the screen to create a Mahjong set.
    
    //rendering the mahjong set from the initiated plane
    var firstNode : Bool = true
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if(firstNode){
            globalNode = node
            let grid = Grid(anchor: anchor as! ARPlaneAnchor)
            self.grids = grid
            node.addChildNode(grid)
            let plane = anchor as! ARPlaneAnchor
            for i in 1...13 {
                let box = SCNBox(width: 0.045, height: 0.06, length: 0.03, chamferRadius: 0.005)
                let otherPiece = box
                let otherMaterial = [UIColor.green,UIColor.white,UIColor.white,UIColor.white,UIColor.white,UIColor.white]
                let blankMaterial = otherMaterial.map{otherimage -> SCNMaterial in
                    let tempmaterial =  SCNMaterial()
                    tempmaterial.diffuse.contents = otherimage
                    tempmaterial.locksAmbientWithDiffuse = true
                    return tempmaterial
                }
                otherPiece.materials = blankMaterial
                let otherNode = SCNNode(geometry: otherPiece)
                otherNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: otherPiece, options: nil))
                otherNode.physicsBody?.categoryBitMask = 2
                
                otherNode.position = SCNVector3Make(plane.center.x - 0.32 + 0.047 * Float(i), 0, plane.center.z-0.5);
                //otherNode.transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0);
                node.addChildNode(otherNode)
                frontCards.append(otherNode)
                frontPlaces.append(otherNode.position)
                
                
                // add left mahjong set
                let leftPiece = SCNBox(width: 0.03, height: 0.06, length: 0.045, chamferRadius: 0.005)
                let leftMaterial  = [UIColor.white,UIColor.green,UIColor.white,UIColor.white,UIColor.white,UIColor.white].map{otherimage -> SCNMaterial in
                    let tempmaterial =  SCNMaterial()
                    tempmaterial.diffuse.contents = otherimage
                    tempmaterial.locksAmbientWithDiffuse = true
                    return tempmaterial
                }
                leftPiece.materials = leftMaterial
                let leftNode = SCNNode(geometry: leftPiece)
                leftNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: leftPiece, options: nil))
                leftNode.physicsBody?.categoryBitMask = 2
                leftNode.position = SCNVector3Make(plane.center.x - 0.35, 0, plane.center.z-0.5 + 0.047 * Float(i));
                node.addChildNode(leftNode)
                leftCards.append(leftNode)
                leftPlaces.append(leftNode.position)
                
                // add right mahjong set
                let rightPiece = SCNBox(width: 0.03, height: 0.06, length: 0.045, chamferRadius: 0.005)
                let rightMaterial  = [UIColor.white,UIColor.white,UIColor.white,UIColor.green,UIColor.white,UIColor.white].map{otherimage -> SCNMaterial in
                    let tempmaterial =  SCNMaterial()
                    tempmaterial.diffuse.contents = otherimage
                    tempmaterial.locksAmbientWithDiffuse = true
                    return tempmaterial
                }
                rightPiece.materials = rightMaterial
                let rightNode = SCNNode(geometry: rightPiece)
                rightNode.physicsBody = SCNPhysicsBody(type: .static, shape:    SCNPhysicsShape(geometry: rightPiece, options: nil))
                rightNode.physicsBody?.categoryBitMask = 2
                rightNode.position = SCNVector3Make(plane.center.x + 0.35, 0, plane.center.z-0.5 + 0.047 * Float(i));
                node.addChildNode(rightNode)
                rightCards.append(rightNode)
                rightPlaces.append(rightNode.position)
            }
            for i in 14 ... 20{
                frontPlaces.append(SCNVector3Make(plane.center.x - 0.32 + 0.047 * Float(i), 0, plane.center.z-0.5))
                leftPlaces.append(SCNVector3Make(plane.center.x - 0.35, 0, plane.center.z-0.5 + 0.047 * Float(i)))
                rightPlaces.append(SCNVector3Make(plane.center.x + 0.35, 0, plane.center.z-0.5 + 0.047 * Float(i)))
            }
            firstNode = false
        }
    }
    
    //detect a plane to form majong set with touches
    var isFirstTouch : Bool = true
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let cards = currentCard{
            print(cards)
            if (isFirstTouch){
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                arSceneView.session.run(configuration)
                
                isFirstTouch = false;
            }
        }
    }
    
    //Reference: https://stfalconcom.medium.com/augmented-reality-with-swift-5-how-to-start-19118c77dffe
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSceneView.session.pause()
    }
    
    //chow button
    var chowPressed: Bool = false
    @IBAction func chowButtonPressed(_ sender: Any) {
        if canPressButton{
            if buttonDecision!.contains(.chow){
                chowPressed = true
            }
        }
    }
    
    //pass button
    var passPressed: Bool = false
    @IBAction func passButtonPressed(_ sender: Any) {
        if canPressButton{
            if buttonDecision!.contains(.pass){
                passPressed = true
                myTurn = false
            }
        }
    }
    
    //pong button
    var pongPressed: Bool = false
    @IBAction func pongButtonPressed(_ sender: Any) {
        if canPressButton{
            if buttonDecision!.contains(.pong){
                pongPressed = true
            }
        }
    }
    
    //kong button
    var kongPressed: Bool = false
    @IBAction func kongButtonPressed(_ sender: Any) {
        if canPressButton{
            if buttonDecision!.contains(.kong){
                kongPressed = true
                myTurn = false
            }
        }
    }
    
    //win button
    var winPressed: Bool = false
    @IBAction func winButtonPressed(_ sender: Any) {
        if canPressButton{
            if buttonDecision!.contains(.win){
                winPressed = true
                myTurn = false
            }
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        return UIInterfaceOrientationMask.landscape
    }
}
