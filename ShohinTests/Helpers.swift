//
//  Helpers.swift
//  ShohinTests
//
//  Created by Patrick Smith on 17/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


extension UIControl {
	func testSendActions(for controlEvent: UIControlEvents) {
		let targets = self.allTargets
		for target in targets {
			let actions = self.actions(forTarget: target, forControlEvent: controlEvent) ?? []
			for action in actions {
				let selector = NSSelectorFromString(action)
				(target as NSObject).perform(selector, with: nil, with: nil)
			}
		}
	}
}
