//
//  IdViewControllerV2.swift
//  Vouched
//
//  Copyright © 2021 Vouched.id. All rights reserved.
//

import UIKit
import TensorFlowLite
import VouchedCore
import VouchedBarcode
import MLKitBarcodeScanning

class IdViewControllerV2: UIViewController {
    @IBOutlet private weak var previewContainer: UIView!
    @IBOutlet private weak var nextButton: UIButton!
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var instructionLabel: UILabel!

    var inputFirstName: String = ""
    var inputLastName: String = ""
    var onBarcodeStep = false
    var includeBarcode = false

    private var helper: VouchedCameraHelper?
    private let session: VouchedSession = VouchedSession(apiKey: getValue(key:"API_KEY"), sessionParameters: VouchedSessionParameters())

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.isHidden = false
        self.navigationItem.title = "Place Camera On ID"
        nextButton.isHidden = true
        loadingIndicator.isHidden = true
        instructionLabel.text = nil

        configureHelper(.id)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        helper?.startCapture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        helper?.stopCapture()
    }

    override func prepare(for segue: UIStoryboardSegue, sender:Any?){
        if segue.identifier == "ToFaceDetect"{
            let destVC = segue.destination as! FaceViewController
            destVC.session = self.session
        }
    }

    func configureHelper(_ mode: VouchedCameraMode) {
        helper = VouchedCameraHelper(with: .id, detectionOptions: [.cardDetect(CardDetectOptionsBuilder().withEnableDistanceCheck(false).build())], in: previewContainer)?.withCapture(delegate: { self.handleResult($0) })
    }
    
    func handleResult(_ result: VouchedCore.CaptureResult) {
        switch result {
        case .empty:
            DispatchQueue.main.async() {
                self.instructionLabel.text = self.onBarcodeStep ? "Focus camera on barcode" : "Show ID Card"
            }
        case .id(let result):
            guard let result = result as? CardDetectResult else { return }
            switch result.step {
            case .preDetected:
                DispatchQueue.main.async() {
                    self.instructionLabel.text = "Show ID Card"
                }
            case .detected:
                self.updateLabel(result.instruction)
            case .postable:
                helper?.stopCapture()
                self.loadingToggle()
                DispatchQueue.main.async() {
                    self.instructionLabel.text = "Processing Image"
                }
                do {
                    let job: Job
                    if inputFirstName.isEmpty && inputLastName.isEmpty {
                        job = try session.postFrontId(detectedCard: result)
                    } else {
                        let details = Params(firstName: inputFirstName, lastName: inputLastName)
                        job = try session.postFrontId(detectedCard: result, details: details)
                    }
                    print(job)

                    // if there are job insights, update label and retry card detection
                    let insights = VouchedUtils.extractInsights(job)
                    if !insights.isEmpty {
                        self.updateLabel(insights.first!)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.helper?.resetDetection()
                            self.loadingToggle()
                            self.helper?.startCapture()
                        }
                        return
                    }
                    if includeBarcode {
                        onBarcodeStep = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.loadingToggle()
                            self.configureHelper(.barcode(BarcodeDetect.defaultIdentifier, BarcodeScannerOptions(formats: [.PDF417])))
                            self.helper?.startCapture()
                        }
                    } else {
                        self.buttonShow()
                    }
                } catch {
                    print("Error FrontId: \(error.localizedDescription)")
                }
            }
        case .selfie(_):
            break
        case .barcode(let result):
            helper?.stopCapture()
            self.loadingToggle()
            DispatchQueue.main.async() {
                self.instructionLabel.text = "Processing"
            }
            
            do {
                let job = try session.postBackId(detectedBarcode: result)
                print(job)
                
                // if there are job insights, update label and retry card detection
                let insights = VouchedUtils.extractInsights(job)
                if !insights.isEmpty {
                    self.updateLabel(insights.first!)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.loadingToggle()
                        self.helper?.startCapture()
                    }
                    return
                }
                self.buttonShow()
            } catch {
                print("Error Barcode: \(error.localizedDescription)")
            }
        }
    }
    
    func updateLabel(_ instruction: Instruction) {
        var str: String
        switch instruction {
        case .moveCloser:
            str = "Move Closer"
        case .moveAway:
            str = "Move Away"
        case .holdSteady:
            str = "Hold Steady"
        case .onlyOne:
            str = "Multiple IDs"
        default:
            str = "Show ID"
        }
        DispatchQueue.main.async() {
            self.instructionLabel.text = str
        }
    }
        
    func updateLabel(_ insight: Insight) {
        var str: String

        switch insight {
        case .nonGlare:
            str = "image has glare"
        case .quality:
            str = "image is blurry"
        case .brightness:
            str = "image needs to be brighter"
        case .face:
            str = "image is missing required visual markers"
        case .glasses:
            str = "please take off your glasses"
        case .unknown:
            str = "No Error Message"
        }
        
        DispatchQueue.main.async() {
            self.instructionLabel.text = str
        }
    }

    func buttonShow() {
        DispatchQueue.main.async() { // Correct
            self.nextButton.isHidden = false
            self.loadingIndicator.isHidden = true

        }
    }

    func loadingToggle() {
        DispatchQueue.main.async() {
            self.loadingIndicator.isHidden = !self.loadingIndicator.isHidden
        }
    }
}
