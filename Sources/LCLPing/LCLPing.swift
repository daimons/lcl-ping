

public struct LCLPing {
    
    var ping: Pingable?
    
    public var status: PingState {
        ping?.pingStatus ?? .error
    }
    
    public var summary: PingSummary {
        ping?.summary ?? .empty
    }
    
    private let configuration: LCLPing.Configuration
    
    public init(configuration: LCLPing.Configuration = .init()) {
        ping = nil
        self.configuration = configuration
        logger.logLevel = self.configuration.verbose ? .debug : .info
        // TODO: think about how to pass configuration to ping instance
    }
    
    public mutating func start(pingConfiguration: LCLPing.PingConfiguration) async throws {
        // TODO: validate configuration
        logger.info("START")
        logger.debug("Using configuration \(pingConfiguration)")
        let type = pingConfiguration.type
        switch type {
        case .icmp:
            logger.debug("start ICMP Ping ...")
            ping = ICMPPing()
        case .http(let options):
            logger.debug("start HTTP Ping with options \(options)")
            ping = HTTPPing(options: options)
        }
        
        try await ping?.start(with: pingConfiguration)
        logger.info("DONE")
    }
    
    public mutating func stop() {
        logger.debug("try to stop ping")
        ping?.stop()
        logger.debug("ping stopped")
    }
}
