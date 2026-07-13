//
//  LsofParserTests.swift
//  TCPV4MAC — real-time TCP/UDP connection inspector for macOS
//
//  Copyright (C) 2026 Jensy Leonardo Martínez Cruz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import XCTest
@testable import TCPV4MACCore

final class LsofParserTests: XCTestCase {

    private func loadFixture() throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "lsof_sample", withExtension: "txt"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testParsesExpectedConnectionCount() throws {
        let connections = LsofParser().parse(try loadFixture())
        // 634 has two fds; 643, 641, 675 one each.
        XCTAssertEqual(connections.count, 5)
    }

    func testFullProcessNameIsNotTruncated() throws {
        let connections = LsofParser().parse(try loadFixture())
        XCTAssertTrue(connections.contains { $0.processName == "identityservicesd" })
    }

    func testListeningTCPConnection() throws {
        let connections = LsofParser().parse(try loadFixture())
        let listener = try XCTUnwrap(connections.first { $0.processName == "rapportd" && !$0.isIPv6 })
        XCTAssertEqual(listener.protocolType, .tcp)
        XCTAssertEqual(listener.state, .listen)
        XCTAssertEqual(listener.localIP, "*")
        XCTAssertEqual(listener.localPort, 49152)
        XCTAssertNil(listener.remoteIP)
        XCTAssertNil(listener.remotePort)
        XCTAssertTrue(listener.isListening)
    }

    func testEstablishedConnectionWithRemote() throws {
        let connections = LsofParser().parse(try loadFixture())
        let conn = try XCTUnwrap(connections.first { $0.processName == "MSTeams" })
        XCTAssertEqual(conn.state, .established)
        XCTAssertEqual(conn.localIP, "192.168.40.19")
        XCTAssertEqual(conn.localPort, 49825)
        XCTAssertEqual(conn.remoteIP, "13.89.179.11")
        XCTAssertEqual(conn.remotePort, 443)
    }

    func testUDPUnboundHasNoStateOrPort() throws {
        let connections = LsofParser().parse(try loadFixture())
        let udp = try XCTUnwrap(connections.first { $0.protocolType == .udp })
        XCTAssertNil(udp.state)
        XCTAssertEqual(udp.localIP, "*")
        XCTAssertEqual(udp.localPort, 0)
        XCTAssertNil(udp.remotePort)
    }

    func testIPv6LoopbackConnection() throws {
        let connections = LsofParser().parse(try loadFixture())
        let conn = try XCTUnwrap(connections.first { $0.processName == "Freeplane" })
        XCTAssertTrue(conn.isIPv6)
        XCTAssertEqual(conn.localIP, "::1")
        XCTAssertEqual(conn.localPort, 49157)
        XCTAssertTrue(conn.isLoopback)
    }

    func testStableIdentityIsDeterministic() throws {
        let a = LsofParser().parse(try loadFixture())
        let b = LsofParser().parse(try loadFixture())
        XCTAssertEqual(a.map(\.identity), b.map(\.identity))
    }

    // MARK: - Endpoint parsing

    func testParseEndpointIPv4WithPort() {
        let result = LsofParser.parseEndpoint("192.168.40.19:49825")
        XCTAssertEqual(result?.ip, "192.168.40.19")
        XCTAssertEqual(result?.port, 49825)
    }

    func testParseEndpointWildcardHost() {
        let result = LsofParser.parseEndpoint("*:49152")
        XCTAssertEqual(result?.ip, "*")
        XCTAssertEqual(result?.port, 49152)
    }

    func testParseEndpointWildcardPort() {
        let result = LsofParser.parseEndpoint("*:*")
        XCTAssertEqual(result?.ip, "*")
        XCTAssertNil(result?.port)
    }

    func testParseEndpointIPv6Bracketed() {
        let result = LsofParser.parseEndpoint("[::1]:42050")
        XCTAssertEqual(result?.ip, "::1")
        XCTAssertEqual(result?.port, 42050)
    }

    func testParseEndpointIPv6WithZone() {
        let result = LsofParser.parseEndpoint("[fe80::1%en0]:546")
        XCTAssertEqual(result?.ip, "fe80::1%en0")
        XCTAssertEqual(result?.port, 546)
    }
}
