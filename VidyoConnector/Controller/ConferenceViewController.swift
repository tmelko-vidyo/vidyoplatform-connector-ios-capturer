//
//  ConferenceViewController.swift
//  VidyoConnector
//
//  Created by taras.melko on 01.03.2021.
//

import UIKit

class ConferenceViewController: UIViewController {
    
    @IBOutlet var videoView: UIView!
    
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var microphoneButton: UIButton!
    
    @IBOutlet weak var libVersion: UILabel!
    @IBOutlet weak var progress: UIActivityIndicatorView!

    @IBOutlet weak var localView: UIView!

    public var connectParams: ConnectParams?
    
    private var connector: VCConnector?
    
    struct CallState {
        var hasDevicesSelected = true
        var cameraMuted = false
        var micMuted = false
        
        var connected = false
        var disconnectingWithQuit = false
    }
    
    var callState = CallState()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        connector = VCConnector(&videoView,
                                viewStyle: .default,
                                remoteParticipants: 8,
                                logFileFilter: "warning debug@VidyoClient debug@VidyoConnector".cString(using: .utf8),
                                logFileName: "".cString(using: .utf8),
                                userData: 0)
        
        // Orientation change observer
        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationChanged),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
        
        // Foreground mode observer
        NotificationCenter.default.addObserver(self, selector: #selector(onForeground),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        
        // Background mode observer
        NotificationCenter.default.addObserver(self, selector: #selector(onBackground),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        
        libVersion.text = "Version: \(connector!.getVersion()!)"
        
        progress.isHidden = true
        progress.startAnimating()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshUI()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        connector?.select(nil as VCLocalCamera?)
        connector?.select(nil as VCLocalMicrophone?)
        connector?.select(nil as VCLocalSpeaker?)
        
        connector?.hideView(&videoView)
        connector?.disable()
        
        connector = nil
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func onForeground() {
        guard let connector = connector else {
            return
        }
        
        connector.setMode(.foreground)
        
        if !callState.hasDevicesSelected {
            callState.hasDevicesSelected = true
            
            connector.selectDefaultCamera()
            connector.selectDefaultMicrophone()
            connector.selectDefaultSpeaker()
        }
        
        connector.setCameraPrivacy(callState.cameraMuted)
    }
    
    @objc func onBackground() {
        guard let connector = connector else {
            return
        }
        
        if isInCallingState() {
            connector.setCameraPrivacy(true)
        } else {
            callState.hasDevicesSelected = false
            
            connector.select(nil as VCLocalCamera?)
            connector.select(nil as VCLocalMicrophone?)
            connector.select(nil as VCLocalSpeaker?)
        }
        
        connector.setMode(.background)
    }
    
    @objc func onOrientationChanged() {
        self.refreshUI();
    }
    
    @IBAction func onConferenceCall(_ sender: Any) {
        if callState.connected {
            disconnectConference()
        } else {
            connectConference()
        }
    }
    
    @IBAction func onCameraStateChanged(_ sender: Any) {
        callState.cameraMuted = !callState.cameraMuted
        updateCallState()
        
        connector?.setCameraPrivacy(callState.cameraMuted)
    }

    @IBAction func onMicStateChanged(_ sender: Any) {
        callState.micMuted = !callState.micMuted
        updateCallState()
        
        connector?.setMicrophonePrivacy(callState.micMuted)
    }
    
    @IBAction func closeConference(_ sender: Any) {
        if isInCallingState() {
            progress.isHidden = false
            callState.disconnectingWithQuit = true
            disconnectConference()
            return
        }
        
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - IConnect delegate methods

extension ConferenceViewController: VCConnectorIConnect {
    
    func onSuccess() {
        print("Connection Successful.")
        
        DispatchQueue.main.async {
            [weak self] in
            guard let this = self else { fatalError("Can't maintain self reference.") }
            
            this.progress.isHidden = true
            this.updateCallState()
            
            this.libVersion.text = "Connected."
        }
    }
    
    func onFailure(_ reason: VCConnectorFailReason) {
        print("Connection failed \(reason)")
        
        DispatchQueue.main.async {
            [weak self] in
            guard let this = self else { fatalError("Can't maintain self reference.") }
            
            this.progress.isHidden = true
            this.callState.connected = false

            this.updateCallState()
            
            this.libVersion.text = "Error: \(reason)"
        }
    }
    
    func onDisconnected(_ reason: VCConnectorDisconnectReason) {
        print("Call Disconnected")
        
        DispatchQueue.main.async {
            [weak self] in
            guard let this = self else { fatalError("Can't maintain self reference.") }
            
            this.progress.isHidden = true
            this.callState.connected = false
            
            this.updateCallState()
            
            this.libVersion.text = "Disconnected: \(reason)"
            
            /* Force quit */
            if this.callState.disconnectingWithQuit { this.dismiss(animated: true, completion: nil) }
        }
    }
}

// MARK: Private

extension ConferenceViewController {
    
    private func connectConference() {
        progress.isHidden = false

        callState.connected = true
        updateCallState()
        
        connector?.connectToRoom(asGuest: connectParams?.portal,
                                 displayName: connectParams?.displayName,
                                 roomKey: connectParams?.roomKey,
                                 roomPin: connectParams?.pin,
                                 connectorIConnect: self)
    }
    
    private func disconnectConference() {
        progress.isHidden = false
        
        connector?.disconnect()
    }
    
    private func updateCallState() {
        self.cameraButton.setImage(UIImage(named: callState.cameraMuted ? "cameraOff": "cameraOn"), for: .normal)
        self.callButton.setImage(UIImage(named: callState.connected ? "callEnd": "callStart"), for: .normal)
        self.microphoneButton.setImage(UIImage(named: callState.micMuted ? "microphoneOff": "microphoneOn"), for: .normal)
    }
    
    private func refreshUI() {
        DispatchQueue.main.async {
            [weak self] in
            guard let this = self else { return }
            
            this.connector?.showView(at: &this.videoView,
                                     x: 0,
                                     y: 0,
                                     width: UInt32(this.videoView.frame.size.width),
                                     height: UInt32(this.videoView.frame.size.height))
        }
    }
    
    private func isInCallingState() -> Bool {
        if let connector = connector {
            let state = connector.getState()
            return state != .idle && state != .ready
        }
        
        return false
    }
}
