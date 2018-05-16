//
//  ShohinTests.swift
//  ShohinTests
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import XCTest
@testable import Shohin


enum Mascot : String {
	case cat
	case dog
	case fox
	case wolf
	
	static var allCases: [Mascot] {
		return [.cat, .dog, .fox, .wolf]
	}
}

struct CounterModel {
	var counter: Int = 5
	var maximumValue: Int = 10
	var mascot: Mascot = .cat
}

enum CounterMsg {
	case increment()
	case decrement
	case randomize()
	case setCounter(to: Int)
	case setMaximumValue(to: Int)
	case setMascot(to: Mascot)
	case reset()
}

let intGenerator = RandomGenerator(toMessage: CounterMsg.setCounter)

func updateCounter(message: CounterMsg, change: inout Change<CounterModel, CounterMsg>) {
	switch message {
	case .increment():
		change.model.counter += 1
	case .decrement:
		change.model.counter -= 1
	case .randomize():
		change.send(intGenerator.generate(min: 0, max: change.model.maximumValue))
	case let .setCounter(newValue):
		change.model.counter = newValue
	case let .setMaximumValue(newValue):
		change.model.maximumValue = newValue
	case let .setMascot(newMascot):
		change.model.mascot = newMascot
	case .reset():
		change.model.counter = 0
	}
}

enum CounterKey: String {
	case counter, increment, decrement, randomize, counterField, counterSlider, maximumValueStepper
	case mascotChoice, mascot
}

extension Mascot {
	var label: String {
		switch self {
		case .cat:
			return "Cat"
		case .dog:
			return "Dog"
		case .fox:
			return "Fox"
		case .wolf:
			return "Wolf"
		}
	}
	
	var emoji: String {
		switch self {
		case .cat:
			return "🐱"
		case .dog:
			return "🐶"
		case .fox:
			return "🦊"
		case .wolf:
			return "🐺"
		}
	}
}

func renderCounter(model: CounterModel) -> [Element<CounterMsg>] {
	return [
		label(CounterKey.counter, [
			.tag(1),
			.text("\(model.counter)"),
			.textAlignment(.center),
			]),
		field(CounterKey.counterField, [
			.tag(2),
			.text("\(model.counter)"),
			.returnKeyType(.done),
			.on(.editingDidEndOnExit) { textField, event in
				let value = textField.text.flatMap(Int.init) ?? 0
				return CounterMsg.setCounter(to: value)
			}
			]),
		stepper(CounterKey.maximumValueStepper, [
			.tag(3),
			.value(Double(model.maximumValue)),
			.minimumValue(1),
			.on(.valueChanged) { stepper, event in
				let value = Int(stepper.value)
				return CounterMsg.setMaximumValue(to: value)
			}
			]),
		slider(CounterKey.counterSlider, [
			.tag(4),
			.minimumValue(0),
			.maximumValue(Float(model.maximumValue)),
			.value(Float(model.counter)),
			.isContinuous,
			.on(.valueChanged) { slider, event in
				let value = Int(slider.value)
				return CounterMsg.setCounter(to: value)
			}
			]),
		segmentedControl(CounterKey.mascotChoice, [
			.tag(5),
			.selectedKey(model.mascot.rawValue),
			.segments(
				Mascot.allCases.prefix(upTo: min(model.counter, Mascot.allCases.endIndex)).map { mascot in
					return segment(
						mascot,
						Segment.Content.title(mascot.label),
						enabled: true,
						width: 0.0
					)
			}),
			.on(.valueChanged) { control, event in
				let mascot = Mascot(rawValue: control.selectedSegmentKey)!
				return CounterMsg.setMascot(to: mascot)
			}
			]),
		label(CounterKey.mascot, [
			.tag(6),
			.text(model.mascot.emoji)
			]),
		button(CounterKey.increment, [
			.tag(7),
			.title("Increment", for: .normal),
			.onPress(CounterMsg.increment),
			]),
		button(CounterKey.decrement, [
			.tag(8),
			.title("Decrement", for: .normal),
			.onPress{ CounterMsg.decrement },
			.set(\.tintColor, to: UIColor.red),
			]),
		button(CounterKey.randomize, [
			.tag(9),
			.title("Randomize", for: .normal),
			.onPress(CounterMsg.randomize),
			]),
	]
}

func layoutCounter(model: CounterModel, context: LayoutContext) -> [NSLayoutConstraint] {
	let margins = context.marginsGuide
	let counterView = context.view(CounterKey.counter)!
	let counterField = context.view(CounterKey.counterField)!
	let counterSlider = context.view(CounterKey.counterSlider)!
	let maximumValueStepper = context.view(CounterKey.maximumValueStepper)!
	let mascotChoice = context.view(CounterKey.mascotChoice)!
	let mascot = context.view(CounterKey.mascot)!
	let decrementButton = context.view(CounterKey.decrement)!
	let incrementButton = context.view(CounterKey.increment)!
	let randomizeButton = context.view(CounterKey.randomize)!
	return [
		counterView.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterView.topAnchor.constraint(equalTo: margins.topAnchor),
		counterField.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterField.topAnchor.constraint(equalTo: counterView.bottomAnchor),
		maximumValueStepper.topAnchor.constraint(equalTo: counterField.bottomAnchor),
		maximumValueStepper.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		counterSlider.leadingAnchor.constraint(equalTo: maximumValueStepper.trailingAnchor, constant: 20.0),
		counterSlider.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		counterSlider.topAnchor.constraint(equalTo: counterField.bottomAnchor),
		mascotChoice.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		mascotChoice.topAnchor.constraintGreaterThanOrEqualToSystemSpacingBelow(counterSlider.bottomAnchor, multiplier: 1.0),
		mascot.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		mascot.topAnchor.constraintGreaterThanOrEqualToSystemSpacingBelow(mascotChoice.bottomAnchor, multiplier: 1.0),
		mascot.bottomAnchor.constraint(lessThanOrEqualTo: incrementButton.topAnchor, constant: -20.0),
		decrementButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
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
		return self.mainView.viewWithTag(7) as! UIButton
	}
	
	var decrementButton: UIButton {
		return self.mainView.viewWithTag(8) as! UIButton
	}
	
	override func setUp() {
		super.setUp()
		
		let mainView = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
		mainView.backgroundColor = #colorLiteral(red: 0.239215686917305, green: 0.674509823322296, blue: 0.968627452850342, alpha: 1.0)
		self.mainView = mainView
		
		let app = UIApplication.shared
		let screen = UIScreen.main
		let window = UIWindow(frame: screen.bounds)
		window.addSubview(mainView)
		window.isHidden = false
		
		self.program = Program(view: mainView, model: CounterModel(), initialCommand: [], update: updateCounter, render: renderCounter, layout: layoutCounter)
	}
	
	override func tearDown() {
		self.mainView = nil
		self.program = nil
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	func testInitialRender() {
		XCTAssertEqual(counterView.text, "5")
	}
	
	func testProgramReceive() {
		self.program.store.receive(message: .increment())
		XCTAssertEqual(counterView.text, "6")
		
		self.program.store.receive(message: .increment())
		XCTAssertEqual(counterView.text, "7")
		
		self.program.store.receive(message: .decrement)
		XCTAssertEqual(counterView.text, "6")
	}
	
	func testUIEvents() {
		incrementButton.testSendActions(for: .touchUpInside)
		XCTAssertEqual(counterView.text, "6")
		
		decrementButton.testSendActions(for: .touchUpInside)
		XCTAssertEqual(counterView.text, "5")
	}
	
	func testKeyPath() {
		XCTAssertEqual(decrementButton.tintColor, UIColor.red)
	}
	
	func testPerformanceExample() {
		self.measure {
			for _ in 0...200 {
				self.program.store.receive(message: .increment())
				self.program.store.receive(message: .decrement)
			}
		}
	}
	
}
