//
//  CustomElements.swift
//  Counter Shohin Example
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit
import Shohin


public enum SliderProps<Msg> {
	case on(UIControlEvents, toMessage: (UISlider, UIEvent) -> Msg)
	case keyPathApplier(KeyPathApplier<UISlider>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UISlider, Value>, to value: Value) -> SliderProps {
		return .keyPathApplier(KeyPathApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to slider: UISlider, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, MessageMaker(control: { toMessage($0 as! UISlider, $1) }), EventHandlingOptions())
			slider.addTarget(target, action: action, for: controlEvents)
		case let .keyPathApplier(applier):
			applier.apply(to: slider)
		}
	}
}

struct SliderElement<Msg> {
	let key: String
	let props: [SliderProps<Msg>]
	
	var defaultSlider: UISlider {
		let slider = UISlider()
		slider.translatesAutoresizingMaskIntoConstraints = false
		return slider
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UISlider ?? defaultSlider
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let button = view as? UISlider else { return }
		
		button.removeTarget(nil, action: nil, for: .allEvents)
		props.forEach { $0.apply(to: button, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> Element<Msg> {
		return Element(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func slider<Key: RawRepresentable, Msg>(_ key: Key, _ props: [SliderProps<Msg>]) -> Element<Msg> where Key.RawValue == String {
	return SliderElement(key: key.rawValue, props: props).toElement()
}
