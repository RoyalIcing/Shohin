//
//  Codable.swift
//  Shohin
//
//  Created by Patrick Smith on 17/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit


enum ButtonElementCodingKey : String, CodingKey {
	case key
	case title
}

extension ControlElement : Decodable where Control == UIButton {
	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: ButtonElementCodingKey.self)
		self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
		
		var props = [ControlProp<Msg, Control>]()
		
		if let title = try c.decodeIfPresent(String.self, forKey: .title) {
			props.append(.title(title, for: .normal))
		}
		
		self.props = props
	}
}


enum ElementCodingKey : String, CodingKey {
	case type
	case key
	case props
}

extension Element : Decodable {
	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: ElementCodingKey.self)
		let type = try c.decode(String.self, forKey: .type)
		let key = try c.decode(String.self, forKey: .key)
		
		switch type {
		case "button":
			let controlElement = try c.decode(ControlElement<Msg, UIButton>.self, forKey: .props)
			self = controlElement.toElement()
		default:
			throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown type \(type)")
		}
		
		self.key = key
	}
}
