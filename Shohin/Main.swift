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


public struct ViewElement<Msg> {
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
	private let _guideForKey: (String) -> UILayoutGuide?
	
	init(view: UIView, viewForKey: @escaping (String) -> UIView?, guideForKey: @escaping (String) -> UILayoutGuide?) {
		self._view = view
		self._viewForKey = viewForKey
		self._guideForKey = guideForKey
	}
	
	public var marginsGuide: UILayoutGuide {
		return _view.layoutMarginsGuide
	}
	
	public var safeAreaGuide: UILayoutGuide {
		return _view.safeAreaLayoutGuide
	}
	
	public var readableContentGuide: UILayoutGuide {
		return _view.readableContentGuide
	}
	
	public var view: UIView {
		return _view
	}
	
	public func view<Key>(_ key: Key) -> UIView? {
		return _viewForKey(String(describing: key))
	}
	
	public func guide<Key>(_ key: Key) -> UILayoutGuide? {
		return _guideForKey(String(describing: key))
	}
}


class ViewReconciler<Msg> {
	let view: UIView
	var send: (Msg) -> () = { _ in }
	
	private var keyToSubview: Dictionary<String, UIView> = [:]
	private var keyToEventHandlers: Dictionary<String, EventHandlerSet<Msg>> = [:]
	private var layoutGuideForKey: (String) -> UILayoutGuide?
	
	init(view: UIView, layoutGuideForKey: @escaping (String) -> UILayoutGuide?) {
		self.view = view
		self.layoutGuideForKey = layoutGuideForKey
	}
	
	func update(_ elements: [ViewElement<Msg>]) {
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
	
	var layoutContext: LayoutContext {
		return LayoutContext(view: self.view, viewForKey: self.view(forKey:), guideForKey: self.layoutGuideForKey)
	}
	
	public func apply<Model>(model: Model, render: @escaping (Model) -> [ViewElement<Msg>], layout: @escaping (_ model: Model, _ context: LayoutContext) -> [NSLayoutConstraint]) {
		self.update(render(model))
		let constraints = layout(model, layoutContext)
		NSLayoutConstraint.activate(constraints)
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
		render: @escaping (Model) -> [ViewElement<Msg>] = { _ in [] },
		layoutGuideForKey: @escaping (String) -> UILayoutGuide? = { _ in nil },
		layout: @escaping (Model, LayoutContext) -> [NSLayoutConstraint] = { _, _ in [] }
		) {
		let reconciler = ViewReconciler<Msg>(view: view, layoutGuideForKey: layoutGuideForKey)
		self.reconciler = reconciler
		self.store = Store(
			initial: (model, initialCommand),
			update: update,
			connect: { send in
				reconciler.send = send
				return { model in
					reconciler.apply(model: model, render: render, layout: layout)
				}
		})
	}
	
	public var model: Model {
		return store.currentModel
	}
	
	public func send(_ message: Msg) {
		store.receive(message: message)
	}
}
