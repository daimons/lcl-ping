//
//  ICMPPing.swift
//  
//
//  Created by JOHN ZZN on 8/26/23.
//

import Foundation
@_spi(AsyncChannel) import NIOCore
import NIO
import NIOPosix
import Logging

typealias ICMPOutboundIn = (UInt16, UInt16)

fileprivate let ICMPPingIdentifier: UInt16 = 0xbeef

internal struct ICMPPing: Pingable {
    
    var status: PingState {
        get {
            pingStatus
        }
    }
    
    
    var summary: PingSummary? {
        get {
            // return empty if ping is still running
            switch pingStatus {
            case .ready, .running, .failed:
                return .empty
            case .stopped, .finished:
                return pingSummary
            }
        }
        set {
            
        }
    }
    private var asyncChannel: NIOAsyncChannel<PingResponse, ICMPOutboundIn>?
    private var task: Task<(), Error>?
    
    private var timeout: Set<UInt16> = Set()
    private var duplicates: Set<UInt16> = Set()
    private var pingResults: [PingResult] = []
    private var pingStatus: PingState = .ready
    private var pingSummary: PingSummary?
    private let logger: Logger = Logger(label: "com.lcl.lclping")
    
    internal init() { }
    
//    mutating func start(with configuration: LCLPing.Configuration) throws {
//        print("non async start")
//    }
    
    mutating func start(with configuration: LCLPing.Configuration) async throws {
        pingStatus = .running
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        let bootstrap = DatagramBootstrap(group: group)
            .protocolSubtype(.init(.icmp))
            .channelInitializer { channel in
                channel.pipeline.addHandlers(
                [
                    IPDecoder(), ICMPDecoder(), ICMPDuplexer(configuration: configuration)
                ]
                )
            }
        
        let host: String
        switch configuration.host {
        case .icmp(let h):
            host = h
        default:
            pingStatus = .failed
            throw PingError.invalidConfiguration("Expect IP.ICMP host. But received \(configuration.host)")
        }
        
//        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
//        if fd == -1 {
//            fatalError("Unable to open datagram socket for ICMP")
//        }
        
        do {
//            let channel = try await bootstrap.withBoundSocket(fd).get()
            let channel = try await bootstrap.connect(host: host, port: 0).get()
//            try await channel.connect(to: .makeAddressResolvingHost(host, port: 0))
            asyncChannel = try await withCheckedThrowingContinuation { continuation in
                channel.eventLoop.execute {
                    do {
                        let asyncChannel = try NIOAsyncChannel<PingResponse, ICMPOutboundIn>(synchronouslyWrapping: channel)
                        continuation.resume(with: .success(asyncChannel))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            pingStatus = .failed
            throw PingError.hostConnectionError(error)
        }

        guard let asyncChannel = asyncChannel else {
            throw PingError.failedToInitialzeChannel
        }
        
        print("Channel intialized")

        task = Task(priority: .background) { [asyncChannel] in
            var cnt: UInt16 = 0
            var nextSequenceNumber: UInt16 = 0
            do {
                while !Task.isCancelled && cnt != configuration.count {
                    print("sending #\(cnt)")
                    try await asyncChannel.outboundWriter.write((ICMPPingIdentifier, nextSequenceNumber))
                    cnt += 1
                    nextSequenceNumber += 1
                    try await Task.sleep(nanoseconds: configuration.interval.nanosecond)
                }
            } catch {
                // pingStatus = .failed
                throw PingError.sendPingFailed(error)
            }
        }

        var localMin: Double = .greatestFiniteMagnitude
        var localMax: Double = .zero
        var consecutiveDiffSum: Double = .zero
        var errorCount: Int = 0
        for try await pingResponse in asyncChannel.inboundStream {
            switch pingResponse {
            case .ok(let sequenceNum, let latency, let timstamp):
                localMin = min(localMin, latency)
                localMax = max(localMax, latency)
                if self.pingResults.count > 1 {
                    consecutiveDiffSum += abs(latency - self.pingResults.last!.latency)
                }
                self.pingResults.append( PingResult(seqNum: sequenceNum, latency: latency, ipAddress: host, timestamp: timstamp) )
            case .duplicated(let sequenceNum):
                duplicates.insert(sequenceNum)
            case .timeout(let sequenceNum):
                timeout.insert(sequenceNum)
            case .error:
                errorCount += 1
                print("Error occurred during processing ping response")
            }
        }

        let pingResultLen = self.pingResults.count
        let avg = self.pingResults.avg
        let stdDev = sqrt( self.pingResults.map { ($0.latency - avg) * ($0.latency - avg) }.reduce(0.0, +) / Double(pingResultLen - 1))

        pingSummary = PingSummary(min: localMin,
                                   max: localMax,
                                   avg: avg,
                                   median: self.pingResults.median,
                                   stdDev: stdDev,
                                   jitter: consecutiveDiffSum / Double(pingResultLen),
                                   details: self.pingResults,
                                   totalCount: pingResultLen + errorCount + timeout.count,
                                   timeout: timeout,
                                   duplicates: duplicates,
                                   ipAddress: host)

        if pingStatus == .running {
            pingStatus = .finished
        }
        print("summary is \(String(describing: pingSummary))")
        
    }
    
    mutating func stop() {
        pingStatus = .stopped
        task?.cancel()
        asyncChannel?.channel.close(mode: .all, promise: nil)
    }
}
