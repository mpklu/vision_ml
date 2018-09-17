//
//  ViewController+PresentError.swift
//  vision_ml
//
//  Created by Kun Lu on 8/31/18.
//  Copyright © 2018 Kun Lu. All rights reserved.
//

import Foundation
import UIKit
extension ViewController {
	func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		self.present(alertController, animated: true)
	}

	func presentError(_ error: NSError) {
		self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
	}
}
