//
//  Base.swift
//  Shohin
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


public struct Command<Msg> {
	fileprivate indirect enum Store<Msg> {
		case routine(() -> Msg)
		case batch([Store<Msg>])
		
		fileprivate func run(send: (Msg) -> ()) {
			switch self {
			case let .routine(routine):
				send(routine())
			case let .batch(commands):
				commands.forEach { $0.run(send: send) }
			}
		}
	}
	
	private let store: Store<Msg>
	
	fileprivate init(store: Store<Msg>) {
		self.store = store
	}
	
	public init<S>(batch elements: S) where S : Sequence, Command == S.Element {
		self.store = .batch(elements.map{ $0.store })
	}
	
	public func run(send: (Msg) -> ()) {
		self.store.run(send: send)
	}
}

extension Command : ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: Command...) {
		self.store = .batch(elements.map{ $0.store })
	}
}

public class RandomGenerator<Msg> {
	let min: Int
	let max: Int
	let toMessage : (Int) -> Msg
	
	public init(min: Int, max: Int, toMessage: @escaping (Int) -> Msg) {
		self.min = min
		self.max = max
		self.toMessage = toMessage
	}
	
	public var command: Command<Msg> {
		let min = self.min
		let max = self.max
		let toMessage = self.toMessage
		return Command(store: Command.Store.routine({
			let value = min + Int(arc4random_uniform(UInt32(max - min + 1)))
			return toMessage(value)
		}))
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
