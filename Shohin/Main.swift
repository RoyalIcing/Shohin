//
//  Main.swift
//  Shohin
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


public class MessageMaker<Msg> {
	fileprivate enum Store {
		case ignore
		case event((UIEvent) -> Msg)
		case control((UIControl, UIEvent) -> Msg)
	}
	
	fileprivate let store: Store
	
	public init(event makeMessage: @escaping (UIEvent) -> Msg) {
		self.store = .event(makeMessage)
	}
	
	public init<Control: UIControl>(control makeMessage: @escaping (Control, UIEvent) -> Msg) {
		self.store = .control({ makeMessage($0 as! Control, $1) })
	}
	
	public init() {
		self.store = .ignore
	}
}


public struct EventHandlingOptions {
	public var resignFirstResponder: Bool
	
	public init(
		resignFirstResponder: Bool = false
		) {
		self.resignFirstResponder = resignFirstResponder
	}
}


public struct Element<Msg> {
	public typealias MakeView = (UIView?) -> UIView
	public typealias ViewAndRegisterEventHandler = (UIView, (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) -> ()
	
	public var key: String
	public var makeViewIfNeeded: MakeView
	public var applyToView: ViewAndRegisterEventHandler
	
	public init(
		key: String,
		makeViewIfNeeded: @escaping MakeView,
		applyToView: @escaping ViewAndRegisterEventHandler
		) {
		self.key = key
		self.makeViewIfNeeded = makeViewIfNeeded
		self.applyToView = applyToView
	}
}


class EventHandler<Msg> : NSObject {
	private let send: (Msg) -> ()
	
	let messageMaker: MessageMaker<Msg>
	let eventHandlingOptions: EventHandlingOptions
	
	init(
		send: @escaping (Msg) -> (),
		messageMaker: MessageMaker<Msg>,
		eventHandlingOptions: EventHandlingOptions
		) {
		self.send = send
		self.messageMaker = messageMaker
		self.eventHandlingOptions = eventHandlingOptions
	}
	
	@objc func performForEvent(_ event: UIEvent) {
		switch messageMaker.store {
		case let .event(makeMessage):
			send(makeMessage(event))
		default:
			break
		}
	}
	
	@objc func performForControl(_ control: UIControl, event: UIEvent) {
		if eventHandlingOptions.resignFirstResponder {
			control.resignFirstResponder()
		}
		
		switch messageMaker.store {
		case let .control(makeMessage):
			send(makeMessage(control, event))
		default:
			break
		}
	}
	
	@objc func doNothing(_ arg: Any?) {}
	
	var action: Selector {
		switch messageMaker.store {
		case .event:
			return NSSelectorFromString("performForEvent:")
		case .control:
			return NSSelectorFromString("performForControl:event:")
		case .ignore:
			return NSSelectorFromString("doNothing:")
		}
	}
}

class EventHandlerSet<Msg> {
	var groupedHandlers: Dictionary<String, Dictionary<String, EventHandler<Msg>>> = [:]
	var send: (Msg) -> () = { _ in }
	
	private func registerForElement(elementHandlers: inout Dictionary<String, EventHandler<Msg>>?, actionKey: String, messageMaker: MessageMaker<Msg>, eventHandlingOptions: EventHandlingOptions) -> EventHandler<Msg> {
		if elementHandlers == nil {
			elementHandlers = [:]
		}
		
		if
			let existing = elementHandlers?[actionKey],
			existing.messageMaker === messageMaker
		{
			return existing
		}
		
		let eventHandler = EventHandler(send: { [weak self] (msg) in
			self?.send(msg)
			}, messageMaker: messageMaker, eventHandlingOptions: eventHandlingOptions)
		
		elementHandlers?[actionKey] = eventHandler
		return eventHandler
	}
	
	func register(elementKey: String, actionKey: String, messageMaker: MessageMaker<Msg>, eventHandlingOptions: EventHandlingOptions) -> (Any?, Selector) {
		let eventHandler = registerForElement(elementHandlers: &groupedHandlers[elementKey], actionKey: actionKey, messageMaker: messageMaker, eventHandlingOptions: eventHandlingOptions)
		
		return (eventHandler, eventHandler.action)
	}
	
	func curriedRegister(elementKey: String) -> (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector) {
		return { (actionKey, messageMaker, eventHandlingOptions) in
			self.register(elementKey: elementKey, actionKey: actionKey, messageMaker: messageMaker, eventHandlingOptions: eventHandlingOptions)
		}
	}
	
	func reset() {
		groupedHandlers.removeAll()
	}
}


public class LayoutContext {
	private let _view: UIView
	private let _viewForKey: (String) -> UIView?
	
	init(view: UIView, viewForKey: @escaping (String) -> UIView?) {
		self._view = view
		self._viewForKey = viewForKey
	}
	
	public var marginsGuide: UILayoutGuide {
		return _view.layoutMarginsGuide
	}
	
	public var safeAreaGuide: UILayoutGuide {
		return _view.safeAreaLayoutGuide
	}
	
	public func view<Key: RawRepresentable>(_ key: Key) -> UIView? where Key.RawValue == String {
		return _viewForKey(key.rawValue)
	}
}


class ViewReconciler<Msg> {
	let view: UIView
	var send: (Msg) -> () = { _ in }
	
	private var keyToSubview: Dictionary<String, UIView> = [:]
	private var keyToEventHandlers: Dictionary<String, EventHandlerSet<Msg>> = [:]
	
	init(view: UIView) {
		self.view = view
	}
	
	func update(_ elements: [Element<Msg>]) {
		for element in elements {
			let key = element.key
			let handlers: EventHandlerSet<Msg>
			if let existingHandlers = keyToEventHandlers[key] {
				handlers = existingHandlers
			}
			else {
				handlers = EventHandlerSet<Msg>()
				handlers.send = send
				keyToEventHandlers[key] = handlers
			}
			let existingView = keyToSubview[key]
			let updatedView = element.makeViewIfNeeded(existingView)
			
			if existingView != updatedView {
				keyToSubview[key] = updatedView
				
				existingView?.removeFromSuperview()
				view.addSubview(updatedView)
			}
			
			element.applyToView(
				updatedView,
				handlers.curriedRegister(elementKey: key)
			)
		}
	}
	
	func view(forKey key: String) -> UIView? {
		return keyToSubview[key]
	}

	func usingModel<Model>(view: @escaping (Model) -> [Element<Msg>], layout: @escaping (_ model: Model, _ context: LayoutContext) -> [NSLayoutConstraint]) -> ((Model) -> ()) {
		return { model in
			self.update(view(model))
			let constraints = layout(model, LayoutContext(view: self.view, viewForKey: self.view(forKey:)))
			NSLayoutConstraint.activate(constraints)
		}
	}
}

public struct Change<Model, Msg> {
	var changeCount = 0
	
	public var model: Model {
		didSet {
			changeCount += 1
		}
	}
	
	private var commands: [Command<Msg>] = []
	
	init(model: Model) {
		self.model = model
	}
	
	public mutating func send(_ command: Command<Msg>) {
		commands.append(command)
	}
	
	var command: Command<Msg> {
		return Command(batch: commands)
	}
}

public class Program<Model, Msg> {
	let reconciler: ViewReconciler<Msg>
	let store: Store<Model, Msg>!
	
	public init(
		view: UIView,
		model: Model,
		initialCommand: Command<Msg> = [],
		update: @escaping (Msg, inout Model) -> Command<Msg> = { _, _ in [] },
		render: @escaping (Model) -> [Element<Msg>] = { _ in [] },
		layout: @escaping (Model, LayoutContext) -> [NSLayoutConstraint] = { _, _ in [] }
		) {
		let reconciler = ViewReconciler<Msg>(view: view)
		self.reconciler = reconciler
		self.store = Store(
			initial: (model, initialCommand),
			update: update,
			connect: { send in
				reconciler.send = send
				return reconciler.usingModel(view: render, layout: layout)
		})
	}
}
