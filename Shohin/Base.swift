//
//  Base.swift
//  Shohin
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


public struct Command<Msg> {
	indirect enum Store<Msg> {
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
	
	init(store: Store<Msg>) {
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

class Store<Model, Msg> {
	private var _current: MonotonicallyTracked<Model>
	private let updater: (Msg, inout Model) -> (Command<Msg>)
	private var use: ((Model) -> ()) = { _ in }
	
	init(
		initial: (Model, Command<Msg>),
		update: @escaping (Msg, inout Model) -> (Command<Msg>),
		connect: (_ send: @escaping (Msg) -> ()) -> ((Model) -> ())
		) {
		let (current, command) = initial
		self._current = MonotonicallyTracked(current)
		
		self.updater = update
		self.use = connect(receive)
		self.use(current)
		
		command.run(send: self.receive)
	}
	
	func receive(message: Msg) {
		let command = self.updater(message, &_current.value)
		self.use(self._current.value)
		command.run(send: self.receive)
	}
}
