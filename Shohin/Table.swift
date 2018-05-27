//
//  Table.swift
//  Shohin
//
//  Created by Patrick Smith on 27/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


public enum CellProp<Msg> {
	case backgroundColor(UIColor)
	case textLabel([LabelProp<Msg>])
	case content([Element<Msg>])
}

@objc class TableCellView : UITableViewCell {
	var customConstraints: [NSLayoutConstraint] = []
	
	override func prepareForReuse() {
		super.prepareForReuse()
		
		//
	}
	
	override func updateConstraints() {
		//
		
		super.updateConstraints()
	}
	
	fileprivate func setProps<Msg>(_ cellProps: [CellProp<Msg>], reconciler: ViewReconciler<Msg>) {
		for cellProp in cellProps {
			switch cellProp {
			case let .backgroundColor(backgroundColor):
				self.backgroundColor = backgroundColor
			case let .textLabel(labelProps):
				if let label = self.textLabel {
					for labelProp in labelProps {
						labelProp.apply(to: label)
					}
				}
			case let .content(elements):
				reconciler.update(elements)
				break
			}
		}
	}
}

struct TableCellTemplate<Item, Msg> {
	var reuseIdentifier: String
	var render: (Item) -> [CellProp<Msg>]
	var layout: (_ item: Item, _ context: LayoutContext) -> [NSLayoutConstraint]
}

public class TableAssistant<Model, Item, Msg> {
	public var tableView: UITableView
	public var model: Model
	private var _update: (Msg, inout Model) -> ()
	var cellIdentifiersToTemplates = [String: TableCellTemplate<Item, Msg>]()
	var cellReconcilers = [ObjectIdentifier: ViewReconciler<Msg>]()
	
	public init(tableView: UITableView, initial: Model, update: @escaping (Msg, inout Model) -> ()) {
		self.tableView = tableView
		self.model = initial
		self._update = update
	}
	
	public func registerCells<ReuseIdentifier>(reuseIdentifier: ReuseIdentifier, render: @escaping (Item) -> [CellProp<Msg>], layout: @escaping (_ item: Item, _ context: LayoutContext) -> [NSLayoutConstraint], tableView: UITableView) {
		let reuseIdentifierString = String(describing: reuseIdentifier)
		let cellTemplate = TableCellTemplate(reuseIdentifier: reuseIdentifierString, render: render, layout: layout)
		cellIdentifiersToTemplates[reuseIdentifierString] = cellTemplate
		tableView.register(TableCellView.self, forCellReuseIdentifier: reuseIdentifierString)
	}
	
	public func cell<ReuseIdentifier>(_ reuseIdentifier: ReuseIdentifier, _ item: Item, tableView: UITableView) -> UITableViewCell {
		let reuseIdentifierString = String(describing: reuseIdentifier)
		let cellView = tableView.dequeueReusableCell(withIdentifier: reuseIdentifierString) as! TableCellView
		let cellReconciler: ViewReconciler<Msg>
		if let found = cellReconcilers[ObjectIdentifier(cellView)] {
			cellReconciler = found
		}
		else {
			cellReconciler = ViewReconciler<Msg>(view: cellView.contentView, layoutGuideForKey: { _ in nil })
			cellReconciler.send = { message in
				self._update(message, &self.model)
				self.tableView.reloadData()
			}
			cellReconcilers[ObjectIdentifier(cellView)] = cellReconciler
		}
		
		let template = cellIdentifiersToTemplates[reuseIdentifierString]!
		let props = template.render(item)
		cellView.setProps(props, reconciler: cellReconciler)
		NSLayoutConstraint.activate(
			template.layout(item, cellReconciler.layoutContext)
		)
		return cellView
	}
}
