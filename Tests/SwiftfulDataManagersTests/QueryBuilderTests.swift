//
//  QueryBuilderTests.swift
//  SwiftfulDataManagers
//
//  Tests for QueryFilter and QueryBuilder Equatable conformance.
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

    // MARK: - QueryBuilder Equality

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
}
