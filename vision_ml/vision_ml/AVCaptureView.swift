//
//  AVCaptureView.swift
//  vision_ml
//
//  Created by Kun Lu on 9/5/18.
//  Copyright © 2018 Kun Lu. All rights reserved.
//

import UIKit
import AVFoundation

class  AVCaptureView: UIView {
	var previewLayer: AVCaptureVideoPreviewLayer?

	func setup() {
		self.previewLayer = setupPreviewLayer()
	}

	func setupPreviewLayer() -> AVCaptureVideoPreviewLayer {
		let previewLayer = AVCaptureVideoPreviewLayer(session: AVCaptureSession())
		previewLayer.name = "CameraPreview"
		previewLayer.backgroundColor = UIColor.black.cgColor
		previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill

		layer.masksToBounds = true
		previewLayer.frame = layer.bounds
		layer.addSublayer(previewLayer)
		return previewLayer
	}

	func teardown() {
		if let previewLayer = self.previewLayer {
			previewLayer.removeFromSuperlayer()
			self.previewLayer = nil
		}
	}
}
