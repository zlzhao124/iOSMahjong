//
//  LoginPage.swift
//  MahjoingAR
//
//  Created by Xuyan Qin on 11/22/20.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//




//This is the first login Page

import UIKit
import MultipeerConnectivity

class LoginPage: UIViewController {
    
    // used by Multipeer Connectivity View Controllers
    private var peerID: MCPeerID?
    private var mcSession: MCSession?
    
    //Below is the IBOutlet from the StoryBoard
    @IBOutlet weak var nameBox: UITextField!
    @IBOutlet weak var hostButton: UIButton!
    @IBOutlet weak var joinFriendButton: UIButton!
    @IBOutlet weak var faImage: UIImageView!
    
    
    //test button !!!!!!!
    @IBOutlet weak var arViewButton: UIButton!
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the middle image icon to be FA
        faImage.image = UIImage(named: "fa")
        
        nameBox.placeholder = UIDevice.current.name
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID!)
    }

    //Rules Button Pressed Function. This function will navigate to the RulesPage
    @IBAction func rulesPressed(_ sender: Any) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rulesPageViewController = storyBoard.instantiateViewController(identifier: "RulesViewController") as! RulesPage
        rulesPageViewController.modalPresentationStyle = .fullScreen
        self.present(rulesPageViewController, animated: true, completion: nil)
    }
    
    // "Start as a host" button pressed, go to next page with host configuration
    @IBAction func startAsHostPressed(_ sender: Any) {
        

            let mcDiscoverViewController = MCDiscoverViewController()
            mcDiscoverViewController.displayName = nameBox.text != "" ? nameBox.text : UIDevice.current.name
            mcDiscoverViewController.isHost = true
            mcDiscoverViewController.peerID = peerID
            mcDiscoverViewController.mcSession = mcSession
            mcDiscoverViewController.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(mcDiscoverViewController, animated: true)
    
    }
    
    // "Join my friends" button pressed, go to next page with paticipant configuration
    @IBAction func joinFriendPressed(_ sender: Any) {

        let mcDiscoverViewController = MCDiscoverViewController()
        mcDiscoverViewController.displayName = nameBox.text != "" ? nameBox.text : UIDevice.current.name
        mcDiscoverViewController.isHost = false
        mcDiscoverViewController.peerID = peerID
        mcDiscoverViewController.mcSession = mcSession
        mcDiscoverViewController.modalPresentationStyle = .fullScreen
        navigationController?.pushViewController(mcDiscoverViewController, animated: true)

    }
    
    //Function alert user to input his name
    func createAlert(title:String, message: String){
        //Reference: https://www.youtube.com/watch?v=4EAGIiu7SFU
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler:  {(action) in alert.dismiss(animated: true, completion: nil)
        }))
        self.present(alert,animated: true, completion: nil)
    }
    
    //Dismiss keyboard
    //Reference:https://stackoverflow.com/questions/32281651/how-to-dismiss-keyboard-when-touching-anywhere-outside-uitextfield-in-swift
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }

    @IBAction func testFunction(_ sender: Any) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let arViewController = storyBoard.instantiateViewController(identifier: "arViewController") as! ViewController
        arViewController.modalPresentationStyle = .fullScreen
        self.present(arViewController, animated: true, completion: nil)
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        return UIInterfaceOrientationMask.portrait
    }
    
}
