import Vision
import AVFoundation
import UIKit

extension ViewController {
    
    func setupDetector() {
        let modelURL = Bundle.main.url(forResource: "YOLOv3TinyInt8LUT", withExtension: "mlmodelc")
    
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL!))
            let recognitions = VNCoreMLRequest(model: visionModel, completionHandler: detectionDidComplete)
            self.requests = [recognitions]
        } catch let error {
            print(error)
        }
    }
    
    func detectionDidComplete(request: VNRequest, error: Error?) {
        DispatchQueue.main.async(execute: {
            if let results = request.results {
                self.extractDetections(results)
            }
        })
    }
    
    func extractDetections(_ results: [VNObservation]) {
        detectionLayer.sublayers = nil
        
        // Define the user's path as a rectangle in the center of the screen
        let pathRect = CGRect(x: screenRect.width/4, y: screenRect.height/4, width: screenRect.width/2, height: screenRect.height/2)
        
        // Check if any detected objects intersect with the user's path
        var intersectingObjects = [VNRecognizedObjectObservation]()
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else { continue }
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
            
            if pathRect.intersects(objectBounds) {
                intersectingObjects.append(objectObservation)
            }
        }
        
        if intersectingObjects.count > 0 {
            // Play a sound to alert the user
            let systemSoundID: SystemSoundID = 1057
            AudioServicesPlaySystemSound(systemSoundID)
            
            // Get the direction that the user should move in to avoid the obstacle
            let intersectingBounds = intersectingObjects.map { VNImageRectForNormalizedRect($0.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height)) }
            
            // Calculate the average position of intersecting objects
            var averageXPosition: CGFloat = 0.0
            for bound in intersectingBounds {
                averageXPosition += (bound.minX + bound.maxX) / 2
            }
            averageXPosition /= CGFloat(intersectingBounds.count)
            
            var directionArrow: UIImage?
            var directionText: String?
            if averageXPosition > pathRect.midX {
                directionArrow = UIImage(systemName: "arrowtriangle.right.fill")
                directionText = "Turn right"
            } else if averageXPosition < pathRect.midX {
                directionArrow = UIImage(systemName: "arrowtriangle.left.fill")
                directionText = "Turn left"
            }
            
            if let directionArrow = directionArrow, let directionText = directionText {
                // Display a direction arrow and text to the user
                let arrowLayer = CALayer()
                arrowLayer.contents = directionArrow.cgImage
                arrowLayer.frame = CGRect(x: screenRect.width/2 - 50, y: screenRect.height - 150, width: 100, height: 100)
                detectionLayer.addSublayer(arrowLayer)
                
                let labelLayer = CATextLayer()
                labelLayer.string = directionText
                labelLayer.fontSize = 24
                labelLayer.foregroundColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                labelLayer.backgroundColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
                labelLayer.cornerRadius = 4
                labelLayer.alignmentMode = .center
                labelLayer.frame = CGRect(x: screenRect.width/2 - 100, y: screenRect.height - 100, width: 200, height: 50)
                detectionLayer.addSublayer(labelLayer)
            }
        }
        
        // Draw bounding boxes for all detected objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else { continue }
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
            
            let boxLayer = self.drawBoundingBox(objectBounds)
            
            // Display the name of the detected object
            let labelLayer = self.drawLabel(objectObservation.labels[0].identifier, frame: objectBounds)
            detectionLayer.addSublayer(labelLayer)
            
            detectionLayer.addSublayer(boxLayer)
        }
    }

    func drawLabel(_ labelText: String, frame: CGRect) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = labelText
        textLayer.fontSize = 16
        textLayer.foregroundColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        textLayer.backgroundColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
        textLayer.cornerRadius = 4
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: frame.origin.x, y: frame.origin.y - 20, width: frame.size.width, height: 20)
        return textLayer
    }
    
    func setupLayers() {
        detectionLayer = CALayer()
        detectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        self.view.layer.addSublayer(detectionLayer)
    }
    
    func updateLayers() {
        detectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
    }
    
    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
        let boxLayer = CALayer()
        boxLayer.frame = bounds
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = CGColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        boxLayer.cornerRadius = 4
        return boxLayer
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:]) // Create handler to perform request on the buffer

        do {
            try imageRequestHandler.perform(self.requests) // Schedules vision requests to be performed
        } catch {
            print(error)
        }
    }
}
