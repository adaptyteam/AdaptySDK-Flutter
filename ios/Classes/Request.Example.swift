
import AdaptyPlugin

// enum Request {
//     struct Example: AdaptyPluginRequest {
//         static let method = "example"
//         let value: String

//         private enum CodingKeys: CodingKey {
//             case value
//         }
        
//         init(from jsonDictionary: AdaptyJsonDictionary) throws {
//             try self.init(
//                 jsonDictionary.value(String.self, forKey: CodingKeys.value)
//             )
//         }
        
//         init(_ value: String) {
//             self.value = value
//         }
        
//         func execute() async throws -> AdaptyJsonData {
//             // TODO
            
//             return .success()
//         }
//     }
// }