import Foundation
import Combine

public enum BetterErgomonics_2 {
  // MARK: - Core implementation
  
  // Lets return actions array to enable chaining
  public typealias Reducer<State, Action> = (inout State, Action) -> [Action]
  
  public class Store<State, Action> {
    /// Now we store state in a `CurrentValueSubject` to get state publisher out of the box
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
      /// Now our reducer can return new actions, that we should process
      let actions = self.reducer(&_state.value, action)
      
      /// We call send method recursively to handle all of the actions in the action chain
      actions.forEach(self.send)
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
  
  /// Now we have to always return new actions from our reducer,
  /// return [] if you don't need to process anything
  /// But now we able to chain actions and actual value modification will happen
  /// only when `.setValue` action is sent
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
// –––––––––– Action ––––––––––––>–––┬–––<–– Action ––┐
//                                   ↓                |
// ┌–––––––––––––––––––––––––––––––––┬––––––––––––––┐ |
// | System                          |              | |
// |                                 ↓              | |
// |┌–––––––┐                   ┌–––––––––┐         | |
// || State ├––– inout State ––→| Reducer ├––––>––––┼–┘
// |└–––––––┘                   └–––––––––┘         |
// └––––––––––––––––––––––––––––––––––––––––––––––––┘

// MARK: - Advanced note

extension Array {
  /// We can declare an `empty` array static getter to return it from our reducer for final actions instead of array literal
  ///
  /// If you remember CocoaHeadsBelarus first FP session, this `empty` element can be used as a base element to generalize Array as a Monoid
  /// ```
  /// protocol Semigroup {
  ///   static func +(lhs: Self, rhs: Self) -> Self
  /// }
  ///
  /// protocol Monoid: Semigroup {
  ///   static var empty: Self { get }
  /// }
  ///
  /// Array(0) + Array.empty == Array(0)
  /// Array(1, 2) + Array(3, 4) == Array(1,2,3,4)
  ///
  /// // Other types can be Monoids too if they implement some concatenation and a base element
  /// String("Hello, World!") + String.empty == String("Hello, World!")
  /// String("Hello, ") + String("World!") == String("Hello, World!")
  /// ```
  public static var empty: Array { [] }
}
