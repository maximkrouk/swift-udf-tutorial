/// Test helper
///
/// Usage:
/// ```
/// test { assert in
///  assert(1 == 2)
/// }
/// ```
@discardableResult
public func test(_ handler: ((Bool) -> String) -> Void) -> String {
  var result: [Bool] = []
  handler { assert in
    result.append(assert)
    return assert ? "✅" : "❌"
  }
  let badge = result.contains(true)
    ? result.allSatisfy { $0 } ? "✅" : "⚠️"
    : "❌"
  let successfulAssertsCount = result.filter { $0 }.count
  return "\(badge) [\(successfulAssertsCount) of \(result.count) assertions succeed]"
}
