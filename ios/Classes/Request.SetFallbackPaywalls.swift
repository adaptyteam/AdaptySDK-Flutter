import Adapty
import AdaptyPlugin
import Flutter

enum Request {
    enum SetFallbackPaywallsError: LocalizedError {
        case assetNotFound(id: String)
        
        var localizedDescription: String {
            switch self {
            case .assetNotFound(let id):
                "Asset \(id) not found"
            }
        }
    }
    
    struct SetFallbackPaywalls: AdaptyPluginRequest {
        static let method = "set_fallback_paywalls"
        let assetId: String

        private enum CodingKeys: String, CodingKey {
            case assetId = "asset_id"
        }

        func execute() async throws -> AdaptyJsonData {
            let fallbackFileKey = FlutterDartProject.lookupKey(forAsset: assetId)
            guard let url = Bundle.main.url(forResource: fallbackFileKey, withExtension: nil) else {
                throw SetFallbackPaywallsError.assetNotFound(id: assetId)
            }

            try await Adapty.setFallbackPaywalls(fileURL: url)

            return .success()
        }
    }
}
