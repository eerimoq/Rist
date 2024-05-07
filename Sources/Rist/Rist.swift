import librist

public func ristVersion() -> String {    
    return String(cString: librist_version()!)
}

public class RistContext {
    let context: OpaquePointer
    
    init(context: OpaquePointer) {
        self.context = context
    }
}

public func ristSenderCreate() -> RistContext? {
    var context: OpaquePointer? = nil
    let result = withUnsafeMutablePointer(to: &context) { contextPointer in
        return rist_sender_create(contextPointer, RIST_PROFILE_SIMPLE, 0, nil)
    }
    guard result == 0, let context else {
        return nil
    }
    return RistContext(context: context)
}
