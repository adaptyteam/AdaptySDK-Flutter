//
//  SwiftAdaptyProfileBuilder.swift
//  adapty_flutter
//
//  Created by Aleksey Goncharov on 24.11.2020.
//

import Adapty


class SwiftAdaptyProfileBuilder {
    private static let dateFormatter = DateFormatter()

    static func createBuilder(map: [String: Any]) -> AdaptyProfileParameters.Builder {
        AdaptyProfileParameters.empty.builder()
//        let builder = ProfileParameterBuilder()
//
//        if let email = map["email"] as? String {
//            _ = builder.withEmail(email)
//        }
//
//        if let phoneNumber = map["phone_number"] as? String {
//            _ = builder.withPhoneNumber(phoneNumber)
//        }
//
//        if let facebookUserId = map["facebook_user_id"] as? String {
//            _ = builder.withFacebookUserId(facebookUserId)
//        }
//
//        if let amplitudeUserId = map["amplitude_user_id"] as? String {
//            _ = builder.withAmplitudeUserId(amplitudeUserId)
//        }
//
//        if let amplitudeDeviceId = map["amplitude_device_id"] as? String {
//            _ = builder.withAmplitudeDeviceId(amplitudeDeviceId)
//        }
//
//        if let mixpanelUserId = map["mixpanel_user_id"] as? String {
//            _ = builder.withMixpanelUserId(mixpanelUserId)
//        }
//        if let appmetricaProfileId = map["appmetrica_profile_id"] as? String {
//            _ = builder.withAppmetricaProfileId(appmetricaProfileId)
//        }
//        if let appmetricaDeviceId = map["appmetrica_device_id"] as? String {
//            _ = builder.withAppmetricaDeviceId(appmetricaDeviceId)
//        }
//
//        if let firstName = map["first_name"] as? String {
//            _ = builder.withFirstName(firstName)
//        }
//
//        if let lastName = map["last_name"] as? String {
//            _ = builder.withLastName(lastName)
//        }
//
//        if let genderValue = map["gender"] as? String,
//           let gender = Gender.fromAnyString(genderValue) {
//            _ = builder.withGender(gender)
//        }
//
//        if let birthdayString = map["birthday"] as? String {
//            dateFormatter.dateFormat = "yyyy-MM-dd"
//            dateFormatter.timeZone = TimeZone(identifier: "UTC")
//            if let birthday = dateFormatter.date(from: birthdayString) {
//                _ = builder.withBirthday(birthday)
//            }
//        }
//
//        if let customAttributes = map["custom_attributes"] as? [String: Any] {
//            _ = builder.withCustomAttributes(customAttributes)
//        }
//
//        if #available(iOS 14, *), let status = map["att_status"] as? String {
//            switch status {
//            case "notDetermined":
//                _ = builder.withAppTrackingTransparencyStatus(.notDetermined)
//            case "restricted":
//                _ = builder.withAppTrackingTransparencyStatus(.restricted)
//            case "denied":
//                _ = builder.withAppTrackingTransparencyStatus(.denied)
//            case "authorized":
//                _ = builder.withAppTrackingTransparencyStatus(.authorized)
//            default:
//                break
//            }
//        }
//
//        if let facebookAnonymousId = map["facebook_anonymous_id"] as? String {
//            _ = builder.withFacebookAnonymousId(facebookAnonymousId)
//        }
//
//        return builder
    }
}
