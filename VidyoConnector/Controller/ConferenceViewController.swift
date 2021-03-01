//
//  ConferenceViewController.swift
//  VidyoConnector
//
//  Created by taras.melko on 01.03.2021.
//

import UIKit

class ConferenceViewController: UIViewController {
    
    @IBOutlet var videoView: UIView!
        
    public var connectParams: ConnectParams?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    @IBAction func closeConference(_ sender: Any) {
        
        dismiss(animated: true) {
            
        }
    }
}
