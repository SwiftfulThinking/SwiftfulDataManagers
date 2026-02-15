//
//  QueryBuilder.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno on 1/18/25.
//

import Foundation

/// Query builder for constructing database queries with various filter operators.
///
/// Example:
/// ```swift
/// let query = QueryBuilder()
///     .where("age", isGreaterThan: 18)
///     .where("city", isEqualTo: "NYC")
///     .where("tags", arrayContains: "swift")
/// ```
public final class QueryBuilder: @unchecked Sendable, Equatable {
    private var filters: [QueryFilter] = []

    public init() {}

    public static func == (lhs: QueryBuilder, rhs: QueryBuilder) -> Bool {
        lhs.filters == rhs.filters
    }

    // MARK: - Equality Operators

    /// Filter where field equals value
    @discardableResult
    public func `where`(_ field: String, isEqualTo value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .isEqualTo, value: value))
        return self
    }

    /// Filter where field does not equal value
    @discardableResult
    public func `where`(_ field: String, isNotEqualTo value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .isNotEqualTo, value: value))
        return self
    }

    // MARK: - Comparison Operators

    /// Filter where field is greater than value
    @discardableResult
    public func `where`(_ field: String, isGreaterThan value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .isGreaterThan, value: value))
        return self
    }

    /// Filter where field is greater than or equal to value
    @discardableResult
    public func `where`(_ field: String, isGreaterThanOrEqualTo value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .isGreaterThanOrEqualTo, value: value))
        return self
    }

    /// Filter where field is less than value
    @discardableResult
    public func `where`(_ field: String, isLessThan value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .isLessThan, value: value))
        return self
    }

    /// Filter where field is less than or equal to value
    @discardableResult
    public func `where`(_ field: String, isLessThanOrEqualTo value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .isLessThanOrEqualTo, value: value))
        return self
    }

    // MARK: - Array Operators

    /// Filter where field array contains value
    @discardableResult
    public func `where`(_ field: String, arrayContains value: any DMCodableSendable) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .arrayContains, value: value))
        return self
    }

    /// Filter where field array contains any of the values
    @discardableResult
    public func `where`<V: DMCodableSendable>(_ field: String, arrayContainsAny values: [V]) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .arrayContainsAny, value: values))
        return self
    }

    /// Filter where field is in array of values
    @discardableResult
    public func `where`<V: DMCodableSendable>(_ field: String, `in` values: [V]) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .in, value: values))
        return self
    }

    /// Filter where field is not in array of values
    @discardableResult
    public func `where`<V: DMCodableSendable>(_ field: String, notIn values: [V]) -> QueryBuilder {
        filters.append(QueryFilter(field: field, operator: .notIn, value: values))
        return self
    }

    // MARK: - Access Filters

    /// Get all filters
    public func getFilters() -> [QueryFilter] {
        filters
    }
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
