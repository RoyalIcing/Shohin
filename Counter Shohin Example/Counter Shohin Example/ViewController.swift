//
//  ViewController.swift
//  Counter Shohin Example
//
//  Created by Patrick Smith on 15/5/18.
//  Copyright © 2018 Royal Icing. All rights reserved.
//

import UIKit
import Shohin

class ViewController: UIViewController {
	
	var program: Program<CounterModel, CounterMsg>!

	override func viewDidLoad() {
		super.viewDidLoad()
		
		let view = self.view!
//		view.backgroundColor = UIColor.red
		view.tintColor = UIColor.red
		
		self.program = Program(view: view, model: CounterModel(), initialCommand: [], update: updateCounter, render: renderCounter, layout: layoutCounter)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


}

