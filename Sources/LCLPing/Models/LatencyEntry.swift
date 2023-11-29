//
//  LatencyEntry.swift
//  
//
//  Created by JOHN ZZN on 9/19/23.
//

import Foundation


internal struct LatencyEntry {
    var requestStart: TimeInterval = .zero
    var responseStart: TimeInterval = .zero
    var responseEnd: TimeInterval = .zero
    var serverTiming: TimeInterval = .zero
    var latencyStatus: LatencyEntry.Status
    
    let seqNum: UInt16
    
    init(seqNum: UInt16) {
        self.seqNum = seqNum
        self.latencyStatus = .waiting
    }
}

extension LatencyEntry {
    internal enum Status: Equatable {
        case finished
        case timeout
        case error(UInt) // status code (similar to HTTP status code)
        case waiting
    }
}
