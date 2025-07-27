import Foundation
import librist

public protocol RistReceiverContextDelegate: AnyObject {
    func ristReceiverContextConnected(_ context: RistReceiverContext, _ virtualDestinationPort: UInt16)
    func ristReceiverContextDisconnected(_ context: RistReceiverContext, _ virtualDestinationPort: UInt16)
    func ristReceiverContextReceivedData(_ context: RistReceiverContext,
                                         _ virtualDestinationPort: UInt16,
                                         packets: [Data])
}

private func createReceiverContext(profile: rist_profile) -> OpaquePointer? {
    var context: OpaquePointer?
    let result = withUnsafeMutablePointer(to: &context) { contextPointer in
        rist_receiver_create(contextPointer, profile, nil)
    }
    guard result == 0 else {
        return nil
    }
    return context
}

private func createReceiverPeer(context: OpaquePointer, inputUrl: String) -> OpaquePointer? {
    var config: UnsafeMutablePointer<rist_peer_config>?
    var result = withUnsafeMutablePointer(to: &config) { configPointer in
        rist_parse_address2(inputUrl.cString(using: .utf8), configPointer)
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
    guard result == 0 else {
        return nil
    }
    return peer
}

private class Peer {
    let peer: OpaquePointer?
    var virtualDestinationPort: UInt16?
    var packets: [Data] = []
    var latestReceivedPacketsTime = ContinuousClock.now

    init(peer: OpaquePointer?) {
        self.peer = peer
    }
}

public class RistReceiverContext {
    private let context: OpaquePointer
    private let peer: OpaquePointer
    public weak var delegate: RistReceiverContextDelegate?
    private var connectedPeersById: [UInt32: Peer] = [:]

    public init?(inputUrl: String, profile: rist_profile = RIST_PROFILE_MAIN) {
        guard let context = createReceiverContext(profile: profile) else {
            return nil
        }
        self.context = context
        guard let peer = createReceiverPeer(context: context, inputUrl: inputUrl) else {
            rist_destroy(context)
            return nil
        }
        self.peer = peer
        setConnectionStatusCallback()
        setDataHandlerCallback()
    }

    deinit {
        rist_peer_destroy(context, peer)
        rist_destroy(context)
    }

    public func start() -> Bool {
        return rist_start(context) == 0
    }

    private func setConnectionStatusCallback() {
        let handleConnectionStatusChange: @convention(c) (
            UnsafeMutableRawPointer?,
            OpaquePointer?,
            rist_connection_status
        ) -> Void = { contextArg, peer, status in
            guard let contextArg else {
                return
            }
            let context: RistReceiverContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
            let peerId = rist_peer_get_id(peer)
            if status == RIST_CLIENT_CONNECTED {
                context.connectedPeersById[peerId] = Peer(peer: peer)
            } else {
                let peer = context.connectedPeersById.removeValue(forKey: peerId)
                if let virtualDestinationPort = peer?.virtualDestinationPort {
                    context.delegate?.ristReceiverContextDisconnected(context, virtualDestinationPort)
                }
            }
        }
        _ = rist_connection_status_callback_set(
            context,
            handleConnectionStatusChange,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func setDataHandlerCallback() {
        let handleReceiveData: @convention(c) (
            UnsafeMutableRawPointer?, UnsafeMutablePointer<rist_data_block>?
        ) -> Int32 = { contextArg, dataBlockPtr in
            var dataBlockPtr = dataBlockPtr
            guard let contextArg, let dataBlock = dataBlockPtr?.pointee else {
                rist_receiver_data_block_free2(&dataBlockPtr)
                return -1
            }
            let context: RistReceiverContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
            guard let peer = context.connectedPeersById[rist_peer_get_id(dataBlock.peer)] else {
                rist_receiver_data_block_free2(&dataBlockPtr)
                return -1
            }
            if peer.virtualDestinationPort == nil {
                peer.virtualDestinationPort = dataBlock.virt_dst_port
                context.delegate?.ristReceiverContextConnected(context, dataBlock.virt_dst_port)
            }
            let data = Data(bytes: dataBlock.payload!, count: dataBlock.payload_len)
            peer.packets.append(data)
            rist_receiver_data_block_free2(&dataBlockPtr)
            let now = ContinuousClock.now
            guard peer.latestReceivedPacketsTime.duration(to: now) > .milliseconds(50) else {
                return 0
            }
            peer.latestReceivedPacketsTime = now
            context.delegate?.ristReceiverContextReceivedData(context,
                                                              dataBlock.virt_dst_port,
                                                              packets: peer.packets)
            peer.packets = []
            return 0
        }
        _ = rist_receiver_data_callback_set2(
            context,
            handleReceiveData,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
