//
//  Base.swift
//  Counter Shohin Example
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation
import Shohin


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
	case decrement()
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
	case .decrement():
		change.model.counter -= 1
	case .randomize():
		change.send(intGenerator.generate(min: 0, max: change.model.maximumValue))
	case let .setCounter(newValue):
		change.model.counter = newValue
	case let .setMaximumValue(newValue):
		change.model.maximumValue = newValue
		if change.model.counter > newValue {
			change.model.counter = newValue
	}
	case let .setMascot(newMascot):
		change.model.mascot = newMascot
	case .reset():
		change.model.counter = 0
	}
}

enum CounterKey: String {
	case counter, increment, decrement, randomize, counterField, counterSlider, maximumValueStepper
	case mascotChoice, mascot
	case colorView
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
			.text("Counter:"),
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
			.minimumValue(0),
			.maximumValue(Float(model.maximumValue)),
			.value(Float(model.counter)),
			.isContinuous,
			.set(\.minimumTrackTintColor, to: Optional(UIColor(red: 0, green: 1, blue: 1, alpha: 1))),
			.on(.valueChanged) { slider, event in
				let value = Int(slider.value)
				return CounterMsg.setCounter(to: value)
			}
			]),
		customView(CounterKey.colorView, UIImageView.self, [
			.backgroundColor(UIColor(hue: CGFloat(model.counter) / CGFloat(model.maximumValue), saturation: 1.0, brightness: 0.5, alpha: 1.0).cgColor)
			]),
		segmentedControl(CounterKey.mascotChoice, [
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
			.text(model.mascot.emoji)
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
	let colorView = context.view(CounterKey.colorView)!
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
		colorView.topAnchor.constraint(equalTo: counterSlider.bottomAnchor, constant: 20),
		colorView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		colorView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		mascotChoice.topAnchor.constraint(equalTo: colorView.bottomAnchor, constant: 20),
		mascotChoice.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		mascot.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		mascot.topAnchor.constraint(equalTo: mascotChoice.bottomAnchor, constant: 10.0),
		mascot.bottomAnchor.constraint(equalTo: incrementButton.topAnchor, constant: -20.0),
		decrementButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		]
}
