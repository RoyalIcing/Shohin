# Shohin

The Elm architecture in Swift for building iOS apps.

## Usage

- Model: the stored representation of your app's state. Likely a struct.
- Message: requests to change the model. Likely an enum.

~~~swift
import Shohin

struct CounterModel {
	var counter: Int = 0
}

enum CounterMsg {
	case increment()
	case decrement()
	case randomize()
	case setCounter(to: Int)
}
~~~

OK, let's connect the two with an update function, that takes a message and makes changes to a model.

~~~swift
let intGenerator = RandomGenerator(toMessage: CounterMsg.setCounter)

func update(message: CounterMsg, u: inout Change<CounterModel, CounterMsg>) {
	switch message {
	case .increment():
		u.model.counter += 1
	case .decrement():
		u.model.counter -= 1
	case .randomize():
		u.send(intGenerator.generate(min: 0, max: 10))
	case let .setCounter(newValue):
		u.model.counter = newValue
	}
}
~~~

(Note: we also have a random generator here named `intGenerator`. In `update()`, the `.randomize` case calls `intGenerator.generate(min: 0, max: 10)`, which makes a command to later send a `.setCounter` message with the randomly generated number.)

Let's make a UI so people can view the model, and make changes to update it. Here we are making labels, fields, and buttons.

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
		
let program = Program(view: mainView, model: CounterModel(), initialCommand: [], update: update, render: render, layout: layout)
~~~

We now have an interactive app. In summary:

1. You have a **model**, which is presented (**rendered** and **laid out**) to the user as views.
2. Interactions that the user makes (UI events) produce **messages**, which **update** the model.
3. These **updates** cause the views to be **rendered** and **laid out** again.
