import Foundation
import librist

public struct RistSenderStats {
    public let peerId: UInt32
    public let bandwidth: UInt64
    public let retryBandwidth: UInt64
    public let sentPackets: UInt64
    public let receivedPackets: UInt64
    public let retransmittedPackets: UInt64
    public let quality: Double
    public let rtt: UInt32
}

public struct RistStats {
    public let sender: RistSenderStats
}

public class RistPeer {
    let peer: OpaquePointer
    let context: RistSenderContext

    init(peer: OpaquePointer, context: RistSenderContext) {
        self.peer = peer
        self.context = context
    }

    public func setWeight(weight: UInt32) {
        rist_peer_weight_set(context.context, peer, weight)
    }

    public func getId() -> UInt32 {
        return rist_peer_get_id(peer)
    }

    deinit {
        rist_peer_destroy(context.context, peer)
    }
}

public protocol RistSenderContextDelegate: AnyObject {
    func ristSenderContextStats(_ context: RistSenderContext, stats: RistStats)
    func ristSenderContextPeerConnected(_ context: RistSenderContext, peerId: UInt32)
    func ristSenderContextPeerDisconnected(_ context: RistSenderContext, peerId: UInt32)
}

private func createSenderContext(profile: rist_profile) -> OpaquePointer? {
    var context: OpaquePointer?
    let result = withUnsafeMutablePointer(to: &context) { contextPointer in
        rist_sender_create(contextPointer, profile, 0, nil)
    }
    guard result == 0 else {
        return nil
    }
    return context
}

public class RistSenderContext {
    let context: OpaquePointer
    public weak var delegate: RistSenderContextDelegate?

    public init?(profile: rist_profile = RIST_PROFILE_MAIN) {
        guard let context = createSenderContext(profile: profile) else {
            return nil
        }
        self.context = context
        setStatsCallback()
        setConnectionStatusCallback()
    }

    public func start() -> Bool {
        return rist_start(context) == 0
    }

    public func stop() {
        rist_destroy(context)
    }

    public func addPeer(url: String) -> RistPeer? {
        var config: UnsafeMutablePointer<rist_peer_config>?
        var result = withUnsafeMutablePointer(to: &config) { configPointer in
            rist_parse_address2(url.cString(using: .utf8), configPointer)
        }
        guard result == 0 else {
            return nil
        }
        var peer: OpaquePointer?
        result = withUnsafeMutablePointer(to: &peer) { peerPointer in
            rist_peer_create(context, peerPointer, config)
        }
        if let peer,
           let config = config?.pointee,
           config.srp_username.0 != 0,
           config.srp_password.0 != 0
        {
            withUnsafePointer(to: config.srp_username) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { username in
                    withUnsafePointer(to: config.srp_password) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 1) { password in
                            _ = rist_enable_eap_srp_2(peer, username, password, nil, nil)
                        }
                    }
                }
            }
        }
        withUnsafeMutablePointer(to: &config) { configPointer in
            _ = rist_peer_config_free2(configPointer)
        }
        guard result == 0, let peer else {
            return nil
        }
        return RistPeer(peer: peer, context: self)
    }

    public func send(data: Data) -> Bool {
        return data.withUnsafeBytes { dataPointer in
            send(dataPointer: dataPointer, count: data.count)
        }
    }

    public func send(dataPointer: UnsafeRawBufferPointer, count: Int) -> Bool {
        var dataBlock = rist_data_block(
            payload: dataPointer.baseAddress,
            payload_len: count,
            ts_ntp: 0,
            virt_src_port: 0,
            virt_dst_port: 0,
            peer: nil,
            flow_id: 0,
            seq: 0,
            flags: 0,
            ref: nil
        )
        let writtenCount = withUnsafePointer(to: &dataBlock) { dataBlockPointer in
            rist_sender_data_write(context, dataBlockPointer)
        }
        return writtenCount == count
    }

    private func setStatsCallback() {
        let handleStats: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<rist_stats>?)
            -> Int32 = { contextArg, stats in
                guard let contextArg else {
                    return 0
                }
                let context: RistSenderContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
                guard let stats = stats?.pointee.stats else {
                    return 0
                }
                context.delegate?.ristSenderContextStats(context, stats: RistStats(sender: RistSenderStats(
                    peerId: stats.sender_peer.peer_id,
                    bandwidth: UInt64(stats.sender_peer.bandwidth),
                    retryBandwidth: UInt64(stats.sender_peer.retry_bandwidth),
                    sentPackets: stats.sender_peer.sent,
                    receivedPackets: stats.sender_peer.received,
                    retransmittedPackets: stats.sender_peer.retransmitted,
                    quality: stats.sender_peer.quality,
                    rtt: stats.sender_peer.rtt
                )))
                return 0
            }
        _ = rist_stats_callback_set(context, 200, handleStats, Unmanaged.passUnretained(self).toOpaque())
    }

    private func setConnectionStatusCallback() {
        let handleConnectionStatusChange: @convention(c) (
            UnsafeMutableRawPointer?,
            OpaquePointer?,
            rist_connection_status
        ) -> Void = { contextArg, peer, status in
            guard let contextArg, let peer else {
                return
            }
            let context: RistSenderContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
            let peerId = rist_peer_get_id(peer)
            if status == RIST_CONNECTION_ESTABLISHED {
                context.delegate?.ristSenderContextPeerConnected(context, peerId: peerId)
            } else {
                context.delegate?.ristSenderContextPeerDisconnected(context, peerId: peerId)
            }
        }
        _ = rist_connection_status_callback_set(
            context,
            handleConnectionStatusChange,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
