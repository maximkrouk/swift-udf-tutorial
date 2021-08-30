import Foundation
import Combine

public enum PerformanceImprovements_1 {
  // MARK: - Core implementation
  
  public typealias Reducer<State, Action> = (inout State, Action) -> [Action]
  
  public class Store<State, Action> {
    private let _state: CurrentValueSubject<State, Never>
    
    public var state: State { _state.value }
    public var publisher: AnyPublisher<State, Never> { _state.eraseToAnyPublisher() }
    
    private let reducer: Reducer<State, Action>
    
    public init(
      initialState: State,
      reducer: @escaping Reducer<State, Action>
    ) {
      self._state = .init(initialState)
      self.reducer = reducer
    }
    
    public func send(_ action: Action) {
      // Recursively process our actions chain
      func process(_ actions: [Action], state: inout State) {
        guard !actions.isEmpty else { return }
        actions.forEach { action in
          process(self.reducer(&state, action), state: &state)
        }
      }
      
      // Lets copy our current state and update it only after all of our actions chain is processed
      var currentState = state
      
      // Pass first actions to our processor
      process([action], state: &currentState)
      
      // Update actual state
      self._state.value = currentState
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
    case doNothing
  }
  
  public static let counterReducer: Reducer<CounterState, CounterAction> = { state, action in
    switch action {
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

// Basic scheme of the system
//
// ––––––––––– Action –––––––––––––––┐
//                                   ↓
// ┌–––––––––––––––––––––––––––––––––┬––––––––––––––┐
// | System                          |–<– Action ––┐|
// |                                 ↓             ||
// |┌–––––––┐                   ┌–––––––––┐        ||
// || State ├––– inout State ––→| Reducer ├––––>–––┘|
// |└–––––––┘                   └–––––––––┘         |
// └––––––––––––––––––––––––––––––––––––––––––––––––┘
