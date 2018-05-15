//
//  CustomElements.swift
//  Counter Shohin Example
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit
import Shohin


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
	static func value(_ value: Float) -> ControlProps {
		return .set(\.value, to: value)
	}
	
	static func minimumValue(_ value: Float) -> ControlProps {
		return .set(\.minimumValue, to: value)
	}
	
	static func maximumValue(_ value: Float) -> ControlProps {
		return .set(\.maximumValue, to: value)
	}
	
	static var isContinuous: ControlProps {
		return .set(\.isContinuous, to: true)
	}
}

public func slider<Key: RawRepresentable, Msg>(_ key: Key, _ props: [ControlProps<Msg, UISlider>]) -> Element<Msg> where Key.RawValue == String {
	return control(makeDefault: { UISlider() })(key, props)
}

