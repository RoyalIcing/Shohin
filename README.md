# Shohin [![Build Status](https://travis-ci.org/RoyalIcing/Shohin.svg?branch=master)](https://travis-ci.org/RoyalIcing/Shohin)

Pragmatic React/Elm-like components & state management for iOS.

## Philosophy

- Completely opt-in: mix and match with normal iOS code.
- Pragmatic: integrates with instead of trying to replace UIKit. Keep using view controllers.
- Extensible: create your own view elements or commands.

## Usage

First, we import the Shohin library. We are going to build a number counter, with buttons to increment and decrement. There will also a random button to choose a random number, and a text field to let the user choose their own number.

Without any of the interface, what our data model boils down to is a single number, which we can store as an `Int`.

We declare our data model `CounterModel`. Here we use a `struct` with an `Int` variable that will store our counter.

Our message `CounterMsg` has four possible choices for the different user interactions that will change the model. One to increment by 1, on to decrement by 1, one to completely change the counter to a specified `Int`, and another to change it to a random number.

~~~swift
import Shohin

struct CounterModel {
	var counter: Int = 0
}

enum CounterMsg {
	case increment()
	case decrement()
	case setCounter(to: Int)
	case randomize()
}
~~~

Let's connect the model to the message with an update function, which takes a message and makes changes to the model.

~~~swift
let randomInt = RandomGenerator(toMessage: CounterMsg.setCounter)

func update(message: CounterMsg, model: inout CounterModel) -> Command<CounterMsg> {
	switch message {
	case .increment():
		model.counter += 1
	case .decrement():
		model.counter -= 1
	case let .setCounter(newValue):
		model.counter = newValue
	case .randomize():
	  // Returns command to generate a random number
		return randomInt.generate(min: 0, max: 10)
	}
	
	return [] // No command
}
~~~

For `.randomize()`, we use a random generator here named `randomInt`. This is set up to send `CounterMsg.setCounter(to:)` with the generated random number passed in. It’s similar to a callback.

Let’s make a UI so people can view the model, and make changes to update it. Here we are making labels, fields, and buttons.

We identify each element that the user interacts with using the `CounterKey` string enum.

~~~swift
enum CounterKey: String {
	case counter, increment, decrement, randomize, counterField
}

func render(model: CounterModel) -> [Element<CounterMsg>] {
	return [
		label(CounterKey.counter, [
			.text("Counter:"),
			.textAlignment(.center),
		]),
		field(CounterKey.counterField, [
			.text("\(model.counter)"),
			.onChange { CounterMsg.setCounter(to: $0.text.flatMap(Int.init) ?? 0) }
		]),
		button(CounterKey.increment, [
			.title("Increment", for: .normal),
			.onPress(CounterMsg.increment),
		]),
		button(CounterKey.decrement, [
			.title("Decrement", for: .normal),
			.onPress(CounterMsg.decrement),
			.set(\.tintColor, to: UIColor.red),
		]),
		button(CounterKey.randomize, [
			.title("Randomize", for: .normal),
			.onPress(CounterMsg.randomize),
		]),
	]
}
~~~

We can use AutoLayout too, making constraints between each UI element, and to the superview’s margins guide.

~~~swift
func layout(model: CounterModel, context: LayoutContext) -> [NSLayoutConstraint] {
	let margins = context.marginsGuide
	let counterView = context.view(CounterKey.counter)!
	let decrementButton = context.view(CounterKey.decrement)!
	let incrementButton = context.view(CounterKey.increment)!
	let randomizeButton = context.view(CounterKey.randomize)!
	return [
		counterView.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterView.topAnchor.constraint(equalTo: margins.topAnchor),
		decrementButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
	]
}
~~~

Now let's get everything connected and running.

~~~swift
let mainView = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
mainView.backgroundColor = #colorLiteral(red: 0.239215686917305, green: 0.674509823322296, blue: 0.968627452850342, alpha: 1.0)
		
// In a UIViewController, you would write the below in `viewDidLoad()`.
let program = Program(view: mainView, model: CounterModel(), initialCommand: [], update: update, render: render, layout: layout)
~~~

We now have an interactive app! In summary:

1. You have a **model**, which is presented (**rendered** and **laid out**) to the user as views.
2. Interactions that the user makes (UI events) produce **messages**, which **update** the model.
3. These **updates** cause the views to be **rendered** and **laid out** again.

## Glossary

- Model: the stored representation of your app's state. Usually a struct.
- Message: requests to change the model. Usually an enum.
- View element: value which represents a view (UIView / UIButton / UILabel etc) and its properties (‘props’)
- render: function implemented to take the current model and return view elements to be displayed to the user.
- layout: function implemented to take the current model and a context to the rendered views, and return an array of `NSLayoutConstraint` constraining the rendered view to each other and their containing superview.
- update: function implemented to take the current model and a message to change the model. You mutate the model, and after your render and layout functions will be called again to update the views.
- Program: connects all of the above into a running cycle of rendering, layout, respond to user input, and updating the model.
