//
//  Base.swift
//  Counter Shohin Example
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation
import Shohin


struct CounterModel {
	var counter: Int = 0
	var maximumValue: Int = 10
}

enum CounterMsg {
	case increment()
	case decrement()
	case randomize()
	case setCounter(to: Int)
	case setMaximumValue(to: Int)
	case reset()
}

let intGenerator = RandomGenerator(toMessage: CounterMsg.setCounter)

func updateCounter(message: CounterMsg, change: inout Change<CounterModel, CounterMsg>) {
	switch message {
	case .increment():
		change.model.counter += 1
	case .decrement():
		change.model.counter -= 1
	case .randomize():
		change.send(intGenerator.generate(min: 0, max: change.model.maximumValue))
	case let .setCounter(newValue):
		change.model.counter = newValue
	case let .setMaximumValue(newValue):
		change.model.maximumValue = newValue
	case .reset():
		change.model.counter = 0
	}
}

enum CounterKey: String {
	case counter, increment, decrement, randomize, counterField, counterSlider, maximumValueStepper
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
			.value(Double(model.maximumValue)),
			.minimumValue(1),
			.on(.valueChanged) { stepper, event in
				let value = Int(stepper.value)
				return CounterMsg.setMaximumValue(to: value)
			}
			]),
		slider(CounterKey.counterSlider, [
			.value(Float(model.counter)),
			.minimumValue(0),
			.maximumValue(Float(model.maximumValue)),
			.isContinuous,
			.on(.valueChanged) { slider, event in
				let value = Int(slider.value)
				return CounterMsg.setCounter(to: value)
			}
			]),
		button(CounterKey.increment, [
			.tag(3),
			.title("Increment", for: .normal),
			.onPress(CounterMsg.increment),
			]),
		button(CounterKey.decrement, [
			.tag(4),
			.title("Decrement", for: .normal),
			.onPress(CounterMsg.decrement),
			.set(\.tintColor, to: UIColor.red),
			]),
		button(CounterKey.randomize, [
			.tag(5),
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
		decrementButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		]
}
