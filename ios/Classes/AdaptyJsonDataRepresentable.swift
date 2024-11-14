
import Adapty
import AdaptyUI
import AdaptyPlugin

protocol AdaptyJsonDataRepresentable {
    var asAdaptyJsonData: AdaptyJsonData  { get throws }
}

extension AdaptyError: AdaptyJsonDataRepresentable {}
extension AdaptyPaywall: AdaptyJsonDataRepresentable {}
extension AdaptyProfile: AdaptyJsonDataRepresentable {}
extension AdaptyPurchaseResult: AdaptyJsonDataRepresentable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
extension AdaptyUI.Action: AdaptyJsonDataRepresentable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
extension AdaptyUI.View: AdaptyJsonDataRepresentable {}

