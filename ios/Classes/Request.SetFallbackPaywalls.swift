import Adapty
import AdaptyPlugin
import Flutter

enum Request {
    struct SetFallbackPaywalls: AdaptyPluginRequest {
        static let method = "set_fallback_paywalls"
        let assetId: String

        private enum CodingKeys: String, CodingKey {
            case assetId = "asset_id"
        }

        init(from jsonDictionary: AdaptyJsonDictionary) throws {
            try self.init(
                jsonDictionary.value(String.self, forKey: CodingKeys.assetId)
            )
        }

        init(_ assetId: String) {
            self.assetId = assetId
        }

        func execute() async throws -> AdaptyJsonData {
            let fallbackFileKey = FlutterDartProject.lookupKey(forAsset: assetId)
            guard let url = Bundle.main.url(forResource: fallbackFileKey, withExtension: nil) else {
//                throw AdaptyPluginError
                return .failure(nil) // TODO: throw error
            }

            try await Adapty.setFallbackPaywalls(fileURL: url)

            return .success()
        }
    }
}
