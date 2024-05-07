import librist

public func ristVersion() -> String {    
    return String(cString: librist_version()!)
}
