import Foundation

/// This packet tells the recording host (the device) info about the video
/// stream we're expecting.
class HostDescription: ScreenCapturePacket {
  var header: Header
  var data: Data
  let description = "[HPD1] Host description dict"

  init() {
    data = HostDescription.initializeData()
    header = Header(length: Int(data[uint32: 0]), type: .async)
  }

  private static func initializeData() -> Data {
    var deviceInfo = Dictionary()
    deviceInfo["Valeria"] = .bool(true)
    deviceInfo["HEVCDecoderSupports444"] = .bool(true)
    var dimensions = Dictionary()
    dimensions["Width"] = .number(Number(float64: 1920.0))
    dimensions["Height"] = .number(Number(float64: 1200.0))
    deviceInfo["DisplaySize"] = .dict(dimensions)
    let dictPayload = deviceInfo.serialize()

    var header = Header(length: dictPayload.count + 20, type: .async, subtype: .hostDescription)
      .serialized
    header.append(dictPayload)

    return header
  }
}
