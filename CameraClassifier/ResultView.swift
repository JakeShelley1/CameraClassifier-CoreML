//
//  ResultView.swift
//  CameraClassifier
//
//  Created by Jake Shelley on 6/13/17.
//  Copyright © 2017 Jake Shelley. All rights reserved.
//

import UIKit
import Vision

class ResultView: UIView {
    
    @IBOutlet weak var resultImage: UIImageView!
    @IBOutlet weak var confidenceLabel: UILabel!
    @IBOutlet weak var resultLabel: UILabel!
    
    var predictions = [VNClassificationObservation]()
    var index = -1
    weak var delegate: ResultViewDelegate?
    
    // When the view enters the superview set the intital confidence/prediction labels
    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        // willMove(_:) is called when view removes from superview, so this check is necessary to ensure
        // index won't go out of bounds
        if (index >= predictions.count) {
            return
        }
        
        cycleToNextPrediction()
    }
    
    // Cycle to the next prediction
    func cycleToNextPrediction() {
        index += 1
        if (index >= predictions.count) {
            closeView()
            return
        }
        
        let confidence = Int(predictions[index].confidence*100)
        confidenceLabel.text = String(describing: confidence) + "%"
        resultLabel.text = predictions[index].identifier
    }
    
    // Close the view
    func closeView() {
        delegate?.setupCamera()
        removeFromSuperview()
    }
    
    @IBAction func wrongButtonPressed(_ sender: Any) {
        cycleToNextPrediction()
    }
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        closeView()
    }
    
}

