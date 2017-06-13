//
//  ViewController.swift
//  CameraClassifier
//
//  Created by Jake Shelley on 6/13/17.
//  Copyright © 2017 Jake Shelley. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

protocol ResultViewDelegate: class {
    func setupCamera()
}

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, ResultViewDelegate {
    
    @IBOutlet weak var captureButton: UIButton!
    
    let captureSession = AVCaptureSession()
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    var captureDevice: AVCaptureDevice!
    var resultView: ResultView!
    var takePhoto = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.statusBarStyle = .lightContent
        setupCamera()
        setupCaptureButton()
    }
    
    // Setup the ResultView and add it to the ViewController
    func setupResultView(with image: UIImage) {
        resultView = UINib(nibName: "ResultView", bundle: nil).instantiate(withOwner: self, options: nil).first as! ResultView
        resultView.frame = self.view.frame
        resultView.resultImage.image = image
        resultView.delegate = self
        
        makePrediction(image)
        
        view.addSubview(resultView)
    }
    
    // Setup the Camera and begin the session
    func setupCamera() {
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        captureDevice = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .back).devices.first
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureDeviceInput)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.frame = view.layer.frame
        view.layer.addSublayer(previewLayer)
        view.bringSubview(toFront: captureButton)
        
        captureSession.startRunning()
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String):NSNumber(value:kCVPixelFormatType_32BGRA)]
        output.alwaysDiscardsLateVideoFrames = true
        
        if (captureSession.canAddOutput(output)) {
            captureSession.addOutput(output)
        }
        
        captureSession.commitConfiguration()
        
        let queue = DispatchQueue(label: "captureQueue")
        output.setSampleBufferDelegate(self, queue: queue)
    }
    
    // Setup the Capture Button
    func setupCaptureButton() {
        captureButton.backgroundColor = .red
        captureButton.layer.cornerRadius = captureButton.frame.width/2
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.layer.borderWidth = 5
    }
    
    // Capture a frame from the camera
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if takePhoto {
            takePhoto = false
            guard let image = getImageFromSampleBuffer(buffer: sampleBuffer) else {
                return
            }
            
            DispatchQueue.main.async {
                self.setupResultView(with: image)
                self.stopCaptureSession()
            }
        }
    }
    
    // Turn the video frame into an image
    func getImageFromSampleBuffer (buffer:CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            if let image = context.createCGImage(ciImage, from: imageRect) {
                return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .right)
            }
            
        }
        
        return nil
    }
    
    // Send an image to the model and send the predictions to the ResultView
    func makePrediction(_ image: UIImage) {
        guard let model = try? VNCoreMLModel(for: GoogLeNetPlaces().model) else {
            fatalError("Could not load CoreML model")
        }
        
        let scaledImage = resizeImage(image: image, newSize: CGSize(width: 224, height: 224))
        let request = VNCoreMLRequest(model: model, completionHandler: {[weak self] (request: VNRequest, error: Error?) in
            if (error != nil) {
                fatalError(error!.localizedDescription)
            }
            
            if let results = request.results as? [VNClassificationObservation] {
                self?.resultView.predictions = results
                return
            }
            
            fatalError("Could not load results")
        })
        
        let handler = VNImageRequestHandler(cgImage: scaledImage.cgImage!, options: [:])
        
        guard (try? handler.perform([request])) != nil else {
            fatalError("request failed")
        }
    }
    
    // Stop the camera from running
    func stopCaptureSession () {
        captureSession.stopRunning()
        
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.captureSession.removeInput(input)
            }
        }
    }
    
    // https://stackoverflow.com/questions/6141298/how-to-scale-down-a-uiimage-and-make-it-crispy-sharp-at-the-same-time-instead
    func resizeImage(image: UIImage, newSize: CGSize) -> (UIImage) {
        
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        let imageRef = image.cgImage
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        let context = UIGraphicsGetCurrentContext()
        
        // Set the quality level to use when rescaling
        context!.interpolationQuality = .high
        let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
        
        context!.concatenate(flipVertical)
        // Draw into the context; this scales the image
        context!.draw(imageRef!, in: newRect)
        
        let newImageRef = context!.makeImage()
        let newImage = UIImage(cgImage: newImageRef!)
        
        // Get the resized image from the context and a UIImage
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    // Will trigger the video to capture the current frame
    @IBAction func captureImage(_ sender: Any) {
        takePhoto = true
    }
    
}


