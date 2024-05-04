import Foundation

struct Header: Equatable {
  let length: Int
  let type: PacketType
  let subtype: PacketSubtype
  var payload = Data(count: 8)

  private let minLength = 8
  private static let typeRange = 4..<8
  private static let payloadRange = 8..<16
  private static let subtypeRange = 16..<20

  var serialized: Data {
    let hasSubtype = subtype != .none
    var res = Data(count: hasSubtype ? 20 : 8)
    res.uint32(at: 0, UInt32(length))
    res.copyInto(at: 4, from: type.rawValue)
    res.copyInto(at: 8, from: payload)
    if hasSubtype {
      // Note the empty 8 bytes between type and subtype.
      res.copyInto(at: 16, from: subtype.rawValue)
    }
    return res
  }

  internal init(length: Int, type: PacketType, subtype: PacketSubtype = .none) {
    self.length = length
    self.type = type
    self.subtype = subtype
  }

  public init?(_ source: Data) {
    if source.count < minLength {
      logger.error("Failed to parse packet header: Not enough data (\(source.count) bytes)")
      return nil
    }
    length = Int(source[uint32: 0])
    let typeStr = Header.parseType(in: source)
    guard let type = PacketType(rawValue: String(typeStr)) else {
      logger.error("Unable to parse packet of type \(typeStr)")
      return nil
    }
    self.type = type

    // Set the subtype
    if type == .ping {
      self.subtype = .none
      return
    }
    self.payload = source[Header.payloadRange]
    let subtypeStr = Header.parseType(in: source, isSubtype: true)
    guard let subtype = PacketSubtype(rawValue: String(subtypeStr)) else {
      logger.error("Unable to parse packet subtype: \(subtypeStr)")
      return nil
    }
    self.subtype = subtype
  }

  private static func parseType(in src: Data, isSubtype: Bool = false) -> String {
    let rng = isSubtype ? subtypeRange : typeRange
    let raw = src.subdata(in: rng)
    // Need to reverse to account for endianness
    return String(String(data: raw, encoding: .ascii)!.reversed())
  }
}
