//
//  Main.swift
//  Shohin
//
//  Created by Patrick Smith on 14/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


class EventHandler<Msg> : NSObject {
	private let send: (Msg) -> ()
	
	enum MessageMaker {
		case event((UIEvent) -> Msg)
		case textField((UITextField) -> Msg)
	}
	
	let messageMaker: MessageMaker
	
	init(
		send: @escaping (Msg) -> (),
		makeMessage: @escaping (UIEvent) -> Msg
		) {
		self.send = send
		self.messageMaker = .event(makeMessage)
	}
	
	init(
		send: @escaping (Msg) -> (),
		makeMessage: @escaping (UITextField) -> Msg
		) {
		self.send = send
		self.messageMaker = .textField(makeMessage)
	}
	
	@objc func performForEvent(_ event: UIEvent) {
		switch messageMaker {
		case let .event(makeMessage):
			send(makeMessage(event))
		default:
			break
		}
	}
	
	@objc func performForTextField(_ textField: UITextField) {
		switch messageMaker {
		case let .textField(makeMessage):
			send(makeMessage(textField))
		default:
			break
		}
	}
	
	var actionForEvent: Selector {
		return NSSelectorFromString("performForEvent:")
		//return #selector(EventHandler.performForEvent(_:))
	}
	
	var actionForTextField: Selector {
		return NSSelectorFromString("performForTextField:")
	}
}

class EventHandlerSet<Msg> {
	var handlers: Dictionary<String, EventHandler<Msg>> = [:]
	var send: (Msg) -> () = { _ in }
	
	func register(key: String, makeMessage: @escaping (UIEvent) -> Msg) -> EventHandler<Msg> {
		let eventHandler = EventHandler(send: { [weak self] (msg) in
			self?.send(msg)
			}, makeMessage: makeMessage)
		handlers[key] = eventHandler
		return eventHandler
	}
	
	func register(key: String, makeMessage: @escaping (UITextField) -> Msg) -> EventHandler<Msg> {
		let eventHandler = EventHandler(send: { [weak self] (msg) in
			self?.send(msg)
			}, makeMessage: makeMessage)
		handlers[key] = eventHandler
		return eventHandler
	}
	
	func reset() {
		handlers.removeAll()
	}
	
	subscript(key: String) -> EventHandler<Msg>? {
		return handlers[key]
	}
}


struct LayoutGuideProp {
	let getConstraint: (UIView, UIView) -> NSLayoutConstraint
	
	init(getConstraintBetween: @escaping (UIView, UIView) -> NSLayoutConstraint) {
		self.getConstraint = getConstraintBetween
	}
	
	static func superview(_ viewAnchorKeyPath: KeyPath<UIView, NSLayoutXAxisAnchor>, equalTo guideAnchorKeyPath: KeyPath<UIView, NSLayoutXAxisAnchor>) -> LayoutGuideProp {
		return self.init { view, guideView in
			let viewAnchor = view[keyPath: viewAnchorKeyPath]
			let guideAnchor = guideView[keyPath: guideAnchorKeyPath]
			return viewAnchor.constraint(equalTo: guideAnchor)
		}
	}
	
	static func superview(_ viewAnchorKeyPath: KeyPath<UIView, NSLayoutYAxisAnchor>, equalTo guideAnchorKeyPath: KeyPath<UIView, NSLayoutYAxisAnchor>) -> LayoutGuideProp {
		return self.init { view, guideView in
			let viewAnchor = view[keyPath: viewAnchorKeyPath]
			let guideAnchor = guideView[keyPath: guideAnchorKeyPath]
			return viewAnchor.constraint(equalTo: guideAnchor)
		}
	}
	
	static func margins(_ viewAnchorKeyPath: KeyPath<UIView, NSLayoutXAxisAnchor>, equalTo guideAnchorKeyPath: KeyPath<UILayoutGuide, NSLayoutXAxisAnchor>) -> LayoutGuideProp {
		return self.superview(viewAnchorKeyPath, equalTo: (\UIView.layoutMarginsGuide).appending(path: guideAnchorKeyPath))
	}
	
	static func margins(_ viewAnchorKeyPath: KeyPath<UIView, NSLayoutYAxisAnchor>, equalTo guideAnchorKeyPath: KeyPath<UILayoutGuide, NSLayoutYAxisAnchor>) -> LayoutGuideProp {
		return self.superview(viewAnchorKeyPath, equalTo: (\UIView.layoutMarginsGuide).appending(path: guideAnchorKeyPath))
	}
}



struct Element<Msg> {
	let key: String
	let makeViewIfNeeded: (UIView?) -> UIView
	let update: (UIView, EventHandlerSet<Msg>, (String?) -> UIView) -> ()
}



enum ButtonProps<Msg> {
	case onTouchUpInside((UIEvent) -> Msg)
	case title(String?, for: UIControlState)
	case layout(LayoutGuideProp)
	case tag(Int)
	
	fileprivate func apply(to button: UIButton, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		switch self {
		case let .onTouchUpInside(makeMessage):
			let handler = eventHandlers.register(key: "@touchUpInside", makeMessage: makeMessage)
			button.addTarget(handler, action: handler.actionForEvent, for: UIControlEvents.touchUpInside)
		case let .title(title, for: state):
			button.setTitle(title, for: state)
		case let .layout(layoutGuideProp):
			layoutGuideProp.getConstraint(button, viewWithKey(nil)).isActive = true
		case let .tag(tag):
			button.tag = tag
		}
	}
}

struct ButtonElement<Msg> {
	let key: String
	let props: [ButtonProps<Msg>]
	
	var defaultButton: UIButton {
		let button = UIButton()
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UIButton ?? defaultButton
	}
	
	func update(_ button: UIButton, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		eventHandlers.reset()
		button.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: button, eventHandlers: eventHandlers, viewWithKey: viewWithKey) }
	}
	
	func updateView(_ view: UIView, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		guard let button = view as? UIButton else { return }
		update(button, eventHandlers: eventHandlers, viewWithKey: viewWithKey)
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, update: updateView)
	}
}

func button<Msg>(_ key: String, _ props: [ButtonProps<Msg>]) -> Element<Msg> {
	return ButtonElement(key: key, props: props).toElement()
}

func button<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ButtonProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return ButtonElement(key: key.rawValue, props: props).toElement()
}


enum LabelProps<Msg> {
	case text(String)
	case textAlignment(NSTextAlignment)
	case layout(LayoutGuideProp)
	case tag(Int)
	
	fileprivate func apply(to label: UILabel, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		switch self {
		case let .text(text):
			label.text = text
		case let .textAlignment(alignment):
			label.textAlignment = alignment
		case let .layout(layoutGuideProp):
			layoutGuideProp.getConstraint(label, viewWithKey(nil)).isActive = true
		case let .tag(tag):
			label.tag = tag
		}
	}
}

struct LabelElement<Msg> {
	let key: String
	let props: [LabelProps<Msg>]
	
	private var defaultLabel: UILabel {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UILabel ?? defaultLabel
	}
	
	func update(_ label: UILabel, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		eventHandlers.reset()
		props.forEach { $0.apply(to: label, eventHandlers: eventHandlers, viewWithKey: viewWithKey) }
	}
	
	func updateView(_ view: UIView, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		guard let label = view as? UILabel else { return }
		update(label, eventHandlers: eventHandlers, viewWithKey: viewWithKey)
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, update: updateView)
	}
}

func label<Msg>(_ key: String, _ props: [LabelProps<Msg>]) -> Element<Msg> {
	return LabelElement(key: key, props: props).toElement()
}

func label<Key: RawRepresentable, Msg>(_ key: Key, _ props: [LabelProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return LabelElement(key: key.rawValue, props: props).toElement()
}


enum FieldProps<Msg> {
	case text(String)
	case textAlignment(NSTextAlignment)
	case placeholder(String?)
	case tag(Int)
	case onChange((UITextField) -> Msg)
	
	fileprivate func apply(to field: UITextField, eventHandlers: EventHandlerSet<Msg>) {
		switch self {
		case let .text(text):
			field.text = text
		case let .textAlignment(alignment):
			field.textAlignment = alignment
		case let .placeholder(text):
			field.placeholder = text
		case let .tag(tag):
			field.tag = tag
		case let .onChange(makeMessage):
			let handler = eventHandlers.register(key: "@editingChanged", makeMessage: makeMessage)
			field.addTarget(handler, action: handler.actionForTextField, for: UIControlEvents.editingChanged)
		}
	}
}

struct FieldElement<Msg> {
	let key: String
	let props: [FieldProps<Msg>]
	
	private func makeDefault() -> UITextField {
		let field = UITextField()
		field.translatesAutoresizingMaskIntoConstraints = false
		return field
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UITextField ?? makeDefault()
	}
	
	func update(_ label: UITextField, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		eventHandlers.reset()
		props.forEach { $0.apply(to: label, eventHandlers: eventHandlers) }
	}
	
	func updateView(_ view: UIView, eventHandlers: EventHandlerSet<Msg>, viewWithKey: (String?) -> UIView) {
		guard let label = view as? UITextField else { return }
		update(label, eventHandlers: eventHandlers, viewWithKey: viewWithKey)
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, update: updateView)
	}
}

func field<Msg>(_ key: String, _ props: [FieldProps<Msg>]) -> Element<Msg> {
	return FieldElement(key: key, props: props).toElement()
}

func field<Key: RawRepresentable, Msg>(_ key: Key, _ props: [FieldProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return FieldElement(key: key.rawValue, props: props).toElement()
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
			element.update(updatedView, handlers, { key in view })
		}
	}
	
	func view(forKey key: String) -> UIView? {
		return keyToSubview[key]
	}
}

extension ViewReconciler {
	func usingModel<Model>(view: @escaping (Model) -> [Element<Msg>], layout: @escaping (_ model: Model, _ superview: UIView, _ viewForKey: (String) -> UIView?) -> [NSLayoutConstraint]) -> ((Model) -> ()) {
		return { model in
			self.update(view(model))
			for constraint in layout(model, self.view, self.view(forKey:)) {
				constraint.isActive = true
			}
		}
	}
}

struct Update<Model, Msg> {
	var changeCount = 0
	
	var model: Model {
		didSet {
			changeCount += 1
		}
	}
	
	private var commands: [Command<Msg>] = []
	
	init(model: Model) {
		self.model = model
	}
	
	mutating func send(_ command: Command<Msg>) {
		commands.append(command)
	}
	
	var command: Command<Msg> {
		return Command.batch(commands)
	}
}

class Program<Model, Msg> {
	let reconciler: ViewReconciler<Msg>
	let store: Store<Model, Msg>!
	
	init(view: UIView, model: Model, initialCommand: Command<Msg>, update: @escaping (Msg, inout Update<Model, Msg>) -> (), render: @escaping (Model) -> [Element<Msg>], layout: @escaping (Model, UIView, (String) -> UIView?) -> [NSLayoutConstraint]) {
		let reconciler = ViewReconciler<Msg>(view: view)
		self.reconciler = reconciler
		self.store = Store(initial: (model, initialCommand), update: { model, message in
			var u = Update<Model, Msg>(model: model)
			update(message, &u)
			return (u.model, u.command)
		}) { send in
			reconciler.send = send
			return reconciler.usingModel(view: render, layout: layout)
		}
	}
}
