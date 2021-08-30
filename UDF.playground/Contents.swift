import Combine
import Foundation

// MARK: - Step 0: Theory

/*
 App architecture is a part of programm design.
 Our apps are written to interact with data, get it, modify it and display it.
 
 Basically we can divide our apps in 2 layers:
  - Model layer (app logic)
  - Presentation layer (app interface)
 
 Modern apps may have up to 7+ layers for each app module,
 but at some point such a strong division may allow you to
 make separate layers very simple, but the app in general may become more and more complex.
 
 As Albert Einstein said:
 "Everything should be made as simple as possible, but no simpler"
 
 So in functional programming we can treat our logical layer just as a function of app state
 and some actions, produced by users or other actions for example.
 
 App architecture defines the structure of an application and how do
 data and control flows interact with app components.
 
 And we can build our modules as small isolated systems with some defined behavior.
 Thats called unidirectional data flow (or UDF) where our presentation layer depends only on
 system's state and the only way to modify our state is to send some predefined actions to our system
 (so we are not able to ever mutate our state directly,
 thats why the data flow is called unidirectional [from the system to our presentation])
 
      ┌––––––––––––––┐
 ┌––––┴––––┐         ↓         ┌––––––––––––––┐
 |         |←–––– Actions –––––┤              |
 | System  |                   | Presentation |
 |         ├–––––– State –––––→|              |
 └–––––––––┘                   └––––––––––––––┘
*/

// MARK: - Step 1: Basic example

// At first go to `Sources/1.BasicExample.swift` to see the implementation

// Lets write a little test for our basic example
test { assert in
  let store = BasicExample.Store(
    initialState: BasicExample.CounterState(value: 0),
    reducer: BasicExample.counterReducer
  )
  
  assert(store.state.value == 0)
  
  store.send(.increment)
  assert(store.state.value == 1)
  
  store.send(.setValue(5))
  assert(store.state.value == 5)
  
  store.send(.decrement)
  assert(store.state.value == 4)
  
  // We cannot test it yet, because our reducer reaches out to the outer world
  // to get some random value, so it's a side effect and we didn't implement
  // an instrument to handle such an effect
  store.send(.random)
  assert(store.state.value == .random(in: (.min)...(.max)))
}

/*
 So we do have some basic UDF system, but it has a few problems:
 - We can't handle side effects
 - The ergonomics is not great
    - We have to construct a whole new state every time
    - We have to cover similar logic multiple times
    - We do not have an ability to handle state changes
 
 At first lets fix the ergonomics
*/

// MARK: - Step 2: Better ergonomics 1

// At first go to `Sources/2.BetterErgonomics_1.swift` to see the implementation

// Lets write a little test for our  example
test { assert in
  let store = BetterErgomonics_1.Store(
    initialState: BetterErgomonics_1.CounterState(value: 0),
    reducer: BetterErgomonics_1.counterReducer
  )
  
  var stateValuesBuffer = [store.state.value]
  store.onStateDidSet { stateValuesBuffer.append($0.value) }
  
  assert(store.state.value == 0)
  
  store.send(.increment)
  assert(store.state.value == 1)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.setValue(5))
  assert(store.state.value == 5)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.decrement)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  
  assert(stateValuesBuffer == [0, 1, 5, 4])
  
  // NOTE: We still do not handle side effects and cannot handle `.random` action
}


// MARK: - Step 3: Better ergonomics 2

// At first go to `Sources/3.BetterErgonomics_2.swift` to see the implementation

test { assert in
  let store = BetterErgomonics_2.Store(
    initialState: BetterErgomonics_2.CounterState(value: 0),
    reducer: BetterErgomonics_2.counterReducer
  )
  
  var stateValuesBuffer: [Int] = []
  let storeCancellable = store.publisher.sink { stateValuesBuffer.append($0.value) }
  
  assert(store.state.value == 0)
  
  store.send(.increment)
  assert(store.state.value == 1)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.setValue(5))
  assert(store.state.value == 5)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.decrement)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  
  /// Now our inout modification forces inner `CurrentValueSubject` to send us an update
  /// each time we send any action, even if the state was not changed at all
  /// So when we chain actions we get multiple state changes too
  /// so for state.value == 0 call of `.increment` -> `.setValue(state.value + 1)` produces [0, 1] state publish events
  assert(stateValuesBuffer == [0, 0, 1, 5, 5, 4])
  
  store.send(.doNothing)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 0, 1, 5, 5, 4, 4])
  
  store.send(.increment)
  assert(stateValuesBuffer == [0, 0, 1, 5, 5, 4, 4, 4, 5])
  
  storeCancellable.cancel()
  
  // NOTE: We still do not handle side effects and cannot handle `.random` action
}

// MARK: - Step 4: Performance improvements 1

// At first go to `Sources/4.PerformanceImprovements_1.swift` to see the implementation

test { assert in
  let store = PerformanceImprovements_1.Store(
    initialState: PerformanceImprovements_1.CounterState(value: 0),
    reducer: PerformanceImprovements_1.counterReducer
  )
  
  var stateValuesBuffer: [Int] = []
  let storeCancellable = store.publisher.sink { stateValuesBuffer.append($0.value) }
  
  assert(store.state.value == 0)
  
  store.send(.increment)
  assert(store.state.value == 1)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.setValue(5))
  assert(store.state.value == 5)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.decrement)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  
  /// Now our inout modification still forces inner `CurrentValueSubject` to send us an update
  /// each time we send an action, but we get one published state for each event chain instead of getting
  /// a publish for each event
  assert(stateValuesBuffer == [0, 1, 5, 4])
  
  /// So if we do nothing we still get one publish
  store.send(.doNothing)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 1, 5, 4, 4])
  
  /// But we also get only one publish for chained events
  store.send(.increment)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 1, 5, 4, 4, 5])
  
  storeCancellable.cancel()
  
  // NOTE: We still do not handle side effects and cannot handle `.random` action
}

// MARK: - Step 5: Performance improvements 2

// At first go to `Sources/5.PerformanceImprovements_2.swift` to see the implementation

test { assert in
  let store = PerformanceImprovements_2.Store(
    initialState: PerformanceImprovements_2.CounterState(value: 0),
    reducer: PerformanceImprovements_2.counterReducer
  )
  
  var stateValuesBuffer: [Int] = []
  
  // Now we can map our publisher using @dynamicMember lookup
  // and also are removing duplicate states
  let storeCancellable = store.publisher.value.sink { stateValuesBuffer.append($0) }
  
  assert(store.state.value == 0)
  
  store.send(.increment)
  assert(store.state.value == 1)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.setValue(5))
  assert(store.state.value == 5)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.decrement)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  
  // Now we finaly fixed our publisher outputs and even more
  assert(stateValuesBuffer == [0, 1, 5, 4])
  
  store.send(.doNothing)
  assert(store.state.value == 4)
  assert(stateValuesBuffer == [0, 1, 5, 4])
  
  store.send(.incrementTwice)
  assert(store.state.value == 6)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 1, 5, 4, 6])
  
  // We do not get the same values redundantly published
  store.send(.setValue(6))
  assert(store.state.value == 6)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 1, 5, 4, 6])
  
  storeCancellable.cancel()
  
  // NOTE: We still do not handle side effects and cannot handle `.random` action
}

// MARK: - Step 6: Higher order reducers 1

// At first go to `Sources/6.HigherOrderReducers_1.swift` to see the implementation

test { assert in
  /// Look at the console to see debug output
  let reducer = HigherOrderReducers_1.counterReducer.debug(state: \.value)
  let store = HigherOrderReducers_1.Store(
    initialState: HigherOrderReducers_1.CounterState(value: 0),
    reducer: reducer
  )
  
  var stateValuesBuffer: [Int] = []
  let storeCancellable = store.publisher.value.sink { stateValuesBuffer.append($0) }
  
  assert(store.state.value == 0)
  
  store.send(.increment)
  assert(store.state.value == 1)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.setValue(5))
  assert(store.state.value == 5)
  assert(store.state.value == stateValuesBuffer.last)
  
  store.send(.decrement)
  assert(store.state.value == 4)
  assert(store.state.value == stateValuesBuffer.last)
  
  assert(stateValuesBuffer == [0, 1, 5, 4])
  
  store.send(.doNothing)
  assert(store.state.value == 4)
  assert(stateValuesBuffer == [0, 1, 5, 4])
  
  store.send(.incrementTwice)
  assert(store.state.value == 6)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 1, 5, 4, 6])
  
  store.send(.setValue(6))
  assert(store.state.value == 6)
  assert(store.state.value == stateValuesBuffer.last)
  assert(stateValuesBuffer == [0, 1, 5, 4, 6])
  
  storeCancellable.cancel()
  
  // NOTE: We still do not handle side effects and cannot handle `.random` action
}
