import Foundation

class Ping: ScreenCapturePacket {
  let header: Header
  let data: Data

  var description: String {
    "<ping size:\(data.count)>"
  }

  static let instance: Ping = {
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
