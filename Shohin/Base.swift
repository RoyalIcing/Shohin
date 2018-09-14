//
//  Base.swift
//  Shohin
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


public struct Command<Msg> {
	indirect enum Storage<Msg> {
		case routine(() -> Msg)
		case batch([Storage<Msg>])
		
		fileprivate func run(send: (Msg) -> ()) {
			switch self {
			case let .routine(routine):
				send(routine())
			case let .batch(commands):
				commands.forEach { $0.run(send: send) }
			}
		}
	}
	
	private let storage: Storage<Msg>
	
	init(store: Storage<Msg>) {
		self.storage = store
	}
	
	public init<S>(batch elements: S) where S : Sequence, Command == S.Element {
		self.storage = .batch(elements.map{ $0.storage })
	}
	
	public func run(send: (Msg) -> ()) {
		self.storage.run(send: send)
	}
}

extension Command : ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: Command...) {
		self.storage = .batch(elements.map{ $0.storage })
	}
}

public protocol ModelProvider : class {
	associatedtype Model
	associatedtype Msg
	
	var currentModel: Model { get }
	
	func receive(message: Msg)
	
	typealias Unsubscribe = () -> ()
	func subscribe(_ f: @escaping (Model) -> ()) -> Unsubscribe
}

public class Store<Model, Msg> : ModelProvider {
	public typealias Unsubscribe = () -> ()
	private class SubscriberIdentifier {}
	
	private var current: MonotonicallyTracked<Model>
	private let updater: (Msg, inout Model) -> (Command<Msg>)
	private var subscribers: Dictionary<ObjectIdentifier, (Model) -> ()> = [:]
	
	public init(
		initial: (Model, Command<Msg>),
		update: @escaping (Msg, inout Model) -> (Command<Msg>)
		) {
		let (current, command) = initial
		self.current = MonotonicallyTracked(current)
		
		self.updater = update
		
		command.run(send: self.receive)
	}
	
	public var currentModel: Model {
		return current.value
	}
	
	private func broadcast(_ model: Model) {
		for (_, subscriber) in self.subscribers {
			subscriber(model)
		}
	}
	
	public func receive(message: Msg) {
		let command = self.updater(message, &self.current.value)
		self.broadcast(self.current.value)
		command.run(send: self.receive)
	}
	
	public func subscribe(_ f: @escaping (Model) -> ()) -> Unsubscribe {
		let id = SubscriberIdentifier()
		subscribers[ObjectIdentifier(id)] = f
		
		return { [weak self] in
			self?.subscribers[ObjectIdentifier(id)] = nil
		}
	}
}
