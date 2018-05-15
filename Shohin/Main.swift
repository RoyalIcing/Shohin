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
		case event((UIEvent) -> Msg)
		case textField((UITextField) -> Msg)
	}
	
	fileprivate let store: Store
	
	init(event makeMessage: @escaping (UIEvent) -> Msg) {
		self.store = .event(makeMessage)
	}
	
	init(textField makeMessage: @escaping (UITextField) -> Msg) {
		self.store = .textField(makeMessage)
	}
}

public struct Element<Msg> {
	public let key: String
	public let makeViewIfNeeded: (UIView?) -> UIView
	public let applyToView: (UIView, (String, MessageMaker<Msg>) -> (Any?, Selector)) -> ()
}


class EventHandler<Msg> : NSObject {
	private let send: (Msg) -> ()
	
	let messageMaker: MessageMaker<Msg>
	
	init(
		send: @escaping (Msg) -> (),
		messageMaker: MessageMaker<Msg>
		) {
		self.send = send
		self.messageMaker = messageMaker
	}
	
	@objc func performForEvent(_ event: UIEvent) {
		switch messageMaker.store {
		case let .event(makeMessage):
			send(makeMessage(event))
		default:
			break
		}
	}
	
	@objc func performForTextField(_ textField: UITextField) {
		switch messageMaker.store {
		case let .textField(makeMessage):
			send(makeMessage(textField))
		default:
			break
		}
	}
	
	private var actionForEvent: Selector {
		return NSSelectorFromString("performForEvent:")
		//return #selector(EventHandler.performForEvent(_:))
	}
	
	private var actionForTextField: Selector {
		return NSSelectorFromString("performForTextField:")
	}
	
	var action: Selector {
		switch messageMaker.store {
		case .event:
			return actionForEvent
		case .textField:
			return actionForTextField
		}
	}
}

class EventHandlerSet<Msg> {
	var groupedHandlers: Dictionary<String, Dictionary<String, EventHandler<Msg>>> = [:]
	var send: (Msg) -> () = { _ in }
	
	private func registerForElement(elementHandlers: inout Dictionary<String, EventHandler<Msg>>?, actionKey: String, messageMaker: MessageMaker<Msg>) -> EventHandler<Msg> {
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
			}, messageMaker: messageMaker)
		
		elementHandlers?[actionKey] = eventHandler
		return eventHandler
	}
	
	func register(elementKey: String, actionKey: String, messageMaker: MessageMaker<Msg>) -> (Any?, Selector) {
		let eventHandler = registerForElement(elementHandlers: &groupedHandlers[elementKey], actionKey: actionKey, messageMaker: messageMaker)
		
		return (eventHandler, eventHandler.action)
	}
	
	func curriedRegister(elementKey: String) -> (String, MessageMaker<Msg>) -> (Any?, Selector) {
		return { (actionKey, messageMaker) in
			self.register(elementKey: elementKey, actionKey: actionKey, messageMaker: messageMaker)
		}
	}
	
	func reset() {
		groupedHandlers.removeAll()
	}
}


public class KeyPathApplier<Root> {
	private var applier: (Root) -> ()
	
	public init<Value>(_ keyPath: ReferenceWritableKeyPath<Root, Value>, value: Value) {
		self.applier = { root in
			root[keyPath: keyPath] = value
		}
	}
	
	public func apply(to root: Root) {
		applier(root)
	}
}


public enum ButtonProps<Msg> {
	case onTouchUpInside((UIEvent) -> Msg)
	case title(String?, for: UIControlState)
	case tag(Int)
	case keyPathApplier(KeyPathApplier<UIButton>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UIButton, Value>, to value: Value) -> ButtonProps {
		return .keyPathApplier(KeyPathApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to button: UIButton, registerEventHandler: (String, MessageMaker<Msg>) -> (Any?, Selector)) {
		switch self {
		case let .onTouchUpInside(makeMessage):
			let (target, action) = registerEventHandler("touchUpInside", MessageMaker(event: makeMessage))
			button.addTarget(target, action: action, for: UIControlEvents.touchUpInside)
		case let .title(title, for: state):
			button.setTitle(title, for: state)
		case let .tag(tag):
			button.tag = tag
		case let .keyPathApplier(applier):
			applier.apply(to: button)
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
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>) -> (Any?, Selector)) {
		guard let button = view as? UIButton else { return }
		
		button.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: button, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func button<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ButtonProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return ButtonElement(key: key.rawValue, props: props).toElement()
}


public enum LabelProps<Msg> {
	case text(String)
	case textAlignment(NSTextAlignment)
	case tag(Int)
	
	fileprivate func apply(to label: UILabel, registerEventHandler: (String, MessageMaker<Msg>) -> (Any?, Selector)) {
		switch self {
		case let .text(text):
			label.text = text
		case let .textAlignment(alignment):
			label.textAlignment = alignment
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
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>) -> (Any?, Selector)) {
		guard let label = view as? UILabel else { return }
		
		props.forEach { $0.apply(to: label, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func label<Key: RawRepresentable, Msg>(_ key: Key, _ props: [LabelProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return LabelElement(key: key.rawValue, props: props).toElement()
}


public enum FieldProps<Msg> {
	case text(String)
	case textAlignment(NSTextAlignment)
	case placeholder(String?)
	case tag(Int)
	case onChange((UITextField) -> Msg)
	
	fileprivate func apply(to field: UITextField, registerEventHandler: (String, MessageMaker<Msg>) -> (Any?, Selector)) {
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
			let (target, action) = registerEventHandler("editingChanged", MessageMaker(textField: makeMessage))
			field.addTarget(target, action: action, for: UIControlEvents.editingChanged)
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
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>) -> (Any?, Selector)) {
		guard let field = view as? UITextField else { return }
		
		field.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: field, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func field<Key: RawRepresentable, Msg>(_ key: Key, _ props: [FieldProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
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
			
			element.applyToView(
				updatedView,
				handlers.curriedRegister(elementKey: key)
			)
		}
	}
	
	func view(forKey key: String) -> UIView? {
		return keyToSubview[key]
	}

	func usingModel<Model>(view: @escaping (Model) -> [Element<Msg>], layout: @escaping (_ model: Model, _ superview: UIView, _ viewForKey: (String) -> UIView?) -> [NSLayoutConstraint]) -> ((Model) -> ()) {
		return { model in
			self.update(view(model))
			for constraint in layout(model, self.view, self.view(forKey:)) {
				constraint.isActive = true
			}
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
		update: @escaping (Msg, inout Change<Model, Msg>) -> () = { _, _ in },
		render: @escaping (Model) -> [Element<Msg>] = { _ in [] },
		layout: @escaping (Model, UIView, (String) -> UIView?) -> [NSLayoutConstraint] = { _, _, _ in [] }
		) {
		let reconciler = ViewReconciler<Msg>(view: view)
		self.reconciler = reconciler
		self.store = Store(
			initial: (model, initialCommand),
			update: { model, message in
				var u = Change<Model, Msg>(model: model)
				update(message, &u)
				return (u.model, u.command)
		},
			connect: { send in
				reconciler.send = send
				return reconciler.usingModel(view: render, layout: layout)
		})
	}
}
