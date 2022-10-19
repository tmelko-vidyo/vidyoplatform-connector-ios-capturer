//
//  CaptureManager.swift
//  VidyoConnector
//
//  Created by taras.melko on 01.03.2021.
//

import Foundation
import UIKit
import AVFoundation

protocol ICaptureManagerState {
    func onStateChanged(capturing: Bool)
}

@objc class CaptureManager: NSObject {
    
    private let position = AVCaptureDevice.Position.front
    private let quality = AVCaptureSession.Preset.medium
    
    private let sessionQueue = DispatchQueue(label: "SessionQueue")
    private let captureSession = AVCaptureSession()

    private var captureDeviceInput: AVCaptureDeviceInput?
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let bufferQueue = DispatchQueue(label: "BufferQueue")
    
    private var captureEnabled = false
    
    private var connector: VCConnector?
    private var activeVirtualSource: VCVirtualVideoSource?
    
    private var listener: ICaptureManagerState?
    
    init(connector: VCConnector?, listener: ICaptureManagerState?) {
        self.listener = listener
        self.connector = connector
        super.init()
                
        sessionQueue.async { [unowned self] in self.configureSession() }
        
        connector?.select(nil as VCLocalCamera?)
        connector?.registerVirtualVideoSourceEventListener(self)
    }
    
    public func startCapturer() {
        if (captureEnabled) { return }
        
        if (self.activeVirtualSource == nil) {
            print("CaptureManager: create vitrual source")
            connector?.createVirtualVideoSource(.CAMERA, id: "VirtualCamera#100", name: "VCX")
        } else {
            connector?.selectVirtualCamera(activeVirtualSource)
            print("CaptureManager: select vitrual source")
        }
    }
    
    public func stopCapturer() {
        if (!captureEnabled) { return }
        
        stopSession()
        self.connector?.selectVirtualCamera(nil)
    }
    
    public func isCapturing() -> Bool {
        return captureEnabled
    }
    
    public func destroy() {
        stopCapturer()
        
        if let input = self.captureDeviceInput {
            captureSession.removeInput(input)
        }
        
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        captureSession.removeOutput(videoOutput)

        connector?.unregisterVirtualVideoSourceEventListener()
        
        print("CaptureManager: destroy manager.")
    }
}

// MARK: Vitrual Video Source Listener

extension CaptureManager: VCConnectorIRegisterVirtualVideoSourceEventListener {
    
    func onVirtualVideoSourceAdded(_ virtualVideoSource: VCVirtualVideoSource!) {
        switch virtualVideoSource.type {
        case .CAMERA:
            self.activeVirtualSource = virtualVideoSource;
            let selected = self.connector?.selectVirtualCamera(virtualVideoSource)
            
            print("CaptureManager: Virtual source created and selected: \(String(describing: selected)). ID: \(virtualVideoSource.id ?? "None")")
        default:
            break
        }
    }
    
    func onVirtualVideoSourceRemoved(_ virtualVideoSource: VCVirtualVideoSource!) {
        switch virtualVideoSource.type {
        case .CAMERA:
            print("CaptureManager: Virtual source removed. ID: \(virtualVideoSource.id ?? "None")")
        default:
            break
        }
    }
    
    func onVirtualVideoSourceStateUpdated(_ virtualVideoSource: VCVirtualVideoSource!, state: VCDeviceState) {
        switch state {
        case .started:
            print("CaptureManager: Virtual source started. Start session feed. ID: \(String(describing: virtualVideoSource.id))")
            startSession()
            captureEnabled = true
            self.listener?.onStateChanged(capturing: true)
            break
        case .stopped:
            print("CaptureManager: Virtual source stopped. Stop session feed. ID: \(String(describing: virtualVideoSource.id))")
            stopSession()
            captureEnabled = false
            self.listener?.onStateChanged(capturing: false)
            break
        default:
            print("CaptureManager: Virtual source state updated: \(state)")
            break
        }
    }
    
    func onVirtualVideoSourceExternalMediaBufferReleased(_ virtualVideoSource: VCVirtualVideoSource!, buffer: UnsafeMutablePointer<UInt8>!, size: Int) {
    }
}

// MARK: Video capturer callback

extension CaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !captureEnabled {
            print("Capturer has been disabled.")
            return
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error: can't extract image buffer")
            return
        }
        
        send(imageBuffer)
    }
}

// MARK: Frame release buffer manager

extension CaptureManager: VCVideoFrameIConstructFromKnownFormatWithExternalBuffer {
    
    func releaseCallback(_ buffer: UnsafeMutableRawPointer!, size: Int) {
        free(buffer)
    }
}

// MARK: Private API

extension CaptureManager {
    private func startSession() {
        sessionQueue.async { [unowned self] in
            self.captureSession.startRunning()
        }
    }
    
    private func stopSession() {
        sessionQueue.async { [unowned self] in
            self.captureSession.stopRunning()
        }
    }

    private func configureSession() {
        captureSession.sessionPreset = quality
        
        guard let captureDevice = selectCaptureDevice() else {
            print("Error: can't get capture device")
            return
        }
        
        self.captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice)
        guard let input = self.captureDeviceInput else {
            print("Error: construct input")
            return
        }
        
        guard captureSession.canAddInput(input) else {
            print("Error: can't add input")
            return
        }
        captureSession.addInput(input)
        
        videoOutput.setSampleBufferDelegate(self, queue: bufferQueue)
        
        guard captureSession.canAddOutput(videoOutput) else {
            print("Error: can't add output")
            return
        }
        captureSession.addOutput(videoOutput)
        
        guard let connection = videoOutput.connection(with: .video) else {
            print("Error: can't establish connection")
            return
        }
        
        guard connection.isVideoOrientationSupported else { return }
        guard connection.isVideoMirroringSupported else { return }
        
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = position == .front
        
        print("CaptureManager: Session has been configured.")
    }
    
    private func selectCaptureDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.devices().filter {
            ($0 as AnyObject).hasMediaType(.video) && ($0 as AnyObject).position == position
        }.first
    }
    
    private func send(_ pixelBuffer: CVImageBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let finalSize = (CVPixelBufferGetHeightOfPlane(pixelBuffer, 1) * CVPixelBufferGetWidthOfPlane(pixelBuffer, 1) * 2) + (CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) * CVPixelBufferGetWidthOfPlane(pixelBuffer, 0))
        let finalBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: finalSize)
        var bufferPointee = finalBuffer
        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        for i in 0..<planeCount {
            let planeBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i)!
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i)
            let planeWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, i)
            let planeHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, i)
            let bytesToCopy = planeWidth * (i + 1)
            for j in 0..<planeHeight {
                let planeBufferDeviation = bytesPerRow * j
                memcpy(bufferPointee, planeBuffer + planeBufferDeviation, bytesToCopy)
                bufferPointee = bufferPointee + bytesToCopy
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        guard let frame = VCVideoFrame(.format420f,
                                       buffer: finalBuffer,
                                       size: UInt32(finalSize),
                                       videoFrameIConstructFromKnownFormatWithExternalBuffer: self,
                                       width: UInt32(CVPixelBufferGetWidth(pixelBuffer)),
                                       height: UInt32( CVPixelBufferGetHeight(pixelBuffer))) else {
            print("Error: frame initialization failed")
            return
        }
        
        self.activeVirtualSource?.onFrame(frame, mediaFormat: .format420f)
    }
}
