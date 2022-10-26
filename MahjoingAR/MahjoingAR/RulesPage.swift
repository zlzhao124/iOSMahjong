//
//  RulesPage.swift
//  MahjoingAR
//
//  Created by Xuyan Qin on 11/22/20.
//  Copyright © 2020 438MahjongGroup. All rights reserved.
//

import UIKit

class RulesPage: UIViewController {

    //Below is the IBOutlet
    @IBOutlet weak var backButton: UIButton!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    //This function is the back button pressed function. It should send you to the previous page before you hit rules button.
    @IBAction func backButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    


}
