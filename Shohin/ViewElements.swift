//
//  ViewElements.swift
//  Shohin
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


public protocol ViewProp {
	associatedtype View : UIView
	
	static func set<Value>(_ keyPath: ReferenceWritableKeyPath<View, Value>, to value: Value) -> Self
}

extension ViewProp {
	public static func tag(_ tag: Int) -> Self {
		return self.set(\.tag, to: tag)
	}
}


public enum LabelProp<Msg> : ViewProp {
	public typealias View = UILabel
	
	case text(String)
	case textAlignment(NSTextAlignment)
	case applyChange(ChangeApplier<UILabel>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UILabel, Value>, to value: Value) -> LabelProp {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	func apply(to label: UILabel) {
		switch self {
		case let .text(text):
			label.text = text
		case let .textAlignment(alignment):
			label.textAlignment = alignment
		case let .applyChange(applier):
			applier.apply(to: label)
		}
	}
}

struct LabelElement<Msg> {
	let key: String
	let props: [LabelProp<Msg>]
	
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
		
		props.forEach { $0.apply(to: label) }
	}
	
	func toElement() -> ViewElement<Msg> {
		return ViewElement(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func label<Key, Msg>(_ key: Key, _ props: [LabelProp<Msg>]) -> ViewElement<Msg> {
	return LabelElement(key: String(describing: key), props: props).toElement()
}


public enum FieldProp<Msg> : ViewProp {
	public typealias View = UITextField
	
	case text(String)
	case textAlignment(NSTextAlignment)
	case placeholder(String?)
	case keyboardType(UIKeyboardType)
	case returnKeyType(UIReturnKeyType)
	case applyChange(ChangeApplier<UITextField>)
	case on(UIControl.Event, toMessage: ((UITextField, UIEvent) -> Msg)?)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UITextField, Value>, to value: Value) -> FieldProp {
		return .applyChange(ChangeApplier(keyPath, value: value))
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
		case let .applyChange(applier):
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
	let props: [FieldProp<Msg>]
	
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
	
	func toElement() -> ViewElement<Msg> {
		return ViewElement(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func field<Key, Msg>(_ key: Key, _ props: [FieldProp<Msg>]) -> ViewElement<Msg> {
	return FieldElement(key: String(describing: key), props: props).toElement()
}


public enum ControlProp<Msg, Control: UIControl> : ViewProp {
	public typealias View = Control
	
	case on(UIControl.Event, toMessage: (Control, UIEvent) -> Msg)
	case applyChange(ChangeApplier<Control>, stage: Int)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Control, Value>, to value: Value, stage: Int) -> ControlProp {
		return .applyChange(ChangeApplier(keyPath, value: value), stage: stage)
	}
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Control, Value>, to value: Value) -> ControlProp {
		return .applyChange(ChangeApplier(keyPath, value: value), stage: 0)
	}
	
	fileprivate func apply(to control: Control, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, MessageMaker(control: toMessage), EventHandlingOptions())
			control.addTarget(target, action: action, for: controlEvents)
		case let .applyChange(applier, _):
			applier.apply(to: control)
		}
	}
}

@objc protocol DefaultFactory: class {
	func makeDefault() -> UIView
}

extension UIControl : DefaultFactory {
	func makeDefault() -> UIView {
		let control = type(of: self).init()
		control.translatesAutoresizingMaskIntoConstraints = false
		return control
	}
}

extension UIButton {
	override func makeDefault() -> UIView {
		let control = type(of: self).init(type: .system)
		control.translatesAutoresizingMaskIntoConstraints = false
		return control
	}
}

struct ControlElement<Msg, Control: UIControl> {
	typealias Item = Control
	
	let key: String
	let props: [ControlProp<Msg, Control>]
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? Control ?? Control().makeDefault()
	}
	
	var prioritisedProps: [(Int, ControlProp<Msg, Control>)] {
		return props.enumerated().sorted(by: { (a, b) -> Bool in
			let (indexA, propA) = a
			let (indexB, propB) = b
			switch (propA, propB) {
			case let (.applyChange(_, stageA), .applyChange(_, stageB)):
				if (stageA == stageB) {
					return indexA < indexB
				}
				else {
					return stageA < stageB
				}
			default:
				return indexA < indexB
			}
		})
	}
	
	func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let control = view as? Control else { return }
		
		control.removeTarget(nil, action: nil, for: .allEvents)
		
		for (_, prop) in prioritisedProps {
			prop.apply(to: control, registerEventHandler: registerEventHandler)
		}
	}
	
	func toElement() -> ViewElement<Msg> {
		return ViewElement(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func control<Key, Msg, Control: UIControl>(_ key: Key, _ props: [ControlProp<Msg, Control>]) -> ViewElement<Msg> {
	return ControlElement(key: String(describing: key), props: props).toElement()
}


extension ControlProp where Control : UIButton {
	public static func title(_ title: String, for controlState: UIControl.State) -> ControlProp {
		return .applyChange(ChangeApplier(makeChanges: { $0.setTitle(title, for: controlState) }), stage: 0)
	}
	
	public static func titleFont(_ font: UIFont) -> ControlProp {
		return .applyChange(ChangeApplier(makeChanges: { $0.titleLabel?.font = font }), stage: 0)
	}
	
	public static func onPress(_ makeMessage: @escaping () -> Msg) -> ControlProp {
		return .on(.touchUpInside) { (button: UIButton, event: UIEvent) in return makeMessage() }
	}
}

public func button<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UIButton>]) -> ViewElement<Msg> {
	return control(key, props)
}


extension ControlProp where Control : UISlider {
	public static func value(_ value: Float) -> ControlProp {
		return .set(\.value, to: value, stage: 10)
	}
	
	public static func minimumValue(_ value: Float) -> ControlProp {
		return .set(\.minimumValue, to: value)
	}
	
	public static func maximumValue(_ value: Float) -> ControlProp {
		return .set(\.maximumValue, to: value)
	}
	
	public static var isContinuous: ControlProp {
		return .set(\.isContinuous, to: true)
	}
}

public func slider<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UISlider>]) -> ViewElement<Msg> {
	return control(key, props)
}


extension ControlProp where Control : UIStepper {
	public static func value(_ value: Double) -> ControlProp {
		return .set(\.value, to: value, stage: 10)
	}
	
	public static func minimumValue(_ value: Double) -> ControlProp {
		return .set(\.minimumValue, to: value)
	}
	
	public static func maximumValue(_ value: Double) -> ControlProp {
		return .set(\.maximumValue, to: value)
	}
	
	public static var isContinuous: ControlProp {
		return .set(\.isContinuous, to: true)
	}
}

public func stepper<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UIStepper>]) -> ViewElement<Msg> {
	return control(key, props)
}


extension ControlProp where Control : UISwitch {
    public static func isOn(_ on: Bool, animated: Bool) -> ControlProp {
        return .applyChange(ChangeApplier(applier: {
            if $0.isOn != on {
                $0.setOn(on, animated: animated)
            }
        }), stage: 0)
    }
}

extension ViewElement {
    public static func `switch`<Key>(_ key: Key, _ props: [ControlProp<Msg, UISwitch>]) -> ViewElement<Msg> {
        return control(key, props)
    }
}

public func `switch`<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UISwitch>]) -> ViewElement<Msg> {
    return control(key, props)
}


public struct Segment {
	public enum Content {
		case title(String)
		case image(UIImage)
	}
	
	public var key: String
	public var content: Content
	public var enabled = true
	public var width: CGFloat = 0
	
	func add(to segmentedControl: UISegmentedControl, index: Int) {
		let maxIndex = segmentedControl.numberOfSegments
		switch content {
		case let .image(image):
			if index >= maxIndex {
				segmentedControl.insertSegment(with: image, at: index, animated: false)
			}
			else {
				segmentedControl.setImage(image, forSegmentAt: index)
			}
		case let .title(title):
			if index >= maxIndex {
				segmentedControl.insertSegment(withTitle: title, at: index, animated: false)
			}
			else {
				segmentedControl.setTitle(title, forSegmentAt: index)
			}
		}
		segmentedControl.setEnabled(enabled, forSegmentAt: index)
		segmentedControl.setWidth(width, forSegmentAt: index)
	}
}

public func segment<Key>(_ key: Key, _ content: Segment.Content, enabled: Bool = true, width: CGFloat = 0.0) -> Segment {
	return Segment(key: String(describing: key), content: content, enabled: enabled, width: width)
}

var segmentKeysAssociatedObjectKey = true

extension UISegmentedControl {
	public var selectedSegmentKey: String! {
		guard let segmentKeys = objc_getAssociatedObject(self, &segmentKeysAssociatedObjectKey) as? [String]
			else { return nil }
	
		let index = self.selectedSegmentIndex
		if index >= self.numberOfSegments {
			return nil
		}
		
		return segmentKeys[index]
	}
}

public enum SegmentedControlProp<Msg> : ViewProp {
	public typealias View = UISegmentedControl
	
	case selectedKey(String)
	case segments([Segment])
	case applyChange(ChangeApplier<UISegmentedControl>)
	case on(UIControl.Event, toMessage: ((UISegmentedControl, UIEvent) -> Msg)?)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<UISegmentedControl, Value>, to value: Value) -> SegmentedControlProp {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	struct CommitState {
		var selectedIndex: Int = UISegmentedControl.noSegment
		var segments: [Segment] = []
		var otherProps: [SegmentedControlProp<Msg>] = []
		
		init(props: [SegmentedControlProp<Msg>]) {
			var selectedKey: String? = nil
			
			for prop in props {
				switch prop {
				case let .selectedKey(key):
					selectedKey = key
				case let .segments(newSegments):
					segments.append(contentsOf: newSegments)
				default:
					otherProps.append(prop)
				}
			}
			
			if let selectedKey = selectedKey {
				for (index, segment) in segments.enumerated() {
					if segment.key == selectedKey {
						selectedIndex = index
						break
					}
				}
			}
		}
		
		fileprivate func apply(to control: UISegmentedControl, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
			for (index, segment) in segments.enumerated() {
				segment.add(to: control, index: index)
			}
			
			let currentCount = control.numberOfSegments
			let countToRemove = max(0, currentCount - segments.count)
			if countToRemove > 0 {
				for index in (currentCount - countToRemove) ..< currentCount {
					control.removeSegment(at: index, animated: false)
				}
			}
			
			control.selectedSegmentIndex = selectedIndex
			
			otherProps.forEach { $0.apply(to: control, registerEventHandler: registerEventHandler) }
			
			let segmentKeys = segments.map{ $0.key }
			objc_setAssociatedObject(control, &segmentKeysAssociatedObjectKey, segmentKeys, .OBJC_ASSOCIATION_COPY_NONATOMIC)
		}
	}
	
	fileprivate func apply(to segmentedControl: UISegmentedControl, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .applyChange(applier):
			applier.apply(to: segmentedControl)
		case let .on(controlEvents, toMessage):
			let key = String(describing: controlEvents)
			let (target, action) = registerEventHandler(key, toMessage.map { MessageMaker(control: $0) } ?? MessageMaker(), EventHandlingOptions())
			segmentedControl.addTarget(target, action: action, for: controlEvents)
		default:
			break
		}
	}
}

struct SegmentedControlElement<Msg> {
	let key: String
	let props: [SegmentedControlProp<Msg>]
	
	private func makeDefault() -> UISegmentedControl {
		let control = UISegmentedControl()
		control.translatesAutoresizingMaskIntoConstraints = false
		return control
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? UISegmentedControl ?? makeDefault()
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let control = view as? UISegmentedControl else { return }
		
		control.removeTarget(nil, action: nil, for: .allEvents)
		
		let state = SegmentedControlProp.CommitState(props: props)
		state.apply(to: control, registerEventHandler: registerEventHandler)
	}
	
	func toElement() -> ViewElement<Msg> {
		return ViewElement(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func segmentedControl<Key, Msg>(_ key: Key, _ props: [SegmentedControlProp<Msg>]) -> ViewElement<Msg> {
	return SegmentedControlElement(key: String(describing: key), props: props).toElement()
}


public enum CustomViewProp<Msg, CustomView: UIView> : ViewProp {
	public typealias View = CustomView
	
	case backgroundColor(CGColor?)
	case applyChange(ChangeApplier<CustomView>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<View, Value>, to value: Value) -> CustomViewProp {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to view: CustomView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .backgroundColor(color):
			view.layer.backgroundColor = color
		case let .applyChange(applier):
			applier.apply(to: view)
		}
	}
}

struct CustomViewElement<Msg, CustomView: UIView> {
	let key: String
	let props: [CustomViewProp<Msg, CustomView>]
	
	private var defaultView: CustomView {
		let label = CustomView()
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}
	
	func prepare(existing: UIView?) -> UIView {
		return existing as? CustomView ?? defaultView
	}
	
	private func applyToView(_ view: UIView, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let customView = view as? CustomView else { return }
		
		props.forEach { $0.apply(to: customView, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> ViewElement<Msg> {
		return ViewElement(key: key, makeViewIfNeeded: prepare, applyToView: applyToView)
	}
}

public func customView<Key, Msg, CustomView: UIView>(_ key: Key, _ viewClass: CustomView.Type, _ props: [CustomViewProp<Msg, CustomView>]) -> ViewElement<Msg> {
	return CustomViewElement(key: String(describing: key), props: props).toElement()
}

