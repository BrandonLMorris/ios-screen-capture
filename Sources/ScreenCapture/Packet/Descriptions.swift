import Foundation
import Object

/// This packet tells the recording host (the device) info about the video
/// stream we're expecting.
public class HostDescription: ScreenCapturePacket {
  public let description = "[HPD1] Host description dict"
  public nonisolated(unsafe) static let dimensions = Dictionary.create(
    ("Width", .number(Number(float64: 1920.0))),
    ("Height", .number(Number(float64: 1200.0)))
  )
  public nonisolated(unsafe) static let deviceInfo = Dictionary.create(
    ("Valeria", .bool(true)),
    ("HEVCDecoderSupports444", .bool(true)),
    ("DisplaySize", .dict(HostDescription.dimensions))
  )

  public init() {}

  public lazy var header: Header = {
    let dictPayload = HostDescription.deviceInfo.serialize()
    return Header(length: dictPayload.count + 20, type: .async, subtype: .hostDescription)
  }()

  public lazy var data: Data = {
    var fullPacket = self.header.serialized
    fullPacket.append(HostDescription.deviceInfo.serialize())

    return fullPacket
  }()
}

public class StreamDescription: ScreenCapturePacket {
  public var header: Header
  public private(set) var data: Data
  public lazy var description = "[HPA1] Stream description dict"
  nonisolated(unsafe) private static let payload = Dictionary.create(
    ("BufferAheadInterval", .number(Number(float64: 0.07300000000000001))),
    ("deviceUID", .string("Valeria")),
    ("ScreenLatency", .number(Number(float64: 0.04))),
    ("formats", .data(StreamDescription.audioDescription)),
    ("EDIDAC3Support", .number(Number(int32: 0))),
    ("deviceName", .string("Valeria"))
  )

  public init(clock: CFTypeID) {
    header = Header(length: 337, type: .async, subtype: .streamDesciption, payload: clock)
    var wholePacket = Data(header.serialized)
    wholePacket.append(StreamDescription.payload.serialize())
    data = wholePacket
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
