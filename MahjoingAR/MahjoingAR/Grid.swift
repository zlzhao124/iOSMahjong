//
//  Grid.swift
//  NextReality_Tutorial4
//
//  Created by Ambuj Punn on 5/2/18.
//  Copyright © 2018 Ambuj Punn. All rights reserved.
//

import Foundation
import SceneKit
import ARKit
var myPieces: [SCNNode] = []
var myPlaces: [SCNVector3] = []
var firstGenerate: SCNVector3?
var isConfigured: Bool = false
class Grid : SCNNode {
    
    var anchor: ARPlaneAnchor
    
    init(anchor: ARPlaneAnchor) {
        self.anchor = anchor
        print(anchor)
        super.init()
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        for i in 1...13 {
            let box = SCNBox(width: 0.045, height: 0.06, length: 0.03, chamferRadius: 0.005)
            let imageName = "\(currentCard![i-1].cardType)\(currentCard![i-1].cardValue)"
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
            planeNode.position = SCNVector3Make(anchor.center.x - 0.32 + 0.047 * Float(i), 0, anchor.center.z+0.2);
            firstGenerate = planeNode.position
            //planeNode.transform = SCNMatrix4MakeRotation(Float(-Double.pi / 2.0), 1.0, 0.0, 0.0);
            addChildNode(planeNode)
            myPieces.append(planeNode)
            myPlaces.append(planeNode.position)
        }
        isConfigured = true
        for i in 14...20 {
            myPlaces.append(SCNVector3Make(anchor.center.x - 0.32 + 0.047 * Float(i), 0, anchor.center.z+0.2))
        }
    }
    
}
