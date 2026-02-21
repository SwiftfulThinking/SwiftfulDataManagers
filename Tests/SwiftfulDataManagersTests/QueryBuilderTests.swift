//
//  QueryBuilderTests.swift
//  SwiftfulDataManagers
//
//  Tests for QueryFilter, QueryOrder, QueryCursor, QueryOperation, and QueryBuilder Equatable conformance.
//

import Foundation
import Testing
@testable import SwiftfulDataManagers

@Suite("QueryBuilder Equality Tests")
struct QueryBuilderTests {

    // MARK: - QueryFilter Equality

    @Test("QueryFilter: same field, operator, and value are equal")
    func testQueryFilterEquality() {
        let a = QueryFilter(field: "age", operator: .isGreaterThan, value: 18)
        let b = QueryFilter(field: "age", operator: .isGreaterThan, value: 18)
        #expect(a == b)
    }

    @Test("QueryFilter: different field is not equal")
    func testQueryFilterDifferentField() {
        let a = QueryFilter(field: "age", operator: .isGreaterThan, value: 18)
        let b = QueryFilter(field: "score", operator: .isGreaterThan, value: 18)
        #expect(a != b)
    }

    @Test("QueryFilter: different operator is not equal")
    func testQueryFilterDifferentOperator() {
        let a = QueryFilter(field: "age", operator: .isGreaterThan, value: 18)
        let b = QueryFilter(field: "age", operator: .isLessThan, value: 18)
        #expect(a != b)
    }

    @Test("QueryFilter: different value is not equal")
    func testQueryFilterDifferentValue() {
        let a = QueryFilter(field: "age", operator: .isGreaterThan, value: 18)
        let b = QueryFilter(field: "age", operator: .isGreaterThan, value: 21)
        #expect(a != b)
    }

    @Test("QueryFilter: String values compare correctly")
    func testQueryFilterStringValues() {
        let a = QueryFilter(field: "city", operator: .isEqualTo, value: "NYC")
        let b = QueryFilter(field: "city", operator: .isEqualTo, value: "NYC")
        let c = QueryFilter(field: "city", operator: .isEqualTo, value: "LA")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("QueryFilter: Double values compare correctly")
    func testQueryFilterDoubleValues() {
        let a = QueryFilter(field: "price", operator: .isLessThan, value: 9.99)
        let b = QueryFilter(field: "price", operator: .isLessThan, value: 9.99)
        let c = QueryFilter(field: "price", operator: .isLessThan, value: 19.99)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("QueryFilter: Bool values compare correctly")
    func testQueryFilterBoolValues() {
        let a = QueryFilter(field: "active", operator: .isEqualTo, value: true)
        let b = QueryFilter(field: "active", operator: .isEqualTo, value: true)
        let c = QueryFilter(field: "active", operator: .isEqualTo, value: false)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("QueryFilter: Array values compare correctly")
    func testQueryFilterArrayValues() {
        let a = QueryFilter(field: "tags", operator: .arrayContainsAny, value: ["swift", "ios"])
        let b = QueryFilter(field: "tags", operator: .arrayContainsAny, value: ["swift", "ios"])
        let c = QueryFilter(field: "tags", operator: .arrayContainsAny, value: ["android", "kotlin"])
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - QueryBuilder Filter Equality

    @Test("QueryBuilder: same filters in same order are equal")
    func testQueryBuilderEquality() {
        let a = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .where("city", isEqualTo: "NYC")
        let b = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .where("city", isEqualTo: "NYC")
        #expect(a == b)
    }

    @Test("QueryBuilder: same filters in different order are not equal")
    func testQueryBuilderDifferentOrder() {
        let a = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .where("city", isEqualTo: "NYC")
        let b = QueryBuilder()
            .where("city", isEqualTo: "NYC")
            .where("age", isGreaterThan: 18)
        #expect(a != b)
    }

    @Test("QueryBuilder: different filter count is not equal")
    func testQueryBuilderDifferentCount() {
        let a = QueryBuilder()
            .where("age", isGreaterThan: 18)
        let b = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .where("city", isEqualTo: "NYC")
        #expect(a != b)
    }

    @Test("QueryBuilder: both empty are equal")
    func testQueryBuilderBothEmpty() {
        let a = QueryBuilder()
        let b = QueryBuilder()
        #expect(a == b)
    }

    // MARK: - QueryOrder Equality

    @Test("QueryOrder: same field and direction are equal")
    func testQueryOrderEquality() {
        let a = QueryOrder(field: "age", descending: false)
        let b = QueryOrder(field: "age", descending: false)
        #expect(a == b)
    }

    @Test("QueryOrder: different field is not equal")
    func testQueryOrderDifferentField() {
        let a = QueryOrder(field: "age", descending: false)
        let b = QueryOrder(field: "name", descending: false)
        #expect(a != b)
    }

    @Test("QueryOrder: different direction is not equal")
    func testQueryOrderDifferentDirection() {
        let a = QueryOrder(field: "age", descending: false)
        let b = QueryOrder(field: "age", descending: true)
        #expect(a != b)
    }

    @Test("QueryOrder: default is ascending")
    func testQueryOrderDefaultAscending() {
        let a = QueryOrder(field: "age")
        let b = QueryOrder(field: "age", descending: false)
        #expect(a == b)
    }

    // MARK: - QueryCursor Equality

    @Test("QueryCursor: same values are equal")
    func testQueryCursorEquality() {
        let a = QueryCursor(values: [10, "hello"])
        let b = QueryCursor(values: [10, "hello"])
        #expect(a == b)
    }

    @Test("QueryCursor: different values are not equal")
    func testQueryCursorDifferentValues() {
        let a = QueryCursor(values: [10, "hello"])
        let b = QueryCursor(values: [20, "world"])
        #expect(a != b)
    }

    @Test("QueryCursor: different order is not equal")
    func testQueryCursorDifferentOrder() {
        let a = QueryCursor(values: ["hello", 10])
        let b = QueryCursor(values: [10, "hello"])
        #expect(a != b)
    }

    @Test("QueryCursor: empty values are equal")
    func testQueryCursorEmpty() {
        let a = QueryCursor(values: [])
        let b = QueryCursor(values: [])
        #expect(a == b)
    }

    // MARK: - QueryBuilder Ordering

    @Test("QueryBuilder: same orders are equal")
    func testQueryBuilderOrderEquality() {
        let a = QueryBuilder()
            .order(by: "age")
            .order(by: "name", descending: true)
        let b = QueryBuilder()
            .order(by: "age")
            .order(by: "name", descending: true)
        #expect(a == b)
    }

    @Test("QueryBuilder: different orders are not equal")
    func testQueryBuilderOrderInequality() {
        let a = QueryBuilder()
            .order(by: "age")
        let b = QueryBuilder()
            .order(by: "age", descending: true)
        #expect(a != b)
    }

    @Test("QueryBuilder: order(by:) defaults to ascending")
    func testQueryBuilderOrderDefaultAscending() {
        let a = QueryBuilder().order(by: "age")
        let b = QueryBuilder().order(by: "age", descending: false)
        #expect(a == b)
    }

    @Test("QueryBuilder: getOrders returns correct orders")
    func testQueryBuilderGetOrders() {
        let query = QueryBuilder()
            .order(by: "age")
            .order(by: "name", descending: true)
        let orders = query.getOrders()
        #expect(orders.count == 2)
        #expect(orders[0] == QueryOrder(field: "age"))
        #expect(orders[1] == QueryOrder(field: "name", descending: true))
    }

    // MARK: - QueryBuilder Limiting

    @Test("QueryBuilder: same limit are equal")
    func testQueryBuilderLimitEquality() {
        let a = QueryBuilder().limit(to: 10)
        let b = QueryBuilder().limit(to: 10)
        #expect(a == b)
    }

    @Test("QueryBuilder: different limits are not equal")
    func testQueryBuilderLimitInequality() {
        let a = QueryBuilder().limit(to: 10)
        let b = QueryBuilder().limit(to: 20)
        #expect(a != b)
    }

    @Test("QueryBuilder: limit vs limitToLast are not equal")
    func testQueryBuilderLimitVsLimitToLast() {
        let a = QueryBuilder().limit(to: 10)
        let b = QueryBuilder().limit(toLast: 10)
        #expect(a != b)
    }

    @Test("QueryBuilder: getLimit returns value when set")
    func testQueryBuilderGetLimit() {
        let query = QueryBuilder().limit(to: 10)
        #expect(query.getLimit() == 10)
        #expect(query.getLimitToLast() == nil)
    }

    @Test("QueryBuilder: getLimitToLast returns value when set")
    func testQueryBuilderGetLimitToLast() {
        let query = QueryBuilder().limit(toLast: 5)
        #expect(query.getLimitToLast() == 5)
        #expect(query.getLimit() == nil)
    }

    @Test("QueryBuilder: getLimit returns nil when not set")
    func testQueryBuilderGetLimitNil() {
        let query = QueryBuilder()
        #expect(query.getLimit() == nil)
        #expect(query.getLimitToLast() == nil)
    }

    // MARK: - QueryBuilder Cursors

    @Test("QueryBuilder: same startAt cursors are equal")
    func testQueryBuilderStartAtEquality() {
        let a = QueryBuilder().start(at: [10, "abc"])
        let b = QueryBuilder().start(at: [10, "abc"])
        #expect(a == b)
    }

    @Test("QueryBuilder: different startAt cursors are not equal")
    func testQueryBuilderStartAtInequality() {
        let a = QueryBuilder().start(at: [10])
        let b = QueryBuilder().start(at: [20])
        #expect(a != b)
    }

    @Test("QueryBuilder: startAt vs startAfter are not equal")
    func testQueryBuilderStartAtVsStartAfter() {
        let a = QueryBuilder().start(at: [10])
        let b = QueryBuilder().start(after: [10])
        #expect(a != b)
    }

    @Test("QueryBuilder: same endAt cursors are equal")
    func testQueryBuilderEndAtEquality() {
        let a = QueryBuilder().end(at: [100])
        let b = QueryBuilder().end(at: [100])
        #expect(a == b)
    }

    @Test("QueryBuilder: endAt vs endBefore are not equal")
    func testQueryBuilderEndAtVsEndBefore() {
        let a = QueryBuilder().end(at: [100])
        let b = QueryBuilder().end(before: [100])
        #expect(a != b)
    }

    @Test("QueryBuilder: getStartAt returns correct values")
    func testQueryBuilderGetStartAt() {
        let query = QueryBuilder().start(at: [10, "abc"])
        let values = query.getStartAt()
        #expect(values != nil)
        #expect(values?.count == 2)
    }

    @Test("QueryBuilder: getStartAfter returns correct values")
    func testQueryBuilderGetStartAfter() {
        let query = QueryBuilder().start(after: [25])
        let values = query.getStartAfter()
        #expect(values != nil)
        #expect(values?.count == 1)
    }

    @Test("QueryBuilder: getEndAt returns correct values")
    func testQueryBuilderGetEndAt() {
        let query = QueryBuilder().end(at: [100])
        let values = query.getEndAt()
        #expect(values != nil)
        #expect(values?.count == 1)
    }

    @Test("QueryBuilder: getEndBefore returns correct values")
    func testQueryBuilderGetEndBefore() {
        let query = QueryBuilder().end(before: [99])
        let values = query.getEndBefore()
        #expect(values != nil)
        #expect(values?.count == 1)
    }

    @Test("QueryBuilder: cursor accessors return nil when not set")
    func testQueryBuilderCursorAccessorsNil() {
        let query = QueryBuilder()
        #expect(query.getStartAt() == nil)
        #expect(query.getStartAfter() == nil)
        #expect(query.getEndAt() == nil)
        #expect(query.getEndBefore() == nil)
    }

    // MARK: - Operation Order Preservation

    @Test("QueryBuilder: operations preserve chaining order")
    func testQueryBuilderOperationOrder() {
        let query = QueryBuilder()
            .order(by: "age")
            .where("city", isEqualTo: "NYC")
            .limit(to: 10)
        let ops = query.getOperations()
        #expect(ops.count == 3)
        #expect(ops[0] == .order(QueryOrder(field: "age")))
        #expect(ops[1] == .filter(QueryFilter(field: "city", operator: .isEqualTo, value: "NYC")))
        #expect(ops[2] == .limit(10))
    }

    @Test("QueryBuilder: different interleaving order is not equal")
    func testQueryBuilderInterleavingOrderMatters() {
        let a = QueryBuilder()
            .where("city", isEqualTo: "NYC")
            .order(by: "age")
        let b = QueryBuilder()
            .order(by: "age")
            .where("city", isEqualTo: "NYC")
        #expect(a != b)
    }

    // MARK: - Full Chain

    @Test("QueryBuilder: full chain with filters, order, limit, and cursors are equal")
    func testQueryBuilderFullChain() {
        let a = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .where("city", isEqualTo: "NYC")
            .order(by: "age", descending: true)
            .limit(to: 10)
            .start(after: [25])
            .end(before: [65])
        let b = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .where("city", isEqualTo: "NYC")
            .order(by: "age", descending: true)
            .limit(to: 10)
            .start(after: [25])
            .end(before: [65])
        #expect(a == b)
    }

    @Test("QueryBuilder: full chain differs by one property is not equal")
    func testQueryBuilderFullChainDifference() {
        let a = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .order(by: "age")
            .limit(to: 10)
            .start(after: [25])
        let b = QueryBuilder()
            .where("age", isGreaterThan: 18)
            .order(by: "age")
            .limit(to: 10)
            .start(after: [30])
        #expect(a != b)
    }
}
