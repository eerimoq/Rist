import Foundation
import librist

public protocol RistReceiverContextDelegate: AnyObject {
    func ristReceiverContextConnected(_ virtualDestinationPort: UInt16)
    func ristReceiverContextDisconnected(_ virtualDestinationPort: UInt16)
    func ristReceiverContextReceivedData(_ virtualDestinationPort: UInt16, packets: [Data])
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

private final class Stream {
    var peers: Set<OpaquePointer?> = []
    var receivedPackets: [Data] = []
    var latestReceivedPacketsTime = ContinuousClock.now

    init() {}
}

public final class RistReceiverContext {
    private let context: OpaquePointer
    private let peer: OpaquePointer
    public weak var delegate: RistReceiverContextDelegate?
    private var streams: [UInt16: Stream] = [:]

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

    public func start() -> Bool {
        return rist_start(context) == 0
    }

    public func stop() {
        rist_peer_destroy(context, peer)
        rist_destroy(context)
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
            context.handleConnectionStatusCallback(status: status, peer: peer)
        }
        _ = rist_connection_status_callback_set(
            context,
            handleConnectionStatusChange,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func handleConnectionStatusCallback(status: rist_connection_status, peer: OpaquePointer?) {
        guard status != RIST_CLIENT_CONNECTED else {
            return
        }
        if let (virtualDestinationPort, stream) = streams.first(where: { $0.value.peers.contains(peer) }) {
            stream.peers.remove(peer)
            if stream.peers.isEmpty {
                streams.removeValue(forKey: virtualDestinationPort)
                delegate?.ristReceiverContextDisconnected(virtualDestinationPort)
            }
        }
    }

    private func setDataHandlerCallback() {
        let handleReceiveData: @convention(c) (
            UnsafeMutableRawPointer?, UnsafeMutablePointer<rist_data_block>?
        ) -> Int32 = { contextArg, dataBlockPtr in
            var dataBlockPtr = dataBlockPtr
            guard let contextArg else {
                rist_receiver_data_block_free2(&dataBlockPtr)
                return -1
            }
            let context: RistReceiverContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
            return context.handleDataHandlerCallback(dataBlockPtr: dataBlockPtr)
        }
        _ = rist_receiver_data_callback_set2(
            context,
            handleReceiveData,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func handleDataHandlerCallback(dataBlockPtr: UnsafeMutablePointer<rist_data_block>?) -> Int32 {
        var dataBlockPtr = dataBlockPtr
        guard let dataBlock = dataBlockPtr?.pointee else {
            rist_receiver_data_block_free2(&dataBlockPtr)
            return -1
        }
        var stream = streams[dataBlock.virt_dst_port]
        if stream == nil {
            stream = Stream()
            streams[dataBlock.virt_dst_port] = stream!
            delegate?.ristReceiverContextConnected(dataBlock.virt_dst_port)
        }
        guard let stream else {
            rist_receiver_data_block_free2(&dataBlockPtr)
            return -1
        }
        stream.peers.insert(dataBlock.peer)
        let data = Data(bytes: dataBlock.payload!, count: dataBlock.payload_len)
        stream.receivedPackets.append(data)
        let now = ContinuousClock.now
        guard stream.latestReceivedPacketsTime.duration(to: now) > .milliseconds(50) else {
            rist_receiver_data_block_free2(&dataBlockPtr)
            return 0
        }
        delegate?.ristReceiverContextReceivedData(dataBlock.virt_dst_port, packets: stream.receivedPackets)
        stream.latestReceivedPacketsTime = now
        stream.receivedPackets = []
        rist_receiver_data_block_free2(&dataBlockPtr)
        return 0
    }
}
