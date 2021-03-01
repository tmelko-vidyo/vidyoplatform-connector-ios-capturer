//
//  HomeViewController.swift
//  VidyoConnector
//
//  Created by taras.melko on 01.03.2021.
//

import UIKit

struct ConnectParams {
    let portal: String
    let roomKey: String
    let displayName: String
    let pin: String
}

class HomeViewController: UIViewController {
    
    let presetParams = ConnectParams(portal: "YOUR.PORTAL.com",
                                   roomKey: "YOUR.ROOM.KEY",
                                   displayName: "John Doe",
                                   pin: "")

    @IBOutlet weak var portal: UITextField!
    @IBOutlet weak var roomKey: UITextField!
    @IBOutlet weak var displayName: UITextField!
    @IBOutlet weak var pin: UITextField!
    
    @IBOutlet weak var startConference: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        VCConnectorPkg.vcInitialize()

        portal.text = presetParams.portal
        roomKey.text = presetParams.roomKey
        displayName.text = presetParams.displayName
        pin.text = presetParams.pin
        
        startConference.layer.cornerRadius = 12
    }
    
    @IBAction func onConferenceRequested(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let conference = storyboard.instantiateViewController(withIdentifier: "Conference") as! ConferenceViewController
        conference.isModalInPresentation = true
        
        conference.connectParams = ConnectParams(portal: self.portal.text!,
                                                 roomKey: self.roomKey.text!,
                                                 displayName: self.displayName.text!,
                                                 pin: self.pin.text!)
        
        self.present(conference, animated: true)
    }
}
