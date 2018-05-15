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
	case setMultiplier(to: String)
	case reset()
}
~~~

OK, let's connect the two with an update function, that takes a message and makes changes to a model.

~~~swift
func update(message: CounterMsg, u: inout Update<CounterModel, CounterMsg>) -> () {
	switch message {
	case .increment():
		u.model.counter += 1
	case .decrement():
		u.model.counter -= 1
	case .randomize():
		u.send(generator10.command)
	case let .setCounter(newValue):
		u.model.counter = newValue
	case let .setMultiplier(input):
		u.model.multiplier = Int(input)
	case .reset():
		u.model.counter = 0
		u.model.multiplier = 1
	}
}
~~~

Let's make a UI so people can view the model, and make changes to update it. Here we are making labels, fields, and buttons.

We identify each element that the user interacts with using a key enum.

~~~swift
enum CounterKey: String {
	case counter, increment, decrement, randomize, counterField, multiplierField
}

func view(model: CounterModel) -> [Element<CounterMsg>] {
	return [
		label(CounterKey.counter, [
			.tag(1),
			.text("\(model.counter)"),
			.textAlignment(.center),
			]),
		field(CounterKey.counterField, [
			.tag(2),
			.text("\(model.counter)"),
			.onChange { CounterMsg.setCounter(to: $0.text.flatMap(Int.init) ?? 0) }
			]),
		button(CounterKey.increment, [
			.tag(3),
			.title("Increment", for: .normal),
			.onTouchUpInside { _ in CounterMsg.increment() },
			]),
		button(CounterKey.decrement, [
			.tag(4),
			.title("Decrement", for: .normal),
			.onTouchUpInside({ _ in CounterMsg.decrement() }),
			.set(\.tintColor, to: UIColor.red),
			]),
		button(CounterKey.randomize, [
			.tag(5),
			.title("Randomize", for: .normal),
			.onTouchUpInside({ _ in CounterMsg.randomize() }),
			]),
		field(CounterKey.multiplierField, [
			.tag(6),
			.text(model.multiplier.map {"\($0)"} ?? ""),
			.onChange { CounterMsg.setMultiplier(to: $0.text ?? "") }
			]),
	]
}
~~~

We can use Autolayout too, making constraints between each UI element.

~~~swift
func layout(model: CounterModel, superview: UIView, viewForKey: (String) -> UIView?) -> [NSLayoutConstraint] {
	let margins = superview.layoutMarginsGuide
	let counterView = viewForKey(CounterKey.counter.rawValue)
	let multiplierField = viewForKey(CounterKey.multiplierField.rawValue)
	let decrementButton = viewForKey(CounterKey.decrement.rawValue)
	let incrementButton = viewForKey(CounterKey.increment.rawValue)
	let randomizeButton = viewForKey(CounterKey.randomize.rawValue)
	return [
		counterView?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		counterView?.topAnchor.constraint(equalTo: margins.topAnchor),
		multiplierField?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		multiplierField?.topAnchor.constraint(equalTo: counterView!.bottomAnchor),
		decrementButton?.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
		decrementButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		incrementButton?.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
		incrementButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
		randomizeButton?.centerXAnchor.constraint(equalTo: margins.centerXAnchor),
		randomizeButton?.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
	].compactMap{ $0 }
}
~~~

Now let's get everything connected and running.

~~~swift
let mainView = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
mainView.backgroundColor = #colorLiteral(red: 0.239215686917305, green: 0.674509823322296, blue: 0.968627452850342, alpha: 1.0)
		
let program = Program(view: mainView, model: CounterModel(), initialCommand: [], update: update, render: view, layout: layout)
~~~

That's it! You have a model, which is presented as a view. Interactions produce messages which then update the model. This causes the view to be refreshed.
