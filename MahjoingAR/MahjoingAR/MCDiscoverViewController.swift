//
//  MCViewController.swift
//  MahjoingAR
//
//  Created by 雲無心 on 12/4/20.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//

import UIKit
import MultipeerConnectivity

let serviceType = "mahjoing-ar"

class MCDiscoverViewController: UIViewController {
    
    var displayName: String?
    var isHost: Bool?
    var peerID: MCPeerID?
    var mcSession: MCSession?
    private var mcBrowserViewController: MCBrowserViewController?
    private var mcAdvertiserAssistant: MCAdvertiserAssistant?
    private var textView: UITextView?
    private var arViewController: ViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set up text view
        view.backgroundColor = UIColor.systemBackground
        textView = UITextView(frame: CGRect(x: 0, y: view.frame.height * 0.3, width: view.frame.width, height: 100))
        textView?.textColor = UIColor.systemGray
        textView?.textAlignment = .center
        textView?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        textView?.isEditable = false
        textView?.isSelectable = false
        view.addSubview(textView!)
        textView?.text = "Please wait"
        
        // set up parameters
        displayName = displayName ?? UIDevice.current.name
        isHost = isHost ?? false
        mcSession?.delegate = self
        
        // begin browsing or advertising for MultipeerConnectivity
        if isHost! {
            mcBrowserViewController = MCBrowserViewController(serviceType: serviceType, session: mcSession!)
            mcBrowserViewController?.maximumNumberOfPeers = 4
            mcBrowserViewController?.minimumNumberOfPeers = 4
            mcBrowserViewController?.modalPresentationStyle = .fullScreen
            mcBrowserViewController?.delegate = self
            present(mcBrowserViewController!, animated: true)
        } else {
            mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: serviceType, discoveryInfo: nil, session: mcSession!)
            mcAdvertiserAssistant?.start()
        }
        
        updateTextView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTextView()
        
        // if game finished then go back to LoginPage
        if arViewController != nil {
            if arViewController!.gameDidFinish {
                navigationController?.popViewController(animated: true)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        mcAdvertiserAssistant?.stop()
        mcAdvertiserAssistant = nil
        mcBrowserViewController = nil
    }
    
    func updateTextView() {
        DispatchQueue.main.async { [self] in
            textView?.text = isHost! ? "You are the host \"\(displayName!)\".\nPlease invite others to your game.\n" : "Now discoverable as \"\(displayName!)\".\n"
            textView?.text += "\n"
            textView?.text += "Players in current session:\n"
            textView?.text += "\(displayName!)\n"
            if mcSession?.connectedPeers.count ?? 0 > 0 {
                for peerID in mcSession!.connectedPeers {
                    textView?.text += "\(peerID.displayName)\n"
                }
            }
            
            // https://stackoverflow.com/questions/29431968/how-to-adjust-the-height-of-a-textview-to-his-content-in-swift
            let contentSize = textView?.sizeThatFits((textView?.bounds.size)!)
            textView?.frame.size.height = contentSize?.height ?? 100
        }
    }
    
    func transitToARViewController() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        arViewController = storyBoard.instantiateViewController(identifier: "arViewController") as? ViewController
        arViewController!.isHost = isHost!
        arViewController!.displayName = displayName
        arViewController!.peerID = peerID
        arViewController!.mcSession = mcSession
        arViewController!.modalPresentationStyle = .fullScreen
        present(arViewController!, animated: true, completion: nil)
    }
}

extension MCDiscoverViewController: MCBrowserViewControllerDelegate {
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {

        // notify all players to start game
        try? mcSession?.send("StartGame".data(using: .utf8)!, toPeers: mcSession!.connectedPeers, with: .reliable)
        dismiss(animated: true, completion: nil)
        DispatchQueue.main.async { [self] in
            transitToARViewController()
        }
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        
        // disconnect from the session as host quit
        mcSession?.disconnect()
        dismiss(animated: true, completion: nil)
    }

}


extension MCDiscoverViewController: MCSessionDelegate {

    // reflect changes in player group
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        updateTextView()
    }

    // receive the start game instruction and proceed to game
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if String(decoding: data, as: UTF8.self) == "StartGame" {
            DispatchQueue.main.async { [self] in
                dismiss(animated: true, completion: nil)
                transitToARViewController()
            }
        }
    }
    
    // below functions is not used, added to satisfy protocol requirement
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}


