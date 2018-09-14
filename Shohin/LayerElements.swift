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

extension LayerElement {
	public static func custom<Key, CustomLayer: CALayer>(_ key: Key, _ layerClass: CustomLayer.Type, _ props: [CustomLayerProp<Msg, CustomLayer>]) -> LayerElement<Msg> {
		return CustomLayerElement(key: String(describing: key), props: props).toElement()
	}
}


class LayerReconcilingView<Msg> : UIView {
	var reconciler: LayerReconciler<Msg>!
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		self.translatesAutoresizingMaskIntoConstraints = false
		self.reconciler = LayerReconciler<Msg>(layer: self.layer)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension ViewElement {
	public static func layers<Key>(_ key: Key, _ layerElements: [LayerElement<Msg>]) -> ViewElement<Msg> {
		return ViewElement(
			key: String(describing: key),
			makeViewIfNeeded: { existingView in
				return existingView as? LayerReconcilingView<Msg> ?? LayerReconcilingView()
		},
			applyToView: { (untypedView, registerEventHandler) in
				let view = untypedView as! LayerReconcilingView<Msg>
				view.reconciler.update(layerElements)
		})
	}
}
