//
//  AVCaptureHelper.swift
//  vision_ml
//
//  Created by Kun Lu on 9/12/18.
//  Copyright © 2018 Kun Lu. All rights reserved.
//

import AVFoundation

class AVCaptureHelper {
	var videoDataOutput: AVCaptureVideoDataOutput?
	var videoDataOutputQueue: DispatchQueue?
	var captureDevice: AVCaptureDevice?
	var captureDeviceResolution: CGSize = CGSize()

	func setupAVCaptureSession() throws -> AVCaptureSession {
		let captureSession = AVCaptureSession()
		captureSession.beginConfiguration()
		let inputDevice = try self.configureCamera(for: captureSession)
		self.configureVideoDataOutput(for: inputDevice.device,
									  resolution: inputDevice.resolution,
									  captureSession: captureSession)
		captureSession.commitConfiguration()

		return captureSession
	}

	func teardown() {
		self.videoDataOutput = nil
		self.videoDataOutputQueue = nil
	}

	fileprivate func configureCamera(for captureSession: AVCaptureSession) throws
		-> (device: AVCaptureDevice, resolution: CGSize) {

		let deviceDiscoverySession = AVCaptureDevice
			.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
							  mediaType: .video,
							  position: .back)

		if let device = deviceDiscoverySession.devices.first {
			if let deviceInput = try? AVCaptureDeviceInput(device: device) {
				if captureSession.canAddInput(deviceInput) {
					captureSession.addInput(deviceInput)
				}

				if let highestResolution = self.highestResolution420Format(for: device) {
					try device.lockForConfiguration()
					device.activeFormat = highestResolution.format
					device.unlockForConfiguration()

					return (device, highestResolution.resolution)
				}
			}
		}

		throw NSError(domain: "ViewController", code: 1, userInfo: nil)
	}

	/// find best format and resolution/dimensions
	fileprivate func highestResolution420Format(for device: AVCaptureDevice) ->
		(format: AVCaptureDevice.Format, resolution: CGSize)? {
		var highestResolutionFormat: AVCaptureDevice.Format? = nil
		var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)

		for format in device.formats {
			let deviceFormat = format as AVCaptureDevice.Format

			let deviceFormatDescription = deviceFormat.formatDescription
			if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
				let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
				if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
					highestResolutionFormat = deviceFormat
					highestResolutionDimensions = candidateDimensions
				}
			}
		}

		if let resFormat = highestResolutionFormat {
			let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width),
									height: CGFloat(highestResolutionDimensions.height))
			return (resFormat, resolution)
		}

		return nil
	}

	/// - Tag: CreateSerialDispatchQueue
	fileprivate func configureVideoDataOutput(for inputDevice: AVCaptureDevice,
											  resolution: CGSize,
											  captureSession: AVCaptureSession) {

		let videoDataOutput = AVCaptureVideoDataOutput()
		videoDataOutput.alwaysDiscardsLateVideoFrames = true

		// Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
		// A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
		let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VisionFaceTrack")

		if captureSession.canAddOutput(videoDataOutput) {
			captureSession.addOutput(videoDataOutput)
		}

		videoDataOutput.connection(with: .video)?.isEnabled = true

		if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
			if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
				captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
			}
		}

		self.videoDataOutput = videoDataOutput
		self.videoDataOutputQueue = videoDataOutputQueue

		self.captureDevice = inputDevice
		self.captureDeviceResolution = resolution
	}

	func defaultCameraDevice() -> AVCaptureDevice? {
		var defaultVideoDevice: AVCaptureDevice?
		if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
			defaultVideoDevice = dualCameraDevice
		} else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
			// If the back dual camera is not available, default to the back wide angle camera.
			defaultVideoDevice = backCameraDevice
		} else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
			/*
			In some cases where users break their phones, the back wide angle camera is not available.
			In this case, we should default to the front wide angle camera.
			*/
			defaultVideoDevice = frontCameraDevice
		}
		return defaultVideoDevice
	}
}
