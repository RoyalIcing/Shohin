//
//  LayerElements.swift
//  Shohin
//
//  Created by Patrick Smith on 29/6/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import QuartzCore


public protocol LayerProp {
	associatedtype Layer : CALayer
	
	static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Layer, Value>, to value: Value) -> Self
}


public enum CustomLayerProp<Msg, CustomLayer: CALayer> : LayerProp {
	public typealias Layer = CustomLayer
	
	case backgroundColor(CGColor?)
	case applyChange(ChangeApplier<CustomLayer>)
	
	public static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Layer, Value>, to value: Value) -> CustomLayerProp {
		return .applyChange(ChangeApplier(keyPath, value: value))
	}
	
	fileprivate func apply(to layer: CustomLayer, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		switch self {
		case let .backgroundColor(color):
			layer.backgroundColor = color
		case let .applyChange(applier):
			applier.apply(to: layer)
		}
	}
}

struct CustomLayerElement<Msg, CustomLayer: CALayer> {
	let key: String
	let props: [CustomLayerProp<Msg, CustomLayer>]
	
	private func makeDefault() -> CustomLayer {
		let layer = CustomLayer()
		return layer
	}
	
	func makeLayerIfNeeded(existing: CALayer?) -> CALayer {
		return existing as? CustomLayer ?? makeDefault()
	}
	
	private func applyToLayer(_ layer: CALayer, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let customLayer = layer as? CustomLayer else { return }
		
		props.forEach { $0.apply(to: customLayer, registerEventHandler: registerEventHandler) }
	}
	
	func toElement() -> LayerElement<Msg> {
		return LayerElement(key: key, makeLayerIfNeeded: makeLayerIfNeeded, applyToLayer: applyToLayer)
	}
}

public func customLayer<Key, Msg, CustomLayer: CALayer>(_ key: Key, _ layerClass: CustomLayer.Type, _ props: [CustomLayerProp<Msg, CustomLayer>]) -> LayerElement<Msg> {
	return CustomLayerElement(key: String(describing: key), props: props).toElement()
}
