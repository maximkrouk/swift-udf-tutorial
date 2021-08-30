import Foundation
import Combine

public enum PerformanceImprovements_2 {
  // MARK: - Core implementation
  
  public typealias Reducer<State, Action> = (inout State, Action) -> [Action]
  
  /// We can make some optimizations by creating a publisher that will filter all state update events if the actual state wasn't changed
  /// A publisher of store state will take upstream publisher and a equality function to determine if new state is a duplicate
  /// See the very bottom of the file to see new `publisher` property declarations
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
    
    /// This method will allow you to keep removing duplicates when mapping the publisher to substates
    /// Example:
    /// ```
    /// State {
    ///   substate: Substate {
    ///     value
    ///   }
    /// }
    ///
    /// publisher.state.substate.value.sink { print($0) } // Here you will get values only if the actual value changed
    /// ```
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
      reducer: @escaping Reducer<State, Action>
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
  
  public static let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
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
}

extension PerformanceImprovements_2.Store {
  /// Always publish new state on set if it is not equatable
  public var publisher: PerformanceImprovements_2.StorePublisher<State> {
    .init(upstream: _state, isDuplicate: { _, _ in false })
  }
}

extension PerformanceImprovements_2.Store where State: Equatable {
  /// Compare equatable states by default == function
  public var publisher: PerformanceImprovements_2.StorePublisher<State> {
    .init(upstream: _state, isDuplicate: ==)
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
