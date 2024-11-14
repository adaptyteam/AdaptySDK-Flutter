
import Adapty

extension Log {
    static func Category(name: String) -> AdaptyLog.Category {
        AdaptyLog.Category(
            subsystem: "io.adapty.flutter",
            version: Adapty.SDKVersion,
            name: name
        )
    }

    static let wrapper = Category(name: "wrapper")
}
