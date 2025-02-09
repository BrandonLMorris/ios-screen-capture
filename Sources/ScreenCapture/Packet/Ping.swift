import Foundation

public class Ping: ScreenCapturePacket {
  public let header: Header
  public let data: Data

  public var description: String = "[PING]"

  nonisolated(unsafe) public static let instance: Ping = {
    let data = Data(base64Encoded: "EAAAAGduaXAAAAAAAQAAAA==")!
    return Ping(header: Header(data)!, data: data)!
  }()

  init?(header: Header, data: Data) {
    self.header = header
    self.data = data
  }

  lazy var isValid: Bool = {
    return header.type == .ping && data.count == 16
  }()
}
