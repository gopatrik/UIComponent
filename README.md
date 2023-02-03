# UIComponent

### Write UI in crazy speed, with great perf & no limitations.

**SwiftUI** still hasn't satisfied my requirements. So I built this.

This framework allows you to build UI using UIKit with syntax similar to SwiftUI. You can think about this as an improved `UICollectionView`.

### Highlights:
* Great performance through global cell reuse.
* Built in layouts including `Stack`, `Flow`, & `Waterfall`.
* Declaritive API based on `resultBuilder` and modifier syntax.
* Work seemless with existing UIKit views, viewControllers, and transitions.
* `dynamicMemberLookup` support for all ViewComponents which can help you easily update your UIKit views.
* `Animator` API to apply animations when cells are being moved, updated, inserted, or deleted.
* Simple architecture for anyone to be able to understand.
* Easy to create your own Components.
* No state management or two-way binding.

## Production Apps that use UIComponent
* ### [Noto](https://apps.apple.com/us/app/noto-elegant-note/id1459055246)
  Noto uses **UIComponent** for all of the UI including the text editor. The text editor view is a `ComponentScrollView` with each line rendered as a cell through a custom component. This app showcases the level of flexibility that this framework has compares to SwiftUI. I personally use some SwiftUI in my app, but most of the time, I fallback to UIKit to drill down the exact look and feel that I want while also provide great performance. 
 
  <em>Definitely let me know if you know how to create a custom text view using SwiftUI, if that ever becomes a reality, I would probably switch completely.</em>

* ### [Ink](https://apps.apple.com/us/app/ink-note-sketch-annotation/id1499301117)

## How to use

At its core, it provides two `UIView` subclasses: `ComponentView` and `ComponentScrollView`.

These two classes takes in a `component` parameter where you use to construct your UI using declarative syntax. You can also apply modifiers to these components to treak them further.

For example:
<img align="right"  width=140 src="https://user-images.githubusercontent.com/3359850/124366505-35c54500-dc05-11eb-8611-d70437c627c7.gif" />
```swift
componentView.component =  VStack(spacing: 8) {
  for (index, cardData) in cards.enumerated() {
    Card(card: cardData) { [unowned self] in
      self.cards.remove(at: index)
    }
  }
  AddCardButton { [unowned self] in
    self.cards.append(CardData(title: "Item \(self.newCardIndex)",
                               subtitle: "Description \(self.newCardIndex)"))
    self.newCardIndex += 1
  }
}.inset(20)
```

Checkout the example project for more in-depth examples.

## Built in components

### Layouts

* `VStack`
* `HStack`
* `Waterfall`
* `Flow`

### View

* `Text`
* `Image`
* `Separator`

### Utility

* `ForEach`
* `Space`
* `Join`

### Useful modifiers

* `.inset()`
* `.size()`
* `.background()`
* `.overlay()`
* `.flex()`
* `.view()`
* `.tappableView()`
* `.scrollView()`

## WIP
