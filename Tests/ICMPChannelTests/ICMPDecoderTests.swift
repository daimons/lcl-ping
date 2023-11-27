//
//  ICMPDecoderTests.swift
//  
//
//  Created by JOHN ZZN on 11/25/23.
//

import XCTest
import NIOEmbedded
import NIOCore
@testable import LCLPing

final class ICMPDecoderTests: XCTestCase {
    
    private var channel: EmbeddedChannel!
    private var loop: EmbeddedEventLoop {
        return self.channel.embeddedEventLoop
    }

    override func setUp() {
        self.channel = EmbeddedChannel()
    }

    override func tearDown() {
        XCTAssertNoThrow(try self.channel?.finish(acceptAlreadyClosed: true))
        channel = nil
    }

    func testAddICMPDecoderChannelHandler() {
        XCTAssertNotNil(channel, "Channel should be initialized by now but is still nil")
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ICMPDecoder()).wait())
        channel.pipeline.fireChannelActive()
    }
    
    private func sendICMPPacket(byteString icmp: String) throws {
        XCTAssertNoThrow(try self.channel.pipeline.addHandler(ICMPDecoder()).wait())
        var buffer = channel.allocator.buffer(capacity: icmp.count)
        buffer.writeBytes(icmp.toBytes)
        channel.pipeline.fireChannelActive()
        try channel.writeInbound(buffer)
        self.loop.run()
    }
    
    func testEmptyICMPPacket() throws {
        let expectedError: RuntimeError = .insufficientBytes("Not enough bytes in the reponse message. Need 18 bytes. But received 0")
        XCTAssertThrowsError(try sendICMPPacket(byteString: "")) { error in
            XCTAssertEqual(error as? RuntimeError, expectedError)
        }
    }
    
    func testValidICMPPacket() throws {
        XCTAssertNoThrow(try sendICMPPacket(byteString: "0000f809efbe0100ecf6a2e6be58d941efbe"))
        let icmpHeader = try channel.readInbound(as: ICMPHeader.self)
        XCTAssertNotNil(icmpHeader)
        XCTAssertEqual(icmpHeader!.code, 0)
        XCTAssertEqual(icmpHeader!.type, 0)
        XCTAssertEqual(icmpHeader!.idenifier, 0xbeef)
        XCTAssertEqual(icmpHeader!.sequenceNum, 1)
        XCTAssertEqual(icmpHeader!.payload.identifier, 0xbeef)
    }
    
    func testInsufficientByteLength() throws {
        let expectedError: RuntimeError = .insufficientBytes("Not enough bytes in the reponse message. Need 18 bytes. But received 14")
        XCTAssertThrowsError(try sendICMPPacket(byteString: "0000f809efbe0100ecf6a2e6be58")) { error in
            XCTAssertEqual(error as? RuntimeError, expectedError)
        }
    }
}