//
//  DecodingTests.swift
//  ShohinTests
//
//  Created by Patrick Smith on 17/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import XCTest
@testable import Shohin


let buttonElementJSONData = """
{ "type": "button", "key": "a", "props": { "title": "Click me" } }
""".data(using: .utf8)!


class DecodingTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testButtonElement() throws {
		let jsonDecoder = JSONDecoder()
		let element = try jsonDecoder.decode(ViewElement<Never>.self, from: buttonElementJSONData)
		
		XCTAssertEqual(element.key, "a")
		
		switch element {
		case let .normal(_, makeViewIfNeeded, applyToView):
			let view = makeViewIfNeeded(nil)
			applyToView(view) { (_, _, _) -> (Any?, Selector) in
				(nil, NSSelectorFromString("self"))
			}
			let button = view as! UIButton
			XCTAssertEqual(button.title(for: UIControl.State.normal), "Click me")
		default:
			XCTFail()
		}
		
//		let view = element.makeViewIfNeeded(nil)
//		element.applyToView(view) { (_, _, _) -> (Any?, Selector) in
//			(nil, NSSelectorFromString("self"))
//		}
//		let button = view as! UIButton
//		XCTAssertEqual(button.title(for: UIControl.State.normal), "Click me")
	}
	
	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure {
			// Put the code you want to measure the time of here.
		}
	}
	
}
