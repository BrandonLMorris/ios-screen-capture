import Foundation

class SetProperty: ScreenCapturePacket {
  var header: Header
  var data: Data
  lazy var description: String = {
    """
    [SPRP] Set property
        key: \(propertyKey)
        value: \(propertyValue)
    """
  }()

  internal let propertyKey: String
  internal let propertyValue: DictValue

  init?(header: Header, wholePacket: Data) {
    self.header = header
    self.data = wholePacket

    var idx = 20
    let payloadLength = Int(data[uint32: idx])
    guard data.count >= idx + payloadLength else { return nil }

    guard let kvPrefix = Prefix(data.from(idx)), kvPrefix.type == .keyValue else { return nil }
    idx += 8

    guard let keyPrefix = Prefix(data.from(idx)), keyPrefix.type == .stringKey else { return nil }
    let keyRange = (idx + 8)..<(idx + Int(keyPrefix.length))
    guard let property = String(data: data.subdata(in: keyRange), encoding: .ascii) else {
      return nil
    }
    propertyKey = property
    idx += Int(keyPrefix.length)

    guard let valuePrefix = Prefix(data.from(idx)) else { return nil }
    let valueRange = (idx + 8)..<(idx + Int(valuePrefix.length))
    let valueData = Data(data.subdata(in: valueRange))

    // Nb in my samples this was a bool, but might not always be
    propertyValue = .bool(valueData[0] != 0)
  }
}
