//
//  Tracking.swift
//  Shohin
//
//  Created by Patrick Smith on 20/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import Foundation


public protocol Trackable {
	associatedtype Value
	
	var value: Value { get set }
	
	func sameVersion(as other: Self) -> Bool
}


public struct MonotonicClock : Equatable {
	private var counter: Int64
	
	public init() {
		self.counter = 0
	}
	
	mutating func increment() {
		counter += 1
	}
	
	public static func ==(_ a: MonotonicClock, _ b: MonotonicClock) -> Bool {
		return a.counter == b.counter
	}
	
	public static func >(_ a: MonotonicClock, _ b: MonotonicClock) -> Bool {
		return a.counter > b.counter
	}
}

public struct MonotonicallyTracked<Value> : Trackable {
	public var clock: MonotonicClock
	public var value: Value {
		didSet {
			clock.increment()
		}
	}
	
	public init(_ value: Value, clock: MonotonicClock = MonotonicClock()) {
		self.clock = clock
		self.value = value
	}
	
	public func sameVersion(as other: MonotonicallyTracked<Value>) -> Bool {
		return self.clock == other.clock
	}
	
	public func hasChangeSince(_ clock: MonotonicClock) -> Bool {
		return self.clock > clock
	}
}
