//
//  Base.swift
//  Shohin
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


indirect enum Command<Msg> {
	case none
	case batch([Command<Msg>])
	case routine(() -> Msg)
	
	func run(send: (Msg) -> ()) {
		switch self {
		case let .batch(commands):
			commands.forEach { $0.run(send: send) }
		case let .routine(routine):
			send(routine())
		case .none:
			break
		}
	}
}
extension Command : ExpressibleByArrayLiteral {
	init(arrayLiteral elements: Command...) {
		self = .batch(elements)
	}
}

class RandomGenerator<Msg> {
	let min: Int
	let max: Int
	let toMessage : (Int) -> Msg
	
	init(min: Int, max: Int, toMessage: @escaping (Int) -> Msg) {
		self.min = min
		self.max = max
		self.toMessage = toMessage
	}
	
	var command: Command<Msg> {
		let min = self.min
		let max = self.max
		let toMessage = self.toMessage
		return Command.routine {
			let value = min + Int(arc4random_uniform(UInt32(max - min + 1)))
			return toMessage(value)
		}
	}
}

class Store<Model, Msg> {
	private var _current: Model
	private let updater: (Model, Msg) -> (Model, Command<Msg>)
	private var use: ((Model) -> ()) = { _ in }
	
	init(
		initial: (Model, Command<Msg>),
		update: @escaping (Model, Msg) -> (Model, Command<Msg>),
		connect: (_ send: @escaping (Msg) -> ()) -> ((Model) -> ())
		) {
		let (current, command) = initial
		self._current = current
		
		self.updater = update
		self.use = connect(receive)
		self.use(current)
		
		command.run(send: self.receive)
	}
	
	func receive(message: Msg) {
		let (next, command) = self.updater(_current, message)
		self._current = next
		self.use(self._current)
		command.run(send: self.receive)
	}
}
