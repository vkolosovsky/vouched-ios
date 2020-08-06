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
        var discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
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
            print(self.loadingIndicator.isHidden)
            self.loadingIndicator.isHidden = false

        }
    }
    func buttonShow(){
        DispatchQueue.main.async() { // Correct
            print(self.nextButton.isHidden)
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
        default:
            str = "Look Forward"
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
                print("waiting for the face...")
            case .detected:
                print("instruction: \(detectedFace.instruction)")
                self.updateLabel(detectedFace.instruction)
            case .postable:
                print("posting")
                captureSession?.stopRunning()
                self.loadingShow()
                
                do {
                    self.job = try session!.postFace(detectedFace: detectedFace)
                    self.buttonShow()
                    print("Job Post Success: " + self.job!.id)
                } catch {
                    print("Error info: \(error)")
                }
            }
        } else {
            print("no face...")
        }
        
    }
    
    @IBAction func nextButtonPressed(_ sender: Any) {
//        self.cameraView.isHidden = true
//        self.loadingIndicator.isHidden = false
    }

    override func prepare(for segue: UIStoryboardSegue, sender:Any?) {
        if segue.identifier == "ToResultPage" {
            let destVC = segue.destination as! ResultsViewController
            destVC.job = self.job
            destVC.session = self.session
        }
    }

}