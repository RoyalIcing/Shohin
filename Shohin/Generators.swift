//
//  Generators.swift
//  Shohin
//
//  Created by Patrick Smith on 16/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


public class RandomGenerator<Msg> {
	let toMessage : (Int) -> Msg
	
	public init(toMessage: @escaping (Int) -> Msg) {
		self.toMessage = toMessage
	}
	
	public func generate(min: Int, max: Int) -> Command<Msg> {
		let toMessage = self.toMessage
		return Command(store: Command.Storage.routine({
			let value = min + Int(arc4random_uniform(UInt32(max - min + 1)))
			return toMessage(value)
		}))
	}
}
