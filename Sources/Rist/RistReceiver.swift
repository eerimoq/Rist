import Foundation
import librist

public protocol RistReceiverContextDelegate: AnyObject {
    func ristReceiverContextConnected(_ context: RistReceiverContext)
    func ristReceiverContextDisconnected(_ context: RistReceiverContext)
    func ristReceiverContextReceivedData(_ context: RistReceiverContext, data: Data)
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

public class RistReceiverContext {
    private let context: OpaquePointer
    private let peer: OpaquePointer
    public weak var delegate: RistReceiverContextDelegate?

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
        ) -> Void = { contextArg, _, status in
            guard let contextArg else {
                return
            }
            let context: RistReceiverContext = Unmanaged.fromOpaque(contextArg).takeUnretainedValue()
            if status == RIST_CLIENT_CONNECTED {
                context.delegate?.ristReceiverContextConnected(context)
            } else {
                context.delegate?.ristReceiverContextDisconnected(context)
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
            let data = Data(bytes: dataBlock.payload!, count: dataBlock.payload_len)
            context.delegate?.ristReceiverContextReceivedData(context, data: data)
            rist_receiver_data_block_free2(&dataBlockPtr)
            return 0
        }
        _ = rist_receiver_data_callback_set2(
            context,
            handleReceiveData,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
