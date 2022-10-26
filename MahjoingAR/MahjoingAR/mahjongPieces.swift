//
//  mahjongPieces.swift
//  MahjoingAR
//
//  Created by Xuyan Qin on 12/3/20.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//

import UIKit
import SceneKit
class mahjongBlock: SCNNode {
    //Reference:https://stackoverflow.com/questions/48505345/static-image-for-3d-object-swift-ar
    var picture = UIImage(named: "fa")
    var spot = SCNVector3(x: 0, y: 0, z: 0)
  override init() {
    super.init()
    self.geometry = SCNSphere(radius: 0.1)
    self.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
    self.physicsBody?.isAffectedByGravity = false
    let material = SCNMaterial()
    material.isDoubleSided = false
    material.diffuse.contents = picture
    material.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(-1, 1, 1), 1, 0, 0)
    
    
    let newPoint = SCNPlane(width: 0.1, height: 0.3)
    newPoint.materials = [material]
    let newPointNode = SCNNode(geometry: newPoint)
    newPointNode.position = spot
    newPointNode.constraints = [SCNBillboardConstraint()]
  }
  required init?(coder: NSCoder) {
    fatalError("init(coder: ) has not been implemented")
  }
}
