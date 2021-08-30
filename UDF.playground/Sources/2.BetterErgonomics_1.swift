import Foundation

public enum BetterErgomonics_1 {
  // MARK: - Core implementation
  
  /// The equivalent for function signature of `(T) -> T` is `(inout T) -> Void`
  /// The same works for `(T, U) -> T` and `(inout T, U) -> Void`
  /// So we can replace our reducer signature with an equivalent one, so we are able to modify our state without
  /// reconstructing every field of only a part of the state should be modified.
  ///
  /// See more about inout parameters
  /// https://docs.swift.org/swift-book/LanguageGuide/Functions.html#ID173
  /// https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID545
  public typealias Reducer<State, Action> = (inout State, Action) -> Void
  
  public class Store<State, Action> {
    /// Now we can handle state changes via didSet block
    private(set) public var state: State {
      didSet { _onStateDidSet?(state) }
    }
    
    /// Declare a handler for state changes, each time a new state is set, we get the specified callback
    private var _onStateDidSet: ((State) -> Void)?
    public func onStateDidSet(perform action: ((State) -> Void)?) {
      self._onStateDidSet = action
    }
    
    private let reducer: Reducer<State, Action>
    
    public init(
      initialState: State,
      reducer: @escaping Reducer<State, Action>
    ) {
      self.state = initialState
      self.reducer = reducer
    }
    
    public func send(_ action: Action) {
      /// Now our reducer modifies our state as an inout parameter,
      /// so it will be much more convenient to declare system's logic
      self.reducer(&state, action)
    }
  }
  
  // MARK: - Counter example
  
  public struct CounterState {
    public init(value: Int) {
      self.value = value
    }
    
    public var value: Int
  }
  
  public enum CounterAction {
    case setValue(Int)
    case increment
    case decrement
    case random
  }
  
  public static let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
    switch action {
    case .increment:
      // We don't have to create a new state from scratch
      // New state is created by inout parameter, based on modification
      // all of unchanged fields will remain the same
      state.value += 1
      
    case .decrement:
      state.value -= 1
      
    case .setValue(let value):
      state.value = value
      
    case .random:
      state.value = .random(in: (.min)...(.max))
    }
  }
}

// Basic scheme of the system
//
// –––––––– Action ––––––––––––––––┐
//                                 ↓
// ┌–––––––––––––––––––––––––––––––┬–––––┐
// | System                        |     |
// |                               ↓     |
// |┌–––––––┐                 ┌–––––––––┐|
// || State ├–– inout State–→ | Reducer ||
// |└–––––––┘                 └–––––––––┘|
// └–––––––––––––––––––––––––––––––––––––┘
