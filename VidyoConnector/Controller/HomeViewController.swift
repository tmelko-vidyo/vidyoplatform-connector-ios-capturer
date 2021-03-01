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
    
    let testParams = ConnectParams(portal: "sandbox.vidyocloudstaging.com",
                                   roomKey: "CsUV4kkpdy",
                                   displayName: "Taras Mobile",
                                   pin: "")

    @IBOutlet weak var portal: UITextField!
    @IBOutlet weak var roomKey: UITextField!
    @IBOutlet weak var displayName: UITextField!
    @IBOutlet weak var pin: UITextField!
    
    @IBOutlet weak var startConference: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        VCConnectorPkg.vcInitialize()

        portal.text = testParams.portal
        roomKey.text = testParams.roomKey
        displayName.text = testParams.displayName
        pin.text = testParams.pin
        
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
