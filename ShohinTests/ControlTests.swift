//
//  ControlTests.swift
//  ShohinTests
//
//  Created by Patrick Smith on 17/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import XCTest
@testable import Shohin


enum TestMsg {
	case a
}


class ControlTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testPrioritising() {
		let controlElement = ControlElement<TestMsg, UISlider>(key: "", props: [
			.set(\.value, to: 20, stage: 2),
			.set(\.value, to: 30, stage: 3),
			.set(\.value, to: 10, stage: 1),
			.set(\.maximumValue, to: 100, stage: 0)
			])
		
		let prioritisedProps = controlElement.prioritisedProps
		let indexes = prioritisedProps.map { $0.0 }
		XCTAssertEqual(indexes, [3, 2, 0, 1])
		
		let slider = UISlider()
		controlElement.applyToView(slider) { (_, _, _) -> (Any?, Selector) in
			(nil, NSSelectorFromString("self"))
		}
		XCTAssertEqual(slider.value, 30.0)
	}
	
	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure {
			// Put the code you want to measure the time of here.
		}
	}
	
}
