import Foundation
import librist

public func ristVersion() -> String {
    return String(cString: librist_version()!)
}

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
    let context: RistContext

    init(peer: OpaquePointer, context: RistContext) {
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

public class RistContext {
    let context: OpaquePointer
    public var onStats: ((RistStats) -> Void)?
    public var onPeerConnected: ((UInt32) -> Void)?
    public var onPeerDisconnected: ((UInt32) -> Void)?

    public init?(senderProfile profile: rist_profile = RIST_PROFILE_MAIN) {
        var context: OpaquePointer?
        var result = withUnsafeMutablePointer(to: &context) { contextPointer in
            rist_sender_create(contextPointer, profile, 0, nil)
        }
        guard result == 0, let context else {
            return nil
        }
        let handleStats: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<rist_stats>?)
            -> Int32 = { contextArg, stats in
                guard let contextArg else {
                    return 0
                }
                let context: RistContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
                guard let stats = stats?.pointee.stats else {
                    return 0
                }
                context.onStats?(RistStats(sender: RistSenderStats(
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
        self.context = context
        onStats = nil
        result = rist_stats_callback_set(context, 200, handleStats, Unmanaged.passUnretained(self).toOpaque())
        guard result == 0 else {
            return nil
        }
        let handleConnectionStatusChange: @convention(c) (
            UnsafeMutableRawPointer?,
            OpaquePointer?,
            rist_connection_status
        ) -> Void = { contextArg, peer, status in
            guard let contextArg, let peer else {
                return
            }
            let context: RistContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
            let peerId = rist_peer_get_id(peer)
            if status == RIST_CONNECTION_ESTABLISHED {
                context.onPeerConnected?(peerId)
            } else {
                context.onPeerDisconnected?(peerId)
            }
        }
        _ = rist_connection_status_callback_set(
            context,
            handleConnectionStatusChange,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    deinit {
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

    public func start() -> Bool {
        return rist_start(context) == 0
    }
}
