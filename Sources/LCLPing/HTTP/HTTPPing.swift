//
//  HTTPPing.swift
//  
//
//  Created by JOHN ZZN on 9/6/23.
//

import Foundation


internal struct HTTPPing: Pingable {
    
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
    
    var status: PingState {
        get {
            pingStatus
        }
    }
    
    
    private var timeout: Set<UInt16> = Set()
    private var duplicates: Set<UInt16> = Set()
    private var pingResults: [PingResult] = []
    private var pingStatus: PingState = .ready
    private var pingSummary: PingSummary?
    
//    mutating func start(with configuration: LCLPing.Configuration) throws {
//
//    }
    
    mutating func start(with configuration: LCLPing.Configuration) async throws {
        pingStatus = .running
        let httpExecutor = HTTPHandler(useServerTiming: false)
        do {
            for try await res in try await httpExecutor.execute(configuration: configuration) {
                print(res)
            }
            pingStatus = .finished
        } catch {
            pingStatus = .failed
            print("Error \(error)")
        }
    }
    
    mutating func stop() {
        if pingStatus != .failed {
            pingStatus = .stopped
        }
    }
    

    
    
}