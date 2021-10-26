//
//  Pages.swift
//  Shohin
//
//  Created by Patrick Smith on 16/9/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


//struct PagesRenderer<Msg> {
//	let renderPageAtIndex: (Int) -> [ViewElement<Msg>]
//}


class PageViewElementController<Msg> : ViewElementController<Msg> {
	var index: Int = -1
}


class PagesViewInstance<Msg> : NSObject, ViewInstance, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	let vc: UIPageViewController
	var count: Int = 0
	var selectedIndex: Int = 0
	var renderPageAtIndex: (Int) -> [ViewElement<Msg>] = { _ in return [] }
	var layoutPageAtIndex: (Int, LayoutContext) -> [NSLayoutConstraint] = { _, _ in return [] }
	
	override init() {
		vc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
		
		super.init()
		
		vc.view.translatesAutoresizingMaskIntoConstraints = false
	}
	
	var view: UIView {
		return vc.view
	}
	
	private func makePage(index: Int) -> PageViewElementController<Msg> {
		let newVC = PageViewElementController<Msg>()
		newVC.index = index
		newVC.update(self.renderPageAtIndex(index))
		return newVC
	}
	
	func update() {
		vc.delegate = self
		vc.dataSource = self
		
		print("SELECTED \(selectedIndex)")
		vc.setViewControllers([
			makePage(index: selectedIndex)
			], direction: .forward, animated: false, completion: nil)
	}
	
	func presentationCount(for pageViewController: UIPageViewController) -> Int {
		return count
	}
	
	func presentationIndex(for pageViewController: UIPageViewController) -> Int {
		return selectedIndex
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let viewController = viewController as? PageViewElementController<Msg> else { return nil }
		let newIndex = viewController.index - 1
		guard newIndex >= 0 else { return nil }
		return makePage(index: newIndex)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let viewController = viewController as? PageViewElementController<Msg> else { return nil }
		let newIndex = viewController.index + 1
		guard newIndex < self.count else { return nil }
		return makePage(index: newIndex)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
		for vc in pendingViewControllers {
			let vc = vc as! PageViewElementController<Msg>
			vc.reconciler.apply(layout: { layoutPageAtIndex(vc.index, $0) })
		}
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		if completed {
			guard let vc = pageViewController.viewControllers?.first as? PageViewElementController<Msg> else { return }
			selectedIndex = vc.index
		}
	}
}

struct PagesElement<Msg, Page: RawRepresentable>
	where Page.RawValue == Int
{
	let key: String
	let count: Int
	let selected: Page
	let renderPage: (Page) -> [ViewElement<Msg>]
	let layoutPage: (Page, LayoutContext) -> [NSLayoutConstraint]
	
	func prepare(existing: ViewInstance?) -> ViewInstance {
		return existing as? PagesViewInstance<Msg> ?? PagesViewInstance()
	}
	
	private func applyTo(_ instance: ViewInstance, registerEventHandler: (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) {
		guard let instance = instance as? PagesViewInstance<Msg> else { return }
		
		instance.count = count
		instance.selectedIndex = selected.rawValue
		instance.renderPageAtIndex = { [renderPage] index in
			guard let page = Page(rawValue: index) else { return [] }
			return renderPage(page)
		}
		instance.layoutPageAtIndex = { [layoutPage] index, context in
			guard let page = Page(rawValue: index) else { return [] }
			return layoutPage(page, context)
		}
		
		instance.update()
	}
	
	func toElement() -> ViewElement<Msg> {
		return ViewElement.instance(key: key, makeIfNeeded: prepare, applyTo: applyTo)
	}
}

extension ViewElement {
	public static func Pages<Key, Page: RawRepresentable>(_ key: Key, count: Int, selected: Page, renderPage: @escaping (Page) -> [ViewElement<Msg>], layoutPage: @escaping (Page, LayoutContext) -> [NSLayoutConstraint])
		-> ViewElement<Msg>
		where Page.RawValue == Int
	{
		return PagesElement(key: String(describing: key), count: count, selected: selected, renderPage: renderPage, layoutPage: layoutPage).toElement()
	}
}
