import Foundation
import Combine

/// Higher order reducers enable you to combine reducers and ergonomically add easily functionality
/// The main concept is that we create a new reducer, that wraps another one (or multiple) with some extra work
/// For now we just want to add debugging capabilities
/// ```
/// // Prints actions and state changes to console #if DEBUG
/// myReducer.debug() -> Reducer<MyState, MyAction>
/// ```

public enum HigherOrderReducers_1 {
  // MARK: - Core implementation
  
  /// Lets make a separate type for our Reducer to make it extendable
  public struct Reducer<State, Action> {
    public init(_ reducer: @escaping (inout State, Action) -> [Action]) {
      self.reducer = reducer
    }
    
    let reducer: (inout State, Action) -> [Action]
    
    public func run(_ state: inout State, _ action: Action) -> [Action] {
      self.reducer(&state, action)
    }
    
    public func callAsFunction(_ state: inout State, _ action: Action) -> [Action] {
      self.reducer(&state, action)
    }
  }
  
  @dynamicMemberLookup
  public struct StorePublisher<State>: Publisher {
    public typealias Output = State
    public typealias Failure = Never
    
    public let upstream: AnyPublisher<State, Never>
    
    // Is requried by the Publisher protocol
    public func receive<S: Subscriber>(subscriber: S)
    where S.Failure == Failure, S.Input == Output {
      upstream.receive(subscriber: subscriber)
    }
    
    public init<P: Publisher>(
      upstream: P,
      isDuplicate: @escaping (State, State) -> Bool
    ) where P.Output == Output, P.Failure == Failure {
      self.upstream = upstream
        .removeDuplicates(by: isDuplicate)
        .eraseToAnyPublisher()
    }
    
    public subscript<LocalState>(
      dynamicMember keyPath: KeyPath<State, LocalState>
    ) -> StorePublisher<LocalState>
    where LocalState: Equatable {
      StorePublisher<LocalState>(
        upstream: self.upstream.map(keyPath),
        isDuplicate: ==
      )
    }
  }
  
  public class Store<State, Action> {
    internal let _state: CurrentValueSubject<State, Never>
    
    public var state: State { _state.value }
    
    private let reducer: Reducer<State, Action>
    
    public init(
      initialState: State,
      reducer: Reducer<State, Action>
    ) {
      self._state = .init(initialState)
      self.reducer = reducer
    }
    
    public func send(_ action: Action) {
      func process(_ actions: [Action], state: inout State) {
        guard !actions.isEmpty else { return }
        actions.forEach { action in
          process(self.reducer(&state, action), state: &state)
        }
      }
      
      var currentState = state
      
      process([action], state: &currentState)
      
      self._state.value = currentState
    }
  }
  
  // MARK: - Counter example
  
  public struct CounterState: Equatable {
    public init(value: Int) {
      self.value = value
    }
    
    public var value: Int
  }
  
  public enum CounterAction {
    case setValue(Int)
    case incrementTwice
    case increment
    case decrement
    case random
    case doNothing
  }
  
  public static let counterReducer = Reducer<CounterState, CounterAction> { state, action in
    switch action {
    case .incrementTwice:
      return [.increment, .increment]
      
    case .increment:
      return [.setValue(state.value + 1)]
      
    case .decrement:
      return [.setValue(state.value - 1)]
      
    case .random:
      return [.setValue(.random(in: (.min)...(.max)))]
      
    case .setValue(let value):
      state.value = value
      return []
      
    case .doNothing:
      return []
    }
  }
  
  private static let simpleActionsCounterReducer = Reducer<CounterState, CounterAction> { state, action in
    switch action {
    case .incrementTwice:
      return [.increment, .increment]
      
    case .increment:
      return [.setValue(state.value + 1)]
      
    case .decrement:
      return [.setValue(state.value - 1)]
      
    case .random:
      return [.setValue(.random(in: (.min)...(.max)))]
      
    default:
      return []
    }
  }
  
  private static let setValueReducer = Reducer<CounterState, CounterAction> { state, action in
    switch action {
    case let .setValue(value):
      state.value = value
      return []
      
    default:
      return []
    }
  }
}

extension HigherOrderReducers_1.Store {
  public var publisher: HigherOrderReducers_1.StorePublisher<State> {
    .init(upstream: _state, isDuplicate: { _, _ in false })
  }
}

extension HigherOrderReducers_1.Store where State: Equatable {
  public var publisher: HigherOrderReducers_1.StorePublisher<State> {
    .init(upstream: _state, isDuplicate: ==)
  }
}

// MARK: - Debugging

extension HigherOrderReducers_1.Reducer {
  public func debug<LocalState>(
    _ prefix: String = "",
    state toLocalState: @escaping (State) -> LocalState,
    printer: @escaping (String) -> Void = { print($0) }
  ) -> HigherOrderReducers_1.Reducer<State, Action> {
    /// Return new debugging reducer if we are running in debug configuration
    #if DEBUG
    return .init { state, action in
      /// Save local state before modification
      let previousState = toLocalState(state)
      
      /// Run action and save chained actions
      let actions = self.run(&state, action)
      
      /// Save local state after modification
      let nextState = toLocalState(state)
      
      /// Prepare debug output for action
      var actionOutput = ""
      customDump(action, to: &actionOutput, indent: 2)
      
      /// Prepare debug output for state diff
      let stateOutput =
        LocalState.self == Void.self
        ? ""
        : diff(previousState, nextState).map { "\($0)\n" } ?? "  (No state changes)\n"
      
      /// Print output to printer
      printer(
        """
        \(prefix.isEmpty ? "" : "\(prefix): ")received action:
        \(actionOutput)
        \(stateOutput)
        """
      )
      
      /// Return chained actions
      return actions
    }
    #else
    /// If we running in release configuration - return self to avoid redundant prints
    return self
    #endif
  }
}

// Basic scheme of the system
//
// –––––––– Action ––––––––––––––––┐
//                                 ↓
// ┌–––––––––––––––––––––––––––––––┬––––––––––––––┐
// | System                        |–<– Action ––┐|
// |                               ↓             ||
// |┌–––––––┐                 ┌–––––––––┐        ||
// || State ├–– inout State–→ | Reducer ├––––>–––┘|
// |└–––––––┘                 └–––––––––┘         |
// └––––––––––––––––––––––––––––––––––––––––––––––┘
