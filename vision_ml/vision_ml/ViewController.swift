//
//  ViewController.swift
//  vision_ml
//
//  Created by Kun Lu on 8/31/18.
//  Copyright © 2018 Kun Lu. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
class ViewController: UIViewController {
	@IBOutlet weak var previewView: AVCaptureView!
	var helper = AVCaptureHelper()
	// Vision requests
	private var detectionRequests: [VNDetectFaceRectanglesRequest]?
	private var trackingRequests: [VNTrackObjectRequest]?

	lazy var sequenceRequestHandler = VNSequenceRequestHandler()

	var detectionOverlayLayer: CALayer?
	var detectedFaceRectangleShapeLayer: CAShapeLayer?
	var detectedFaceLandmarksShapeLayer: CAShapeLayer?

	var rootLayer: CALayer? {
		return self.previewView.layer
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		do {
			previewView.setup()

			previewView.previewLayer?.session = try helper.setupAVCaptureSession()

			helper.videoDataOutput?.setSampleBufferDelegate(self, queue: helper.videoDataOutputQueue)

			self.prepareVisionRequest()

			previewView.previewLayer?.session?.startRunning()

			return
		} catch let executionError as NSError {
			self.presentError(executionError)
		} catch {
			self.presentErrorAlert(message: "An unexpected failure has occured")
		}

		self.teardownAVCapture()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// Removes infrastructure for AVCapture as part of cleanup.
	fileprivate func teardownAVCapture() {
		self.helper.teardown()
		self.previewView.teardown()
	}

	fileprivate func prepareVisionRequest() {
		var requests = [VNTrackObjectRequest]()

		let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in

			if error != nil {
				print("FaceDetection error: \(String(describing: error)).")
			}

			guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
				let results = faceDetectionRequest.results as? [VNFaceObservation] else {
					return
			}
			DispatchQueue.main.async {
				// Add the observations to the tracking list
				for observation in results {
					let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
					requests.append(faceTrackingRequest)
				}
				self.trackingRequests = requests
			}
		})

		// Start with detection.  Find face, then track it.
		self.detectionRequests = [faceDetectionRequest]

		self.sequenceRequestHandler = VNSequenceRequestHandler()

		self.setupVisionDrawingLayers()
	}

	// MARK: Drawing Vision Observations
	fileprivate func setupVisionDrawingLayers() {
		let captureDeviceResolution = self.helper.captureDeviceResolution

		let captureDeviceBounds = CGRect(x: 0,
										 y: 0,
										 width: captureDeviceResolution.width,
										 height: captureDeviceResolution.height)

		let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX,
													 y: captureDeviceBounds.midY)

		let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)

		guard let rootLayer = self.rootLayer else {
			self.presentErrorAlert(message: "view was not property initialized")
			return
		}

		let overlayLayer = CALayer()
		overlayLayer.name = "DetectionOverlay"
		overlayLayer.masksToBounds = true
		overlayLayer.anchorPoint = normalizedCenterPoint
		overlayLayer.bounds = captureDeviceBounds
		overlayLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)

		let faceRectangleShapeLayer = CAShapeLayer()
		faceRectangleShapeLayer.name = "RectangleOutlineLayer"
		faceRectangleShapeLayer.bounds = captureDeviceBounds
		faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
		faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
		faceRectangleShapeLayer.fillColor = nil
		faceRectangleShapeLayer.strokeColor = UIColor.green.withAlphaComponent(0.7).cgColor
		faceRectangleShapeLayer.lineWidth = 5
		faceRectangleShapeLayer.shadowOpacity = 0.7
		faceRectangleShapeLayer.shadowRadius = 5

		let faceLandmarksShapeLayer = CAShapeLayer()
		faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
		faceLandmarksShapeLayer.bounds = captureDeviceBounds
		faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
		faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
		faceLandmarksShapeLayer.fillColor = nil
		faceLandmarksShapeLayer.strokeColor = UIColor.yellow.withAlphaComponent(0.7).cgColor
		faceLandmarksShapeLayer.lineWidth = 3
		faceLandmarksShapeLayer.shadowOpacity = 0.7
		faceLandmarksShapeLayer.shadowRadius = 5

		overlayLayer.addSublayer(faceRectangleShapeLayer)
		faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
		rootLayer.addSublayer(overlayLayer)

		self.detectionOverlayLayer = overlayLayer
		self.detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
		self.detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer

		self.updateLayerGeometry()
	}

	fileprivate func updateLayerGeometry() {
		guard let overlayLayer = self.detectionOverlayLayer,
			let rootLayer = self.rootLayer,
			let previewLayer = previewView.previewLayer
			else {
				return
		}

		let captureDeviceResolution = self.helper.captureDeviceResolution

		CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)

		let videoPreviewRect = previewLayer
			.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))

		var rotation: CGFloat
		var scaleX: CGFloat
		var scaleY: CGFloat

		// Rotate the layer into screen orientation.
		switch UIDevice.current.orientation {
		case .portraitUpsideDown:
			rotation = 180
			scaleX = videoPreviewRect.width / captureDeviceResolution.width
			scaleY = videoPreviewRect.height / captureDeviceResolution.height

		case .landscapeLeft:
			rotation = 90
			scaleX = videoPreviewRect.height / captureDeviceResolution.width
			scaleY = scaleX

		case .landscapeRight:
			rotation = -90
			scaleX = videoPreviewRect.height / captureDeviceResolution.width
			scaleY = scaleX

		default:
			rotation = 0
			scaleX = videoPreviewRect.width / captureDeviceResolution.width
			scaleY = videoPreviewRect.height / captureDeviceResolution.height
		}

		// Scale and mirror the image to ensure upright presentation.
		let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation))
			.scaledBy(x: scaleX, y: -scaleY)
		overlayLayer.setAffineTransform(affineTransform)

		// Cover entire screen UI.
		let rootLayerBounds = rootLayer.bounds
		overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
	}

	fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
		return CGFloat(Double(degrees) * Double.pi / 180.0)
	}
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
	public func captureOutput(_ output: AVCaptureOutput,
							  didOutput sampleBuffer: CMSampleBuffer,
							  from connection: AVCaptureConnection) {

		var requestHandlerOptions: [VNImageOption: AnyObject] = [:]

		let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil)
		if cameraIntrinsicData != nil {
			requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
		}

		guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			print("Failed to obtain a CVPixelBuffer for the current output frame.")
			return
		}

		let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()

		guard let requests = self.trackingRequests, !requests.isEmpty else {
			// No tracking object detected, so perform initial detection
			let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
															orientation: exifOrientation,
															options: requestHandlerOptions)

			do {
				guard let detectRequests = self.detectionRequests else {
					return
				}
				try imageRequestHandler.perform(detectRequests)
			} catch let error as NSError {
				NSLog("Failed to perform FaceRectangleRequest: %@", error)
			}
			return
		}

		do {
			try self.sequenceRequestHandler.perform(requests,
													on: pixelBuffer,
													orientation: exifOrientation)
		} catch let error as NSError {
			NSLog("Failed to perform SequenceRequest: %@", error)
		}

		// Setup the next round of tracking.
		var newTrackingRequests = [VNTrackObjectRequest]()
		for trackingRequest in requests {

			guard let results = trackingRequest.results else {
				return
			}

			guard let observation = results[0] as? VNDetectedObjectObservation else {
				return
			}

			if !trackingRequest.isLastFrame {
				if observation.confidence > 0.3 {
					trackingRequest.inputObservation = observation
				} else {
					trackingRequest.isLastFrame = true
				}
				newTrackingRequests.append(trackingRequest)
			}
		}
		self.trackingRequests = newTrackingRequests

		if newTrackingRequests.isEmpty {
			// Nothing to track, so abort.
			return
		}

		// Perform face landmark tracking on detected faces.
		var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()

		// Perform landmark detection on tracked faces.
		for trackingRequest in newTrackingRequests {

			let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in

				if error != nil {
					print("FaceLandmarks error: \(String(describing: error)).")
				}

				guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
					let results = landmarksRequest.results as? [VNFaceObservation] else {
						return
				}

				// Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
				DispatchQueue.main.async {
					self.drawFaceObservations(results)
				}
			})

			guard let trackingResults = trackingRequest.results else {
				return
			}

			guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
				return
			}
			let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
			faceLandmarksRequest.inputFaceObservations = [faceObservation]

			// Continue to track detected facial landmarks.
			faceLandmarkRequests.append(faceLandmarksRequest)

			let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
															orientation: exifOrientation,
															options: requestHandlerOptions)

			do {
				try imageRequestHandler.perform(faceLandmarkRequests)
			} catch let error as NSError {
				NSLog("Failed to perform FaceLandmarkRequest: %@", error)
			}
		}
	}

	fileprivate func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath, applying affineTransform: CGAffineTransform, closingWhenComplete closePath: Bool) {
		let pointCount = landmarkRegion.pointCount
		if pointCount > 1 {
			let points: [CGPoint] = landmarkRegion.normalizedPoints
			path.move(to: points[0], transform: affineTransform)
			path.addLines(between: points, transform: affineTransform)
			if closePath {
				path.addLine(to: points[0], transform: affineTransform)
				path.closeSubpath()
			}
		}
	}

	fileprivate func addIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
		let displaySize = self.helper.captureDeviceResolution

		let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
		faceRectanglePath.addRect(faceBounds)

		if let landmarks = faceObservation.landmarks {
			// Landmarks are relative to -- and normalized within --- face bounds
			let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y)
				.scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)

			// Treat eyebrows and lines as open-ended regions when drawing paths.
			let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
				landmarks.leftEyebrow,
				landmarks.rightEyebrow,
				landmarks.faceContour,
				landmarks.noseCrest,
				landmarks.medianLine
			]
			for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
				self.addPoints(in: openLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
			}

			// Draw eyes, lips, and nose as closed regions.
			let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
				landmarks.leftEye,
				landmarks.rightEye,
				landmarks.outerLips,
				landmarks.innerLips,
				landmarks.nose
			]
			for closedLandmarkRegion in closedLandmarkRegions where closedLandmarkRegion != nil {
				self.addPoints(in: closedLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: true)
			}
		}
	}

	fileprivate func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
		guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
			let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
			else {
				return
		}

		CATransaction.begin()

		CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)

		let faceRectanglePath = CGMutablePath()
		let faceLandmarksPath = CGMutablePath()

		for faceObservation in faceObservations {
			self.addIndicators(to: faceRectanglePath,
							   faceLandmarksPath: faceLandmarksPath,
							   for: faceObservation)
		}

		faceRectangleShapeLayer.path = faceRectanglePath
		faceLandmarksShapeLayer.path = faceLandmarksPath

		self.updateLayerGeometry()

		CATransaction.commit()
	}

	fileprivate func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
		return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
	}

	fileprivate func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation)
		-> CGImagePropertyOrientation {

		switch deviceOrientation {
		case .portraitUpsideDown:
			return .left

		case .landscapeLeft:
			return .down

		case .landscapeRight:
			return .up

		default:
			return .right
		}
	}
}
