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
	case content([ViewElement<Msg>])
}

class TableCellView<Msg> : UITableViewCell {
	lazy var contentReconciler: ViewReconciler<Msg> = ViewReconciler<Msg>(view: self.contentView, layoutGuideForKey: { _ in nil })
	
	override func prepareForReuse() {
		super.prepareForReuse()
		
		//
	}
	
	override func updateConstraints() {
		//
		
		super.updateConstraints()
	}
	
	fileprivate func update(cellProps: [CellProp<Msg>], send: (Msg) -> ()) {
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
				self.contentReconciler.update(elements)
				break
			}
		}
	}
	
	fileprivate var layoutContext: LayoutContext {
		return self.contentReconciler.layoutContext
	}
}

struct TableCellTemplate<CellModel, Msg> {
	var reuseIdentifier: String
	var render: (CellModel) -> [CellProp<Msg>]
	var layout: (_ cellModel: CellModel, _ context: LayoutContext) -> [NSLayoutConstraint]
}

public class TableAssistant<Model, CellModel, Msg> {
	public var tableView: UITableView
	public var model: Model
	private var _update: (Msg, inout Model) -> ()
	var cellIdentifiersToTemplates = [String: TableCellTemplate<CellModel, Msg>]()
	
	public init(tableView: UITableView, initial: Model, update: @escaping (Msg, inout Model) -> ()) {
		self.tableView = tableView
		self.model = initial
		self._update = update
	}
	
	private func send(_ message: Msg) {
		self._update(message, &self.model)
		self.tableView.reloadData()
	}
	
	public func registerCells<ReuseIdentifier>(reuseIdentifier: ReuseIdentifier, render: @escaping (CellModel) -> [CellProp<Msg>], layout: @escaping (_ cellModel: CellModel, _ context: LayoutContext) -> [NSLayoutConstraint]) {
		let reuseIdentifierString = String(describing: reuseIdentifier)
		let cellTemplate = TableCellTemplate(reuseIdentifier: reuseIdentifierString, render: render, layout: layout)
		cellIdentifiersToTemplates[reuseIdentifierString] = cellTemplate
		tableView.register(TableCellView<Msg>.self, forCellReuseIdentifier: reuseIdentifierString)
	}
	
	public func cell<ReuseIdentifier>(_ reuseIdentifier: ReuseIdentifier, _ cellModel: CellModel) -> UITableViewCell {
		let reuseIdentifierString = String(describing: reuseIdentifier)
		let cellView = tableView.dequeueReusableCell(withIdentifier: reuseIdentifierString) as! TableCellView<Msg>
		
		let template = cellIdentifiersToTemplates[reuseIdentifierString]!
		let cellProps = template.render(cellModel)
		cellView.update(cellProps: cellProps, send: { [weak self] in self?.send($0) })
		
		let constraints = template.layout(cellModel, cellView.layoutContext)
		NSLayoutConstraint.activate(constraints)
		
		return cellView
	}
}
