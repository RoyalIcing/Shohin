//
//  ShohinTests.swift
//  ShohinTests
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import XCTest
@testable import Shohin


struct CounterModel {
	var counter: Int = 0
	var multiplier: Int? = 1
}

enum CounterMsg {
	case increment()
	case decrement()
	case randomize()
	case setCounter(to: Int)
	case setMultiplier(to: String)
	case reset()
}

enum CounterKey: String {
	case counter, increment, decrement, randomize
}

let generator10 = RandomGenerator(min: 0, max: 10, toMessage: CounterMsg.setCounter)

func update(message: CounterMsg, u: inout Update<CounterModel, CounterMsg>) -> () {
	switch message {
	case .increment():
		u.model.counter += 1
	case .decrement():
		u.model.counter -= 1
	case .randomize():
		u.send(generator10.command)
	case let .setCounter(newValue):
		u.model.counter = newValue
	case let .setMultiplier(input):
		u.model.multiplier = Int(input)
	case .reset():
		u.model.counter = 0
		u.model.multiplier = 1
	}
}

func layout(model: CounterModel, superview: UIView, viewForKey: (String) -> UIView?) -> [NSLayoutConstraint] {
	let margins = superview.layoutMarginsGuide
	let counterView = viewForKey("counter")
	let multiplierField = viewForKey("multiplierField")
	let decrementButton = viewForKey("decrement")
	let incrementButton = viewForKey("increment")
	let randomizeButton = viewForKey("randomize")
	return [
		counterView?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterView?.topAnchor.constraint(equalTo: margins.topAnchor),
		multiplierField?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		multiplierField?.topAnchor.constraint(equalTo: counterView!.bottomAnchor),
		decrementButton?.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton?.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		].compactMap{ $0 }
}

func view(model: CounterModel) -> [Element<CounterMsg>] {
	return [
		label("counter", [
			.tag(1),
			.text("\(model.counter)"),
			.textAlignment(.center),
			]),
		field("counterField", [
			.tag(2),
			.text("\(model.counter)"),
			.onChange { CounterMsg.setCounter(to: $0.text.flatMap(Int.init) ?? 0) }
			]),
		button("increment", [
			.tag(3),
			.title("Increment", for: .normal),
			.onTouchUpInside { _ in CounterMsg.increment() },
			]),
		button("decrement", [
			.tag(4),
			.title("Decrement", for: .normal),
			.onTouchUpInside({ _ in CounterMsg.decrement() }),
			.set(\.tintColor, to: UIColor.red),
			]),
		button("randomize", [
			.tag(5),
			.title("Randomize", for: .normal),
			.onTouchUpInside({ _ in CounterMsg.randomize() }),
			]),
		field("multiplierField", [
			.tag(6),
			.text(model.multiplier.map {"\($0)"} ?? ""),
			.onChange { CounterMsg.setMultiplier(to: $0.text ?? "") }
			]),
	]
}


class ShohinTests: XCTestCase {
	
	var mainView: UIView!
	var program: Program<CounterModel, CounterMsg>!
	
	var counterView: UILabel {
		return self.mainView.viewWithTag(1) as! UILabel
	}
	
	var counterField: UITextField {
		return self.mainView.viewWithTag(2) as! UITextField
	}
	
	var incrementButton: UIButton {
		return self.mainView.viewWithTag(3) as! UIButton
	}
	
	var decrementButton: UIButton {
		return self.mainView.viewWithTag(4) as! UIButton
	}
	
	override func setUp() {
		super.setUp()
		
		let mainView = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
		mainView.backgroundColor = #colorLiteral(red: 0.239215686917305, green: 0.674509823322296, blue: 0.968627452850342, alpha: 1.0)
		self.mainView = mainView
		
		self.program = Program(view: mainView, model: CounterModel(), initialCommand: [], update: update, render: view, layout: layout)
	}
	
	override func tearDown() {
		self.mainView = nil
		self.program = nil
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testProgramReceive() {
		self.program.store.receive(message: .increment())
		XCTAssertEqual(counterView.text, "1")
		
		self.program.store.receive(message: .increment())
		XCTAssertEqual(counterView.text, "2")
		
		self.program.store.receive(message: .decrement())
		XCTAssertEqual(counterView.text, "1")
	}
	
	func testUIEvents() {
		var e = [XCTestExpectation]()
		
		incrementButton.sendActions(for: .touchUpInside)
		e.append(keyValueObservingExpectation(for: counterView, keyPath: "text", expectedValue: "1"))
		incrementButton.sendActions(for: .touchUpInside)
		e.append(keyValueObservingExpectation(for: counterView, keyPath: "text", expectedValue: "2"))
		e.append(keyValueObservingExpectation(for: counterField, keyPath: "text", expectedValue: "2"))
		
		let _ = XCTWaiter().wait(for: e, timeout: 0.1)
	}
	
	func testKeyPath() {
		XCTAssertEqual(decrementButton.tintColor, UIColor.red)
	}
	
	func testPerformanceExample() {
		self.measure {
			for _ in 0...200 {
				self.program.store.receive(message: .increment())
				self.program.store.receive(message: .decrement())
			}
		}
	}
	
}
