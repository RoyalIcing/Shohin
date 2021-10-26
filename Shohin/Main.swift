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

/// This allow using view controllers such as PageViewController
public protocol ViewInstance : class {
	var view: UIView { get }
}

//protocol NestedViewInstance : ViewInstance {
//	associatedtype Message
//
//	var nestedReconcilers: [ViewReconciler<Message>] { get }
//}
//
//struct ViewInstanceWrapper<Msg> {
//	var instance: ViewInstance
//
//	var view: UIView {
//		return instance.view
//	}
//
//	var nestedReconcilers: [ViewReconciler<Msg>] {
//		guard let instance = self.instance as? NestedViewInstance else {
//			return []
//		}
//	}
//}

class GeneralViewInstance : ViewInstance {
	var view: UIView
	
	init(view: UIView) {
		self.view = view
	}
}

public enum ViewElement<Msg> {
	public typealias ViewAndRegisterEventHandler = (UIView, (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) -> ()
	public typealias ViewInstanceAndRegisterEventHandler = (ViewInstance, (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) -> ()
	
	case normal(key: String, makeViewIfNeeded: (UIView?) -> UIView, applyToView: ViewAndRegisterEventHandler)
	case instance(key: String, makeIfNeeded: (ViewInstance?) -> ViewInstance, applyTo: ViewInstanceAndRegisterEventHandler)
	
	public var key: String {
		get {
			switch self {
			case let .normal(key, _, _):
				return key
			case let .instance(key, _, _):
				return key
			}
		}
		set(newKey) {
			switch self {
			case let .normal(_, makeViewIfNeeded, applyToView):
				self = .normal(key: newKey, makeViewIfNeeded: makeViewIfNeeded, applyToView: applyToView)
			case let .instance(_, makeIfNeeded, applyTo):
				self = .instance(key: newKey, makeIfNeeded: makeIfNeeded, applyTo: applyTo)
			}
		}
	}
	
	public init(
		key: String,
		makeViewIfNeeded: @escaping (UIView?) -> UIView,
		applyToView: @escaping ViewAndRegisterEventHandler
		) {
		self = .normal(key: key, makeViewIfNeeded: makeViewIfNeeded, applyToView: applyToView)
	}
}

public struct LayerElement<Msg> {
	public typealias MakeLayer = (CALayer?) -> CALayer
	public typealias LayerAndRegisterEventHandler = (CALayer, (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) -> ()
	
	public var key: String
	public var makeLayerIfNeeded: MakeLayer
	public var applyToLayer: LayerAndRegisterEventHandler
	
	public init(
		key: String,
		makeLayerIfNeeded: @escaping MakeLayer,
		applyToLayer: @escaping LayerAndRegisterEventHandler
		) {
		self.key = key
		self.makeLayerIfNeeded = makeLayerIfNeeded
		self.applyToLayer = applyToLayer
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
	
	private var keyToInstance: Dictionary<String, ViewInstance> = [:]
	private var keyToEventHandlers: Dictionary<String, EventHandlerSet<Msg>> = [:]
	private var layoutGuideForKey: (String) -> UILayoutGuide?
	
	init(view: UIView, layoutGuideForKey: @escaping (String) -> UILayoutGuide?) {
		self.view = view
		self.layoutGuideForKey = layoutGuideForKey
	}
	
	func update(_ elements: [ViewElement<Msg>]) {
		for element in elements {
			switch element {
			case let .normal(key, makeViewIfNeeded, applyToView):
				let handlers: EventHandlerSet<Msg>
				if let existingHandlers = keyToEventHandlers[key] {
					handlers = existingHandlers
				}
				else {
					handlers = EventHandlerSet<Msg>()
					handlers.send = send
					keyToEventHandlers[key] = handlers
				}
				
				let existingInstance = keyToInstance[key]
				let existingView = existingInstance?.view
				let updatedView = makeViewIfNeeded(existingView)
				let updatedInstance: ViewInstance
				if let existingInstance = existingInstance as? GeneralViewInstance {
					existingInstance.view = updatedView
					updatedInstance = existingInstance
				}
				else {
					updatedInstance = GeneralViewInstance(view: updatedView)
				}
				
				var changed = true
				if let existingInstance = existingInstance,
					ObjectIdentifier(existingInstance) == ObjectIdentifier(updatedInstance) {
					changed = false
				}
				
				if changed {
					keyToInstance[key] = updatedInstance
					
					existingView?.removeFromSuperview()
					view.addSubview(updatedView)
				}
				
				applyToView(
					updatedView,
					handlers.curriedRegister(elementKey: key)
				)
			case let .instance(key, makeIfNeeded, applyTo):
				let handlers: EventHandlerSet<Msg>
				if let existingHandlers = keyToEventHandlers[key] {
					handlers = existingHandlers
				}
				else {
					handlers = EventHandlerSet<Msg>()
					handlers.send = send
					keyToEventHandlers[key] = handlers
				}
				
				let existingInstance = keyToInstance[key]
				let updatedInstance = makeIfNeeded(existingInstance)
				
				var changed = true
				if let existingInstance = existingInstance,
					ObjectIdentifier(existingInstance) == ObjectIdentifier(updatedInstance) {
					changed = false
				}
				
				if changed {
					keyToInstance[key] = updatedInstance
					
					existingInstance?.view.removeFromSuperview()
					view.addSubview(updatedInstance.view)
				}
				
				applyTo(
					updatedInstance,
					handlers.curriedRegister(elementKey: key)
				)
			}
		}
	}
	
	func view(forKey key: String) -> UIView? {
		return keyToInstance[key]?.view
	}
	
	var layoutContext: LayoutContext {
		return LayoutContext(view: self.view, viewForKey: self.view(forKey:), guideForKey: self.layoutGuideForKey)
	}
	
	func apply(layout: (_ context: LayoutContext) -> [NSLayoutConstraint]) {
		let constraints = layout(layoutContext)
		NSLayoutConstraint.activate(constraints)
	}
	
	public func apply<Model>(model: Model, render: (Model) -> [ViewElement<Msg>], layout: (_ model: Model, _ context: LayoutContext) -> [NSLayoutConstraint]) {
		self.update(render(model))
		let constraints = layout(model, layoutContext)
		NSLayoutConstraint.activate(constraints)
	}
}

class ViewElementController<Msg> : UIViewController {
	var reconciler: ViewReconciler<Msg>!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		reconciler = ViewReconciler(view: self.view, layoutGuideForKey: { _ in nil })
	}
	
	func update(_ elements: [ViewElement<Msg>]) {
		_ = self.view
		reconciler.update(elements)
	}
}

class LayerReconciler<Msg> {
	let layer: CALayer
	var send: (Msg) -> () = { _ in }
	
	private var keyToSublayer: Dictionary<String, CALayer> = [:]
//	private var keyToEventHandlers: Dictionary<String, EventHandlerSet<Msg>> = [:]
	
	init(layer: CALayer) {
		self.layer = layer
	}
	
	func update(_ elements: [LayerElement<Msg>]) {
		CATransaction.begin()
		CATransaction.setAnimationDuration(0.0)
		
		for element in elements {
			let key = element.key
//			let handlers: EventHandlerSet<Msg>
//			if let existingHandlers = keyToEventHandlers[key] {
//				handlers = existingHandlers
//			}
//			else {
//				handlers = EventHandlerSet<Msg>()
//				handlers.send = send
//				keyToEventHandlers[key] = handlers
//			}
			let existingLayer = keyToSublayer[key]
			let updatedLayer = element.makeLayerIfNeeded(existingLayer)
			
			if existingLayer != updatedLayer {
				keyToSublayer[key] = updatedLayer
				
				existingLayer?.removeFromSuperlayer()
				layer.addSublayer(updatedLayer)
			}
			
			element.applyToLayer(
				updatedLayer,
				{ _, _, _ in (nil, NSSelectorFromString("doNothing:")) } //handlers.curriedRegister(elementKey: key)
			)
		}
		
		CATransaction.commit()
	}
	
	func layer(forKey key: String) -> CALayer? {
		return keyToSublayer[key]
	}
	
	public func apply<Model>(model: Model, render: @escaping (Model) -> [LayerElement<Msg>]) {
		self.update(render(model))
	}
}

public class Program<Model, Msg> {
	let reconciler: ViewReconciler<Msg>
	let store: LocalStore<Model, Msg>
	var unsubscribeFromStore: LocalStore<Model, Msg>.Unsubscribe!
	
	public init(
		view: UIView,
		store: LocalStore<Model, Msg>,
		render: @escaping (Model) -> [ViewElement<Msg>] = { _ in [] },
		layoutGuideForKey: @escaping (String) -> UILayoutGuide? = { _ in nil },
		layout: @escaping (Model, LayoutContext) -> [NSLayoutConstraint] = { _, _ in [] }
		) {
		let reconciler = ViewReconciler<Msg>(view: view, layoutGuideForKey: layoutGuideForKey)
		self.reconciler = reconciler
		self.store = store
		
		reconciler.send = store.receive(message:)
		
		func use(model: Model) {
			reconciler.apply(model: model, render: render, layout: layout)
		}
		
		self.unsubscribeFromStore = store.subscribe(use(model:))
		use(model: store.currentModel)
	}
	
	deinit {
		self.unsubscribeFromStore()
	}
	
	public convenience init(
		view: UIView,
		model: Model,
		initialCommand: Command<Msg> = [],
		update: @escaping (Msg, inout Model) -> Command<Msg> = { _, _ in [] },
		render: @escaping (Model) -> [ViewElement<Msg>] = { _ in [] },
		layoutGuideForKey: @escaping (String) -> UILayoutGuide? = { _ in nil },
		layout: @escaping (Model, LayoutContext) -> [NSLayoutConstraint] = { _, _ in [] }
		) {
		let store = LocalStore(
			initial: (model, initialCommand),
			update: update
		)
		self.init(view: view, store: store, render: render, layoutGuideForKey: layoutGuideForKey, layout: layout)
	}
	
	public var model: Model {
		return store.currentModel
	}
	
	public func send(_ message: Msg) {
		store.receive(message: message)
	}
}

// TODO: keep or remove?
public func withLayers
	<Model, Msg, Store: ModelProvider>
	(
		layer: CALayer,
		store: Store,
		render: @escaping (Model) -> [LayerElement<Msg>] = { _ in [] }
	) -> Store.Unsubscribe
	where Store.Model == Model, Store.Msg == Msg
{
	let reconciler = LayerReconciler<Msg>(layer: layer)
	
	reconciler.send = store.receive(message:)
	return store.subscribe { model in
		reconciler.apply(model: model, render: render)
	}
}

public class LayerProgram<Model, Msg, Store: ModelProvider>
where Store.Model == Model, Store.Msg == Msg
{
	let reconciler: LayerReconciler<Msg>
	let store: Store
	var unsubscribeFromStore: Store.Unsubscribe!
	
	public init(
		layer: CALayer,
		store: Store,
		render: @escaping (Model) -> [LayerElement<Msg>] = { _ in [] }
		) {
		let reconciler = LayerReconciler<Msg>(layer: layer)
		self.reconciler = reconciler
		self.store = store
		
		reconciler.send = store.receive(message:)
		self.unsubscribeFromStore = store.subscribe { model in
			reconciler.apply(model: model, render: render)
		}
	}
	
	deinit {
		self.unsubscribeFromStore()
	}
	
	public var model: Model {
		return store.currentModel
	}
	
	public func send(_ message: Msg) {
		store.receive(message: message)
	}
}
