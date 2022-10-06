//
//  FrameManager.swift
//  VidyoConnector
//
//  Created by Taras Melko on 09.11.2021.
//

import Foundation
import UIKit
import VideoToolbox

@objc class FrameManager: NSObject {
    
    private var renderer: UIImageView?
    private var connector: VCConnector?
    
    private let width = 320
    private let height = 480
    
    private var localCamera: VCLocalCamera?
    
    init(connector: VCConnector?, renderer: UIImageView) {
        super.init()
        connector?.select(nil as VCLocalCamera?)
        self.connector = connector
        self.renderer = renderer
    }
    
    public func start() {
        if (connector?.registerLocalCameraEventListener(self) ?? false) {
            print("FrameManager: local camera registered")
        } else {
            print("FrameManager: local camera failed")
        }

    }
}


extension FrameManager: VCConnectorIRegisterLocalCameraEventListener {
    func onLocalCameraAdded(_ localCamera: VCLocalCamera!) {
        if (localCamera.getPosition() == VCLocalCameraPosition.front) {
            connector?.select(localCamera)
        }
    }
    
    func onLocalCameraRemoved(_ localCamera: VCLocalCamera!) {
        connector?.unregisterLocalCameraFrameListener(localCamera)
    }
    
    func onLocalCameraSelected(_ localCamera: VCLocalCamera!) {
        guard let localCamera = localCamera else { return }
      
        if (self.localCamera != nil) { return }
            
        self.localCamera = localCamera
        
        print("FrameManager: local camera selected \(self.localCamera!.name)")
        
        if (connector?.registerLocalCameraFrameListener(self, localCamera: self.localCamera!,
                                                    width: UInt32(width),
                                                    height: UInt32(height),
                                                        frameInterval: 0) ?? false) {
            print("FrameManager: success")
        }
    }
    
    func onLocalCameraStateUpdated(_ localCamera: VCLocalCamera!, state: VCDeviceState) {
        
    }
}

extension FrameManager: VCConnectorIRegisterLocalCameraFrameListener {
    
    func onLocalCameraFrame(_ localCamera: VCLocalCamera!, videoFrame: VCVideoFrame!) {
        print("FrameManager: local camera frame received: \(videoFrame.getSize())")
    }
}

extension UIImage {
    /**
     Creates a new UIImage from a CVPixelBuffer.
     NOTE: This only works for RGB pixel buffers, not for grayscale.
     */
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        
        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
    
    /**
     Creates a new UIImage from a CVPixelBuffer, using Core Image.
     */
    public convenience init?(pixelBuffer: CVPixelBuffer, context: CIContext) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer),
                          height: CVPixelBufferGetHeight(pixelBuffer))
        if let cgImage = context.createCGImage(ciImage, from: rect) {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}

