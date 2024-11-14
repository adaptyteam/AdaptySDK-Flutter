import Foundation

enum Argument: String
{
    case view
    case action
    case product
    case productId = "product_id"
    case profile
    case purchasedResult = "purchased_result"
    case error
    case configuration
}

enum Method: String
{
    case didLoadLatestProfile = "did_load_latest_profile"

    case paywallViewDidPerformAction = "paywall_view_did_perform_action"
    case paywallViewDidSelectProduct = "paywall_view_did_select_product"
    case paywallViewDidStartPurchase = "paywall_view_did_start_purchase"
    case paywallViewDidCancelPurchase = "paywall_view_did_cancel_purchase"
    case paywallViewDidFinishPurchase = "paywall_view_did_finish_purchase"
    case paywallViewDidFailPurchase = "paywall_view_did_fail_purchase"
    case paywallViewDidStartRestore = "paywall_view_did_start_restore"
    case paywallViewDidFinishRestore = "paywall_view_did_finish_restore"
    case paywallViewDidFailRestore = "paywall_view_did_fail_restore"
    case paywallViewDidFailRendering = "paywall_view_did_fail_rendering"
    case paywallViewDidFailLoadingProducts = "paywall_view_did_fail_loading_products"
}
