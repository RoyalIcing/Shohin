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
}

enum CounterMsg {
	case increment()
	case decrement()
	case randomize()
	case setCounter(to: Int)
	case reset()
}

let generator10 = RandomGenerator(min: 0, max: 10, toMessage: CounterMsg.setCounter)

func updateCounter(message: CounterMsg, change: inout Change<CounterModel, CounterMsg>) {
	switch message {
	case .increment():
		change.model.counter += 1
	case .decrement():
		change.model.counter -= 1
	case .randomize():
		change.send(generator10.command)
	case let .setCounter(newValue):
		change.model.counter = newValue
	case .reset():
		change.model.counter = 0
	}
}

enum CounterKey: String {
	case counter, increment, decrement, randomize, counterField
}

func layoutCounter(model: CounterModel, superview: UIView, viewForKey: (String) -> UIView?) -> [NSLayoutConstraint] {
	let margins = superview.layoutMarginsGuide
	let counterView = viewForKey(CounterKey.counter.rawValue)
	let counterField = viewForKey(CounterKey.counterField.rawValue)
	let decrementButton = viewForKey(CounterKey.decrement.rawValue)
	let incrementButton = viewForKey(CounterKey.increment.rawValue)
	let randomizeButton = viewForKey(CounterKey.randomize.rawValue)
	return [
		counterView?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterView?.topAnchor.constraint(equalTo: margins.topAnchor),
		counterField?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterView.flatMap { counterField?.topAnchor.constraint(equalTo: $0.bottomAnchor) },
		decrementButton?.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton?.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		].compactMap{ $0 }
}

func viewCounter(model: CounterModel) -> [Element<CounterMsg>] {
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
			.on(.editingDidEndOnExit) { textField in
				let value = textField.text.flatMap(Int.init) ?? 0
				return CounterMsg.setCounter(to: value)
			}
			]),
		button(CounterKey.increment, [
			.tag(3),
			.title("Increment", for: .normal),
			.onTouchUpInside { _ in CounterMsg.increment() },
			]),
		button(CounterKey.decrement, [
			.tag(4),
			.title("Decrement", for: .normal),
			.onTouchUpInside({ _ in CounterMsg.decrement() }),
			.set(\.tintColor, to: UIColor.red),
			]),
		button(CounterKey.randomize, [
			.tag(5),
			.title("Randomize", for: .normal),
			.onTouchUpInside({ _ in CounterMsg.randomize() }),
			]),
	]
}
