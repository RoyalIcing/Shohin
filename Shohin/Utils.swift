//
//  Utils.swift
//  Shohin
//
//  Created by Patrick Smith on 29/6/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


public class ChangeApplier<Root> {
	private var applier: (Root) -> ()
	
	init(applier: @escaping (Root) -> ()) {
		self.applier = applier
	}
	
	public convenience init<Value>(_ keyPath: ReferenceWritableKeyPath<Root, Value>, value: Value) {
		self.init(applier: { root in
			root[keyPath: keyPath] = value
		})
	}
	
	public func apply(to root: Root) {
		applier(root)
	}
}

extension ChangeApplier where Root : AnyObject {
	public convenience init(makeChanges: @escaping (Root) -> ()) {
		self.init(applier: makeChanges)
	}
}
