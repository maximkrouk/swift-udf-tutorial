import Foundation

public enum BasicExample {
  // MARK: - Core implementation
  
  /// Reducer is a function that modifies state based on passed action
  /// Basically it's the component that defines system's logic
  public typealias Reducer<State, Action> = (State, Action) -> State
  
  /// Store is an object that holds a state and a reducer, it is a representation of our system,
  /// you can retrieve state from a store and send actions to modify store's state with the store's reducer
  public class Store<State, Action> {
    /// State cannot be modified from the outside, the only way to modify the state is to pass an action to the store
    private(set) public var state: State
    
    /// Reducer is a captured function for processing actions passed to the store
    /// this field is private. There is a Store.send method for the more convenient action sending
    private let reducer: Reducer<State, Action>
    
    /// Initialize the system with initial state and a reducer
    public init(
      initialState: State,
      reducer: @escaping Reducer<State, Action>
    ) {
      self.state = initialState
      self.reducer = reducer
    }
    
    /// Send function is used to pass actions to internal reducer
    public func send(_ action: Action) {
      self.state = reducer(state, action)
    }
  }
  
  // MARK: - Counter example
  
  // Declare module's state
  public struct CounterState {
    public init(value: Int) {
      self.value = value
    }
    
    public var value: Int
  }
  
  // Declare available actions
  public enum CounterAction {
    case setValue(Int)
    case increment
    case decrement
    case random
  }
  
  // Define implementation for module logic by declaring a reducer,
  // that handles actions as you want
  public static let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
    switch action {
    case .increment:
      return CounterState(value: state.value + 1)
      
    case .decrement:
      return CounterState(value: state.value - 1)
      
    case .setValue(let value):
      return CounterState(value: value)
      
    case .random:
      return CounterState(value: .random(in: (.min)...(.max)))
    }
  }
  
  // NOTE: You already defined your system's behavior,
  // even without holding to any actual data.
  // To initialize your system you should create a store,
  // but since store is just a container, you'll be able to
  // pass any initial state and any reducer to it
}

// Basic scheme of the system
//
// –––– Action –––––––┐
//                    ↓
// ┌––––––––––––––––––┬–––––┐
// | System           |     |
// |                  ↓     |
// |┌–––––––┐    ┌–––––––––┐|
// || State ├–––→| Reducer ||
// |└–––––––┘    └––––┬––––┘|
// |    ↑             |     |
// |    └– New State –┘     |
// └––––––––––––––––––––––––┘
