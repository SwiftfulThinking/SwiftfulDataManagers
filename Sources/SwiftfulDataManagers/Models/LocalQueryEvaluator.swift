//
//  LocalQueryEvaluator.swift
//  SwiftfulDataManagers
//
//  Created by Nick Sarno.
//

import Foundation

// MARK: - Local Query Evaluation

extension QueryBuilder {

    /// Evaluates this query against an in-memory array of documents.
    ///
    /// Used by `CollectionSyncEngine.getDocumentsAsync(buildQuery:behavior:)`
    /// when `behavior == .cachedOrFetch` and the engine has a non-empty
    /// `currentCollection` — the query is run against the local cache
    /// instead of hitting the remote.
    ///
    /// Supports filters, ordering, and limiting. Cursors (startAt /
    /// startAfter / endAt / endBefore) are no-ops in local evaluation —
    /// they require absolute ordering context that's only meaningful for
    /// paginated remote queries.
    ///
    /// Field-name lookups use the document's `Codable` representation, so
    /// pass field names exactly as they appear in remote storage (e.g.
    /// snake_case for Firestore via `CodingKeys`).
    public func evaluate<T: DataSyncModelProtocol>(against documents: [T]) -> [T] {
        var results = documents

        for operation in getOperations() {
            switch operation {
            case .filter(let filter):
                results = results.filter { Self.matches($0, filter: filter) }
            case .order(let order):
                results.sort { lhs, rhs in
                    Self.compare(lhs, rhs, order: order) == .orderedAscending
                }
            case .limit(let count):
                if results.count > count {
                    results = Array(results.prefix(count))
                }
            case .limitToLast(let count):
                if results.count > count {
                    results = Array(results.suffix(count))
                }
            case .startAt, .startAfter, .endAt, .endBefore:
                // Cursors are no-ops in local evaluation.
                continue
            }
        }

        return results
    }

    // MARK: Filter

    private static func matches<T: DataSyncModelProtocol>(_ doc: T, filter: QueryFilter) -> Bool {
        guard let docDict = jsonDict(of: doc) else { return false }
        let docValue = docDict[filter.field] is NSNull ? nil : docDict[filter.field]
        let filterValue = jsonObject(of: filter.value)

        switch filter.operator {
        case .isEqualTo:
            return jsonEquals(docValue, filterValue)
        case .isNotEqualTo:
            return !jsonEquals(docValue, filterValue)
        case .isGreaterThan:
            return jsonCompare(docValue, filterValue) == .orderedDescending
        case .isGreaterThanOrEqualTo:
            let result = jsonCompare(docValue, filterValue)
            return result == .orderedDescending || result == .orderedSame
        case .isLessThan:
            return jsonCompare(docValue, filterValue) == .orderedAscending
        case .isLessThanOrEqualTo:
            let result = jsonCompare(docValue, filterValue)
            return result == .orderedAscending || result == .orderedSame
        case .arrayContains:
            guard let array = docValue as? [Any] else { return false }
            return array.contains { jsonEquals($0, filterValue) }
        case .arrayContainsAny:
            guard let array = docValue as? [Any], let needles = filterValue as? [Any] else { return false }
            return array.contains { element in
                needles.contains { jsonEquals(element, $0) }
            }
        case .in:
            guard let needles = filterValue as? [Any] else { return false }
            return needles.contains { jsonEquals($0, docValue) }
        case .notIn:
            guard let needles = filterValue as? [Any] else { return false }
            return !needles.contains { jsonEquals($0, docValue) }
        }
    }

    // MARK: Order

    private static func compare<T: DataSyncModelProtocol>(
        _ lhs: T,
        _ rhs: T,
        order: QueryOrder
    ) -> ComparisonResult {
        guard let lhsDict = jsonDict(of: lhs),
              let rhsDict = jsonDict(of: rhs) else {
            return .orderedSame
        }
        let lhsValue = lhsDict[order.field] is NSNull ? nil : lhsDict[order.field]
        let rhsValue = rhsDict[order.field] is NSNull ? nil : rhsDict[order.field]
        let raw = jsonCompare(lhsValue, rhsValue) ?? .orderedSame
        return order.descending ? Self.reverse(raw) : raw
    }

    private static func reverse(_ result: ComparisonResult) -> ComparisonResult {
        switch result {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }

    // MARK: JSON Helpers

    private static func jsonDict<T: Encodable>(of value: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func jsonObject(of value: any Encodable) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// JSON-style equality. Two values compare equal if their NSObject
    /// representations match — covers strings, numbers, booleans, null,
    /// arrays, and dictionaries via deep equality.
    private static func jsonEquals(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        default:
            break
        }
        if let lhs = lhs as? NSObject, let rhs = rhs as? NSObject {
            return lhs.isEqual(rhs)
        }
        return false
    }

    /// Numeric / string comparison. Returns nil for incomparable types.
    private static func jsonCompare(_ lhs: Any?, _ rhs: Any?) -> ComparisonResult? {
        guard let lhs, let rhs else {
            // Treat nil as smaller than any present value, equal to nil.
            if lhs == nil && rhs == nil { return .orderedSame }
            return lhs == nil ? .orderedAscending : .orderedDescending
        }
        if let lhsNumber = lhs as? NSNumber, let rhsNumber = rhs as? NSNumber {
            return lhsNumber.compare(rhsNumber)
        }
        if let lhsString = lhs as? String, let rhsString = rhs as? String {
            return lhsString.compare(rhsString)
        }
        return nil
    }
}
