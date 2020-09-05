//
//  FaceViewController.swift
//  Vouched_Example
//
//  Created by David Woo on 7/27/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import AVFoundation
import Vouched
import Vision

class FaceViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var instructionLabel: UILabel!
    
    var device: AVCaptureDevice?
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var cameraImage: UIImage?
    var cardDetect = CardDetect()
    var faceDetect = FaceDetect(config: FaceDetectConfig(liveness: .mouthMovement))
    var count: Int = 0
    var id:String = ""
    var firstCalled:Bool = true
    var session: VouchedSession?
    var job: Job?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isHidden = false
        self.navigationItem.title = "Place Camera On Face"
        
        nextButton.isHidden = true
        loadingIndicator.isHidden = true
        
        setupCamera()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /**
     This method sets up the Camera device details
     */
    func setupCamera() {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                mediaType: AVMediaType.video,
                                                                position: .front)
        
        if  discoverySession.devices.count == 0 {
            return
        }
        device = discoverySession.devices[0]
        
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device!)
        } catch {
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        
        let queue = DispatchQueue(label: "cameraQueue")
        output.setSampleBufferDelegate(self, queue: queue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String: kCVPixelFormatType_32BGRA]
        
        startCapture(input:input, output:output)
    }
    
    /**
     This method sets up captureSession and starts session with previewLayer
     */
    func startCapture(input: AVCaptureDeviceInput, output: AVCaptureVideoDataOutput){
        captureSession = AVCaptureSession()
        captureSession?.addInput(input)
        captureSession?.addOutput(output)
        captureSession?.sessionPreset = AVCaptureSession.Preset.photo
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.frame = CGRect(x: 0.0, y: 0.0, width: view.frame.width, height: view.frame.height)
        
        self.cameraView?.layer.insertSublayer(previewLayer!, at: 0)
        
        captureSession?.startRunning()
    }
    func loadingShow(){
        DispatchQueue.main.async() {
            self.loadingIndicator.isHidden = false

        }
    }
    func buttonShow(){
        DispatchQueue.main.async() { // Correct
            self.nextButton.isHidden = false
            self.loadingIndicator.isHidden = true
        }
    }
    
    func updateLabel(_ instruction:Instruction) {
        var str: String
        switch instruction {
        case .closeMouth:
            str = "Close Mouth"
        case .openMouth:
            str = "Open Mouth"
        case .moveCloser:
            str = "Come Closer to Camera"
        case .holdSteady:
            str = "Hold Steady"
        case .lookForward:
            str = "Look Forward"
        case .onlyOne:
            str = "Multiple Faces"
        default:
            str = "Look Forward"
        }
        DispatchQueue.main.async() {
            self.instructionLabel.text = str
        }
    }
    
    func updateLabel(_ retryableError: RetryableError) {
        var str: String

        switch retryableError {
        case .InvalidIdError:
            str = "Invalid ID"
        case .InvalidIdPhotoError:
            str = "Invalid Photo ID"
        case .InvalidUserPhotoError:
            str = "Invalid Selfie"
        case .ExpiredIdError:
            str = "Expired ID"
        case .PoorIdImageQuality:
            str = "Poor Image Quality"
        }
        
        DispatchQueue.main.async() {
            self.instructionLabel.text = str
        }
    }
    
    /**
     This method called from AVCaptureVideoDataOutputSampleBufferDelegate - passed in sampleBuffer
     */
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let detectedFace = self.faceDetect.detect(imageBuffer!)
        
        if let detectedFace = detectedFace {
            switch detectedFace.step {
            case .preDetected:
                DispatchQueue.main.async() {
                    self.instructionLabel.text = "Look into the Camera"
                }
            case .detected:
                self.updateLabel(detectedFace.instruction)
            case .postable:
                captureSession?.stopRunning()
                self.loadingShow()
                DispatchQueue.main.async() {
                    self.instructionLabel.text = "Processing Image"
                }
                do {
                    self.job = try session!.postFace(detectedFace: detectedFace)
                    let retryableErrors = VouchedUtils.extractRetryableErrors(self.job!)
                    // if there are retryable errors, update label and retry card detection
                    if !retryableErrors.isEmpty {
                        self.updateLabel(retryableErrors.first!)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.captureSession?.startRunning()
                        }
                        return;
                    }
                    self.buttonShow()
                } catch {
                    print("Error info: \(error)")
                }
            }
        } else {
            DispatchQueue.main.async() {
                self.instructionLabel.text = "Look into the Camera"
            }
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender:Any?) {
        if segue.identifier == "ToResultPage" {
            let destVC = segue.destination as! ResultsViewController
            destVC.job = self.job
            destVC.session = self.session
        }
    }

}
