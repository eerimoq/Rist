import Foundation
import librist

public func ristVersion() -> String {
    return String(cString: librist_version()!)
}

public class RistPeer {
    let peer: OpaquePointer

    init(peer: OpaquePointer) {
        self.peer = peer
    }
}

public class RistContext {
    let context: OpaquePointer

    public init?(senderProfile _: rist_profile = RIST_PROFILE_SIMPLE) {
        var context: OpaquePointer?
        let result = withUnsafeMutablePointer(to: &context) { contextPointer in
            rist_sender_create(contextPointer, RIST_PROFILE_SIMPLE, 0, nil)
        }
        guard result == 0, let context else {
            return nil
        }
        self.context = context
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
        return RistPeer(peer: peer)
    }

    public func senderWrite(data: Data) -> Bool {
        let writtenCount = data.withUnsafeBytes { dataPointer in
            var dataBlock: rist_data_block = .init(
                payload: dataPointer.baseAddress,
                payload_len: data.count,
                ts_ntp: 0,
                virt_src_port: 0,
                virt_dst_port: 0,
                peer: nil,
                flow_id: 0,
                seq: 0,
                flags: 0,
                ref: nil
            )
            return withUnsafePointer(to: &dataBlock) { dataBlockPointer in
                rist_sender_data_write(context, dataBlockPointer)
            }
        }
        return writtenCount == data.count
    }

    public func start() -> Bool {
        return rist_start(context) == 0
    }
}
