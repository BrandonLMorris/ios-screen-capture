import Foundation
import os.log

protocol ScreenCapturePacket: CustomStringConvertible {
  var header: Header { get }
  var data: Data { get }
}
