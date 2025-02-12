import Foundation

public protocol ScreenCapturePacket: CustomStringConvertible {
  var header: Header { get }
  var data: Data { get }
}
