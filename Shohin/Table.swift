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
	var reuseIdentifierString: String!
	lazy var contentReconciler: ViewReconciler<Msg> = ViewReconciler<Msg>(view: self.contentView, layoutGuideForKey: { _ in nil })
	
	override func prepareForReuse() {
		super.prepareForReuse()
		
		//
	}
	
	override func updateConstraints() {
		//
		
		super.updateConstraints()
	}
	
	fileprivate func update(cellProps: [CellProp<Msg>], send: @escaping (Msg) -> ()) {
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
				self.contentReconciler.send = send
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

public struct TableCellsDescriptor<CellModel, Msg> {
	fileprivate var _cellIdentifiersToTemplates = [String: TableCellTemplate<CellModel, Msg>]()
	
	public init() {}
	
	public mutating func registerCells<ReuseIdentifier>(reuseIdentifier: ReuseIdentifier, render: @escaping (CellModel) -> [CellProp<Msg>], layout: @escaping (_ cellModel: CellModel, _ context: LayoutContext) -> [NSLayoutConstraint]) {
		let reuseIdentifierString = String(describing: reuseIdentifier)
		let cellTemplate = TableCellTemplate(reuseIdentifier: reuseIdentifierString, render: render, layout: layout)
		_cellIdentifiersToTemplates[reuseIdentifierString] = cellTemplate
	}
}

public class TableAssistant<Model, CellModel, Msg> {
	public var tableView: UITableView
	public var model: Model
	private var _cellsDescriptor: TableCellsDescriptor<CellModel, Msg>
	private var _cellForRowAt: (IndexPath) -> (reuseIdentifier: String, model: CellModel)
	private var _update: (Msg, inout Model) -> ()
	
	public init(tableView: UITableView, cellsDescriptor: TableCellsDescriptor<CellModel, Msg>, cellForRowAt: @escaping (IndexPath) -> (reuseIdentifier: String, model: CellModel), initial: Model, update: @escaping (Msg, inout Model) -> ()) {
		self.tableView = tableView
		self.model = initial
		self._cellsDescriptor = cellsDescriptor
		self._cellForRowAt = cellForRowAt
		self._update = update
		
		for (reuseIdentifierString, _) in _cellsDescriptor._cellIdentifiersToTemplates {
			tableView.register(TableCellView<Msg>.self, forCellReuseIdentifier: reuseIdentifierString)
		}
	}
	
	private func send(_ message: Msg) {
		self._update(message, &self.model)
		self.rerender()
	}
	
	private func rerender() {
		guard let indexPaths = self.tableView.indexPathsForVisibleRows
			else { return }
		
		for indexPath in indexPaths {
			guard let cellView = self.tableView.cellForRow(at: indexPath) as? TableCellView<Msg>
				else { continue }
			
			let (_, cellModel) = self._cellForRowAt(indexPath)
			self.update(cellView: cellView, cellModel: cellModel)
		}
	}
	
	private func update(cellView: TableCellView<Msg>, cellModel: CellModel) {
		let template = _cellsDescriptor._cellIdentifiersToTemplates[cellView.reuseIdentifierString]!
		let cellProps = template.render(cellModel)
		cellView.update(
			cellProps: cellProps,
			send: { [weak self] in
				self?.send($0)
			}
		)
		
		let constraints = template.layout(cellModel, cellView.layoutContext)
		NSLayoutConstraint.activate(constraints)
	}
	
	public func cell(forRowAt indexPath: IndexPath) -> UITableViewCell {
		let (reuseIdentifier, cellModel) = self._cellForRowAt(indexPath)
		let cellView = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as! TableCellView<Msg>
		cellView.reuseIdentifierString = reuseIdentifier
		
		self.update(cellView: cellView, cellModel: cellModel)
		
		return cellView
	}
}
