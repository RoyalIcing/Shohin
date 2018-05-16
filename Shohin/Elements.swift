//
//  Elements.swift
//  Shohin
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


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


protocol ViewProps {
	associatedtype View : UIView
	
	static func set<Value>(_ keyPath: ReferenceWritableKeyPath<View, Value>, to value: Value) -> Self
}

extension ViewProps {
	public static func tag(_ tag: Int) -> Self {
		return self.set(\.tag, to: tag)
	}
}


public enum ButtonProps<Msg> : ViewProps {
	typealias View = UIButton
	
	case onPress((UIEvent) -> Msg)
	case title(String?, for: UIControlState)
	case keyPathApplier(KeyPathApplier<UIButton>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UIButton, Value>, to value: Value) -> ButtonProps {
		return .keyPathApplier(KeyPathApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to button: UIButton, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .onPress(makeMessage):
			let (target, action) = registerEventHandler("touchUpInside", MessageMaker(event: makeMessage), EventHandlingOptions())
			button.addTarget(target, action: action, for: UIControlEvents.touchUpInside)
		case let .title(title, for: state):
			button.setTitle(title, for: state)
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
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
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


public enum LabelProps<Msg> : ViewProps {
	typealias View = UILabel
	
	case text(String)
	case textAlignment(NSTextAlignment)
	case keyPathApplier(KeyPathApplier<UILabel>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UILabel, Value>, to value: Value) -> LabelProps {
		return .keyPathApplier(KeyPathApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to label: UILabel, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .text(text):
			label.text = text
		case let .textAlignment(alignment):
			label.textAlignment = alignment
		case let .keyPathApplier(applier):
			applier.apply(to: label)
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
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
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


public enum FieldProps<Msg> : ViewProps {
	typealias View = UITextField
	
	case text(String)
	case textAlignment(NSTextAlignment)
	case placeholder(String?)
	case keyboardType(UIKeyboardType)
	case returnKeyType(UIReturnKeyType)
	case keyPathApplier(KeyPathApplier<UITextField>)
	case on(UIControlEvents, toMessage: ((UITextField, UIEvent) -> Msg)?)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UITextField, Value>, to value: Value) -> FieldProps {
		return .keyPathApplier(KeyPathApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to field: UITextField, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .text(text):
			field.text = text
		case let .textAlignment(alignment):
			field.textAlignment = alignment
		case let .placeholder(text):
			field.placeholder = text
		case let .keyboardType(keyboardType):
			field.keyboardType = keyboardType
		case let .returnKeyType(returnKeyType):
			field.returnKeyType = returnKeyType
		case let .keyPathApplier(applier):
			applier.apply(to: field)
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, toMessage.map { MessageMaker(control: $0) } ?? MessageMaker(), EventHandlingOptions())
			field.addTarget(target, action: action, for: controlEvents)
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
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
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


public enum ControlProps<Msg, Control: UIControl> {
	case on(UIControlEvents, toMessage: (Control, UIEvent) -> Msg)
	case keyPathApplier(KeyPathApplier<Control>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Control, Value>, to value: Value) -> ControlProps {
		return .keyPathApplier(KeyPathApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to control: Control, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, MessageMaker(control: toMessage), EventHandlingOptions())
			control.addTarget(target, action: action, for: controlEvents)
		case let .keyPathApplier(applier):
			applier.apply(to: control)
		}
	}
}

fileprivate struct ControlElement<Msg, Control: UIControl> {
	let key: String
	let props: [ControlProps<Msg, Control>]
	fileprivate var _makeDefaultControl: () -> Control
	
	func makeDefault() -> Control {
		let control = _makeDefaultControl()
		control.translatesAutoresizingMaskIntoConstraints = false
		return control
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? Control ?? makeDefault()
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let control = view as? Control else { return }
		
		control.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: control, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func control<Key: RawRepresentable, Msg, Control: UIControl>(makeDefault: @escaping () -> Control) -> (_ key: Key, _ props: [ControlProps<Msg, Control>]) -> Element<Msg> where Key.RawValue == String {
	return { key, props in
		return ControlElement(key: key.rawValue, props: props, _makeDefaultControl: makeDefault).toElement()
	}
}


extension ControlProps where Control : UISlider {
	public static func value(_ value: Float) -> ControlProps {
		return .set(\.value, to: value)
	}
	
	public static func minimumValue(_ value: Float) -> ControlProps {
		return .set(\.minimumValue, to: value)
	}
	
	public static func maximumValue(_ value: Float) -> ControlProps {
		return .set(\.maximumValue, to: value)
	}
	
	public static var isContinuous: ControlProps {
		return .set(\.isContinuous, to: true)
	}
}

public func slider<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ControlProps<Msg, UISlider>]) -> Element<Msg> where Key.RawValue == String {
	return control(makeDefault: { UISlider() })(key, props)
}


extension ControlProps where Control : UIStepper {
	public static func value(_ value: Double) -> ControlProps {
		return .set(\.value, to: value)
	}
	
	public static func minimumValue(_ value: Double) -> ControlProps {
		return .set(\.minimumValue, to: value)
	}
	
	public static func maximumValue(_ value: Double) -> ControlProps {
		return .set(\.maximumValue, to: value)
	}
	
	public static var isContinuous: ControlProps {
		return .set(\.isContinuous, to: true)
	}
}

public func stepper<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ControlProps<Msg, UIStepper>]) -> Element<Msg> where Key.RawValue == String {
	return control(makeDefault: { UIStepper() })(key, props)
}
