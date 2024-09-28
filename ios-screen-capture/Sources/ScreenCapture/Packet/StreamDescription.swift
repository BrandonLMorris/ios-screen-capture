import Foundation

class StreamDescription: ScreenCapturePacket {
  var header: Header
  private(set) var data: Data
  lazy var description: String = {
    """
    [HPA1] Stream description dict
    """
  }()

  init(clock: CFTypeID) {
    header = Header(length: 337, type: .async, subtype: .streamDesciption, payload: clock)
    var wholePacket = Data(header.serialized)
    wholePacket.append(StreamDescription.initializeData())
    data = wholePacket
  }

  private static func initializeData() -> Data {
    var data = Dictionary()
    data["BufferAheadInterval"] = .number(Number(float64: 0.07300000000000001))
    data["deviceUID"] = .string("Valeria")
    data["ScreenLatency"] = .number(Number(float64: 0.04))
    data["formats"] = .data(StreamDescription.audioDescription)
    data["EDIDAC3Support"] = .number(Number(int32: 0))
    data["deviceName"] = .string("Valeria")
    return data.serialize()
  }

  private static var audioDescription: Data {
    var result = Data(count: 56)
    var idx = 0
    result.float64(at: idx, 48000.0)  // Sample rate
    idx += 8
    for v: UInt32 in [
      1_819_304_813,  // Format id
      12,  // Format flags
      4,  // Bytes per packet
      1,  // Frames per packet
      4,  // Bytes per frame
      2,  // Channels per frame
      16,  // Bits per channel
      0,  // reserved
    ] {
      result.uint32(at: idx, v)
      idx += 4
    }
    for _ in 1...2 {
      result.float64(at: idx, 48000.0)  // Sample rate
      idx += 8
    }
    return result
  }
}
