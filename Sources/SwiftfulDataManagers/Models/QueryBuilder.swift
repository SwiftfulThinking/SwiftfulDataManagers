//
//  QueryBuilder.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Query builder for constructing database queries with filters, ordering, limiting, and pagination.
/// Operations are preserved in the exact order they are chained.
///
/// Example:
/// ```swift
/// let query = QueryBuilder()
///     .where("city", isEqualTo: "NYC")
///     .order(by: "age", descending: true)
///     .limit(to: 10)
///     .start(after: [25])
/// ```
public final class QueryBuilder: @unchecked Sendable, Equatable {
    private var operations: [QueryOperation] = []

    public init() {}

    public static func == (lhs: QueryBuilder, rhs: QueryBuilder) -> Bool {
        lhs.operations == rhs.operations
    }

    // MARK: - Equality Operators

    /// Filter where field equals value
    @discardableResult
    public func `where`(_ field: String, isEqualTo value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .isEqualTo, value: value)))
        return self
    }

    /// Filter where field does not equal value
    @discardableResult
    public func `where`(_ field: String, isNotEqualTo value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .isNotEqualTo, value: value)))
        return self
    }

    // MARK: - Comparison Operators

    /// Filter where field is greater than value
    @discardableResult
    public func `where`(_ field: String, isGreaterThan value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .isGreaterThan, value: value)))
        return self
    }

    /// Filter where field is greater than or equal to value
    @discardableResult
    public func `where`(_ field: String, isGreaterThanOrEqualTo value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .isGreaterThanOrEqualTo, value: value)))
        return self
    }

    /// Filter where field is less than value
    @discardableResult
    public func `where`(_ field: String, isLessThan value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .isLessThan, value: value)))
        return self
    }

    /// Filter where field is less than or equal to value
    @discardableResult
    public func `where`(_ field: String, isLessThanOrEqualTo value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .isLessThanOrEqualTo, value: value)))
        return self
    }

    // MARK: - Array Operators

    /// Filter where field array contains value
    @discardableResult
    public func `where`(_ field: String, arrayContains value: any DMCodableSendable) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .arrayContains, value: value)))
        return self
    }

    /// Filter where field array contains any of the values
    @discardableResult
    public func `where`<V: DMCodableSendable>(_ field: String, arrayContainsAny values: [V]) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .arrayContainsAny, value: values)))
        return self
    }

    /// Filter where field is in array of values
    @discardableResult
    public func `where`<V: DMCodableSendable>(_ field: String, `in` values: [V]) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .in, value: values)))
        return self
    }

    /// Filter where field is not in array of values
    @discardableResult
    public func `where`<V: DMCodableSendable>(_ field: String, notIn values: [V]) -> QueryBuilder {
        operations.append(.filter(QueryFilter(field: field, operator: .notIn, value: values)))
        return self
    }

    // MARK: - Ordering

    /// Order results by field (ascending)
    @discardableResult
    public func order(by field: String) -> QueryBuilder {
        operations.append(.order(QueryOrder(field: field)))
        return self
    }

    /// Order results by field with specified direction
    @discardableResult
    public func order(by field: String, descending: Bool) -> QueryBuilder {
        operations.append(.order(QueryOrder(field: field, descending: descending)))
        return self
    }

    // MARK: - Limiting

    /// Limit results to the first N documents
    @discardableResult
    public func limit(to value: Int) -> QueryBuilder {
        operations.append(.limit(value))
        return self
    }

    /// Limit results to the last N documents
    @discardableResult
    public func limit(toLast value: Int) -> QueryBuilder {
        operations.append(.limitToLast(value))
        return self
    }

    // MARK: - Cursors

    /// Start results at the provided cursor values (inclusive)
    @discardableResult
    public func start(at values: [any DMCodableSendable]) -> QueryBuilder {
        operations.append(.startAt(QueryCursor(values: values)))
        return self
    }

    /// Start results after the provided cursor values (exclusive)
    @discardableResult
    public func start(after values: [any DMCodableSendable]) -> QueryBuilder {
        operations.append(.startAfter(QueryCursor(values: values)))
        return self
    }

    /// End results at the provided cursor values (inclusive)
    @discardableResult
    public func end(at values: [any DMCodableSendable]) -> QueryBuilder {
        operations.append(.endAt(QueryCursor(values: values)))
        return self
    }

    /// End results before the provided cursor values (exclusive)
    @discardableResult
    public func end(before values: [any DMCodableSendable]) -> QueryBuilder {
        operations.append(.endBefore(QueryCursor(values: values)))
        return self
    }

    // MARK: - Accessors

    /// Get all operations in the order they were chained
    public func getOperations() -> [QueryOperation] {
        operations
    }

    /// Get all filters (convenience accessor, does not preserve interleaved order)
    public func getFilters() -> [QueryFilter] {
        operations.compactMap { operation in
            if case .filter(let filter) = operation { return filter }
            return nil
        }
    }

    /// Get all order clauses (convenience accessor, does not preserve interleaved order)
    public func getOrders() -> [QueryOrder] {
        operations.compactMap { operation in
            if case .order(let order) = operation { return order }
            return nil
        }
    }

    /// Get the last limit value (first N documents), if set
    public func getLimit() -> Int? {
        operations.reversed().compactMap { operation in
            if case .limit(let value) = operation { return value }
            return nil
        }.first
    }

    /// Get the last limit-to-last value (last N documents), if set
    public func getLimitToLast() -> Int? {
        operations.reversed().compactMap { operation in
            if case .limitToLast(let value) = operation { return value }
            return nil
        }.first
    }

    /// Get the last start-at cursor values, if set
    public func getStartAt() -> [any DMCodableSendable]? {
        operations.reversed().compactMap { operation in
            if case .startAt(let cursor) = operation { return cursor.values }
            return nil
        }.first
    }

    /// Get the last start-after cursor values, if set
    public func getStartAfter() -> [any DMCodableSendable]? {
        operations.reversed().compactMap { operation in
            if case .startAfter(let cursor) = operation { return cursor.values }
            return nil
        }.first
    }

    /// Get the last end-at cursor values, if set
    public func getEndAt() -> [any DMCodableSendable]? {
        operations.reversed().compactMap { operation in
            if case .endAt(let cursor) = operation { return cursor.values }
            return nil
        }.first
    }

    /// Get the last end-before cursor values, if set
    public func getEndBefore() -> [any DMCodableSendable]? {
        operations.reversed().compactMap { operation in
            if case .endBefore(let cursor) = operation { return cursor.values }
            return nil
        }.first
    }
}

/// Represents a single query operation, preserving the order in which it was chained.
public enum QueryOperation: Sendable, Equatable {
    case filter(QueryFilter)
    case order(QueryOrder)
    case limit(Int)
    case limitToLast(Int)
    case startAt(QueryCursor)
    case startAfter(QueryCursor)
    case endAt(QueryCursor)
    case endBefore(QueryCursor)
}

/// Represents a single query filter condition
public struct QueryFilter: Sendable, Equatable {
    /// The field name to filter on
    public let field: String

    /// The comparison operator
    public let `operator`: QueryOperator

    /// The value to compare against (can be single value or array for array operators)
    public let value: any DMCodableSendable

    public init(field: String, operator: QueryOperator, value: any DMCodableSendable) {
        self.field = field
        self.operator = `operator`
        self.value = value
    }

    public static func == (lhs: QueryFilter, rhs: QueryFilter) -> Bool {
        guard lhs.field == rhs.field, lhs.operator == rhs.operator else {
            return false
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let lhsData = try? encoder.encode(lhs.value),
              let rhsData = try? encoder.encode(rhs.value) else {
            return false
        }
        return lhsData == rhsData
    }
}

/// Represents an ordering clause for query results
public struct QueryOrder: Sendable, Equatable {
    /// The field name to order by
    public let field: String

    /// Whether to sort in descending order (defaults to false / ascending)
    public let descending: Bool

    public init(field: String, descending: Bool = false) {
        self.field = field
        self.descending = descending
    }
}

/// Represents a cursor position for query pagination
public struct QueryCursor: Sendable, Equatable {
    /// The values that define the cursor position
    public let values: [any DMCodableSendable]

    public init(values: [any DMCodableSendable]) {
        self.values = values
    }

    public static func == (lhs: QueryCursor, rhs: QueryCursor) -> Bool {
        guard lhs.values.count == rhs.values.count else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        for (l, r) in zip(lhs.values, rhs.values) {
            guard let lData = try? encoder.encode(l),
                  let rData = try? encoder.encode(r) else {
                return false
            }
            if lData != rData { return false }
        }
        return true
    }
}

/// Query comparison operators
public enum QueryOperator: String, Sendable, Equatable {
    // Equality
    case isEqualTo = "=="
    case isNotEqualTo = "!="

    // Comparison
    case isGreaterThan = ">"
    case isGreaterThanOrEqualTo = ">="
    case isLessThan = "<"
    case isLessThanOrEqualTo = "<="

    // Array operations
    case arrayContains = "array-contains"
    case arrayContainsAny = "array-contains-any"
    case `in` = "in"
    case notIn = "not-in"
}
