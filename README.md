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

## UIView Docs

### Program

```swift
class Program<Model, Msg> {
  init(
    view: UIView,
    model: Model,
    initialCommand: Command<Msg> = default,
    update: @escaping (Msg, inout Model) -> Command<Msg> = default,
    render: @escaping (Model) -> [ViewElement<Msg>] = default,
    layoutGuideForKey: @escaping (String) -> UILayoutGuide? = default,
    layout: @escaping (Model, LayoutContext) -> [NSLayoutConstraint] = default
  )

  var model: Model { get }

  func send(_ message: Msg)
}
```

### View Element

```swift
struct ViewElement<Msg> {
  typealias MakeView = (UIView?) -> UIView
  typealias ViewAndRegisterEventHandler = (UIView, (String, MessageMaker<Msg>, EventHandlingOptions) -> (Any?, Selector)) -> ()

  var key: String { get set }
  var makeViewIfNeeded: MakeView { get set }
  var applyToView: ViewAndRegisterEventHandler { get set }

  init(
    key: String,
    makeViewIfNeeded: @escaping MakeView,
    applyToView: @escaping ViewAndRegisterEventHandler
  )
}
```

### Props

```swift
protocol ViewProp {
  associatedtype View : UIView

  static func set<Value>(_ keyPath: ReferenceWritableKeyPath<View, Value>, to value: Value) -> Self
}

extension ViewProp {
  static func tag(_ tag: Int) -> Self
}
```

#### UILabel

```swift
enum LabelProp<Msg> : ViewProp {
  typealias View = UILabel

  case text(String)
  case textAlignment(NSTextAlignment)
  case applyChange(ChangeApplier<UILabel>)
}

func label<Key, Msg>(_ key: Key, _ props: [LabelProp<Msg>]) -> ViewElement<Msg>
```

#### UITextField

```swift
enum FieldProp<Msg> : ViewProp {
  typealias View = UITextField

  case text(String)
  case textAlignment(NSTextAlignment)
  case placeholder(String?)
  case keyboardType(UIKeyboardType)
  case returnKeyType(UIReturnKeyType)
  case applyChange(ChangeApplier<UITextField>)
  case on(UIControlEvents, toMessage: ((UITextField, UIEvent) -> Msg)?)
}

func field<Key, Msg>(_ key: Key, _ props: [FieldProp<Msg>]) -> ViewElement<Msg>
```

#### UIControl

```swift
enum ControlProp<Msg, Control: UIControl> : ViewProp {
  typealias View = Control

  case on(UIControlEvents, toMessage: (Control, UIEvent) -> Msg)
  case applyChange(ChangeApplier<Control>, stage: Int)

  static func set<Value>(_ keyPath: ReferenceWritableKeyPath<Control, Value>, to value: Value, stage: Int) -> ControlProp
}

func control<Key, Msg, Control: UIControl>(_ key: Key, _ props: [ControlProp<Msg, Control>]) -> ViewElement<Msg>
```

#### UIButton

```swift
extension ControlProp where Control : UIButton {
  static func title(_ title: String, for controlState: UIControlState) -> ControlProp
  static func onPress(_ makeMessage: @escaping () -> Msg) -> ControlProp
}

func button<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UIButton>]) -> ViewElement<Msg>
```

#### UISlider

```swift
extension ControlProp where Control : UISlider {
  static func value(_ value: Float) -> ControlProp
  static func minimumValue(_ value: Float) -> ControlProp
  static func maximumValue(_ value: Float) -> ControlProp
  static var isContinuous: ControlProp
}

func slider<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UISlider>]) -> ViewElement<Msg>
```

#### UIStepper

```swift
extension ControlProp where Control : UIStepper {
  static func value(_ value: Double) -> ControlProp
  static func minimumValue(_ value: Double) -> ControlProp
  static func maximumValue(_ value: Double) -> ControlProp
  static var isContinuous: ControlProp
}

func stepper<Key, Msg>(_ key: Key, _ props: [ControlProp<Msg, UIStepper>]) -> ViewElement<Msg>
```

#### UISegmentedControl

```swift
struct Segment {
  enum Content {
    case title(String)
    case image(UIImage)
  }

  var key: String { get set }
  var content: Content { get set }
  var enabled = true { get set }
  var width: CGFloat = 0 { get set }
}

func segment<Key>(_ key: Key, _ content: Segment.Content, enabled: Bool = true, width: CGFloat = 0.0) -> Segment

extension UISegmentedControl {
  var selectedSegmentKey: String! { get }
}

enum SegmentedControlProp<Msg> : ViewProp {
  typealias View = UISegmentedControl

  case selectedKey(String)
  case segments([Segment])
  case applyChange(ChangeApplier<UISegmentedControl>)
  case on(UIControlEvents, toMessage: ((UISegmentedControl, UIEvent) -> Msg)?)
}

func segmentedControl<Key, Msg>(_ key: Key, _ props: [SegmentedControlProp<Msg>]) -> ViewElement<Msg>
```

#### For custom views

Add your own `static func` to an extension: `extension CustomViewProp where CustomView : YourViewClass {}` 

```swift
enum CustomViewProp<Msg, CustomView: UIView> : ViewProp {
  typealias View = CustomView

  case backgroundColor(CGColor?)
  case applyChange(ChangeApplier<CustomView>)
}

func customView<Key, Msg, CustomView: UIView>(_ key: Key, _ viewClass: CustomView.Type, _ props: [CustomViewProp<Msg, CustomView>]) -> ViewElement<Msg>
```

### Event handling

```swift
class MessageMaker<Msg> {
  init(event makeMessage: @escaping (UIEvent) -> Msg)
  init<Control: UIControl>(control makeMessage: @escaping (Control, UIEvent) -> Msg)
  init()
}

struct EventHandlingOptions {
  var resignFirstResponder: Bool { get set }

  init(
    resignFirstResponder: Bool = false
  )
}
```

### Layout

```swift
class LayoutContext {
  var marginsGuide: UILayoutGuide { get }
  var safeAreaGuide: UILayoutGuide { get }
  var readableContentGuide: UILayoutGuide { get }
  var view: UIView { get }

  func view<Key>(_ key: Key) -> UIView?
  func guide<Key>(_ key: Key) -> UILayoutGuide?
}
```

### UITableView (alpha: subject to change)

- Model: the data used to render the table
- Item: the data representing a cell
- Msg: changes sent by rendered elements in the table
- `class TableAssistant`: used to render cells in a `UITableView`

```swift
public class TableAssistant<Model, Item, Msg> {
  public var tableView: UITableView
  public var model: Model

  public init(tableView: UITableView, initial: Model, update: @escaping (Msg, inout Model) -> ())

  public func registerCells<ReuseIdentifier>(reuseIdentifier: ReuseIdentifier, render: @escaping (Item) -> [CellProp<Msg>], layout: @escaping (_ item: Item, _ context: LayoutContext) -> [NSLayoutConstraint], tableView: UITableView)

  public func cell<ReuseIdentifier>(_ reuseIdentifier: ReuseIdentifier, _ item: Item, tableView: UITableView) -> UITableViewCell
}
```

#### Using with a `UITableViewController` subclass

```swift
struct Model {
  // …
}

enum CellIdentifier : String {
  case red
  case orange
  case blue

  static let allCases: [CellIdentifier] = [
    .red,
    .orange,
    .blue
  ]
}

enum MyMsg {
  case copyText(String)
}

private struct MyItem {
  // …
}

extension CellIdentifier {
  enum ElementKey : String {
    case label
    case button
  }

  func render(item: MyItem) -> [CellProp<MyMsg>] {
    switch self {
    case .red:
      return [
        .backgroundColor(UIColor.red),
      ]
    case .orange:
      return [
        .backgroundColor(UIColor.orange),
        .content([
          label(ElementKey.label, [
            .text("Orange"),
            .set(\.textColor, to: black),
          ]),
          button(ElementKey.button, [
            .title("Orange", for: .normal),
            .set(\.font, to: UIFont.boldSystemFont(ofSize: UIFont.buttonFontSize)),
            .onPress { .copyText("Orange") }
          ])
        ])
      ]
    case .blue:
      return [
        .backgroundColor(UIColor.blue),
        .content([
          label(ElementKey.label, [
            .text("Blue"),
            .set(\.textColor, to: black),
          ]),
          button(ElementKey.button, [
            .title("Blue", for: .normal),
            .set(\.font, to: UIFont.boldSystemFont(ofSize: UIFont.buttonFontSize)),
            .onPress { .copyText("Blue") }
          ])
        ])
      ]
    }
  }
}

func layout(item: MyItem, context: LayoutContext) -> [NSLayoutConstraint] {
  return [ … ]
}

func update(message: MyMsg, model: inout Model) {
  switch message {
  case let .copyText(text):
    UIPasteboard.general.string = text
  }
}

class MyTableViewController: UITableViewController {
  private var tableAssistant: TableAssistant<Model, MyItem, MyMsg>!

  override func viewDidLoad() {
    super.viewDidLoad()

    let tableView = self.tableView!
    tableView.allowsSelection = false
    // etc

    self.tableAssistant = TableAssistant<Model, MyItem, MyMsg>(tableView: tableView, initial: Model(), update: update)

    for cellIdentifier in CellIdentifier.allCasess {
      tableAssistant.registerCells(reuseIdentifier: cellIdentifier, render: cellIdentifier.render, layout: cellIdentifier.layout, tableView: tableView)
    }
    
    tableView.reloadData()
  }

  // MARK: Table data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    // …
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionIndex: Int) -> Int {
    // …
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellIdentifier = // …
    let item = // …
    return tableAssistant.cell(cellIdentifier, item, tableView: tableView)
  }
}
```
