import Foundation
import FirebaseAnalytics
import Combine

class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Event Constants (matching Android FirebaseEventsLogs with _ios suffix)
    
    // Search Screen
    static let AMIIBO_SEARCH_SCREEN_OPENED = "search_screen_opened_ios"
    static let AMIIBO_LIST = "list_clicked_ios"
    static let AMIIBO_GRID = "grid_clicked_ios"
    static let AMIIBO_FILTER_TYPE_SEARCH = "filter_type_search_selected_ios"
    static let AMIIBO_FILTER_SET_SEARCH = "filter_set_search_selected_ios"
    static let AMIIBO_SORT_SEARCH = "sort_search_selected_ios"
    static let AMIIBO_SOUND = "sound_clicked_ios"
    
    // Collection Screen
    static let AMIIBO_DETAILS_OPENED = "details_opened_ios"
    static let AMIIBO_ADD_COLLECTION = "add_collection_clicked_ios"
    static let AMIIBO_ADD_WISHLIST = "add_wishlist_clicked_ios"
    static let AMIIBO_AMAZON = "amazon_clicked_ios"
    static let AMIIBO_MORE = "more_clicked_ios"
    static let AMIIBO_USAGE = "usage_clicked_ios"
    
    // Scanner Screen
    static let AMIIBO_SCANNER_SCREEN_OPENED = "scanner_screen_opened_ios"
    static let AMIIBO_ENABLE_SCANNER = "enable_scanner_clicked_ios"
    
    // Games Screen
    static let AMIIBO_GAMES_SCREEN_OPENED = "games_screen_opened_ios"
    static let GAME_AMAZON = "amazon_game_clicked_ios"
    static let GAMES_FILTER_SORT_SEARCH = "filter_sort_search_selected_games_ios"
    static let GAMES_FILTER_GENRE_SEARCH = "filter_genre_search_selected_games_ios"
    
    // Community Screen
    static let AMIIBO_COMMUNITY_SCREEN_OPENED = "community_screen_opened_ios"
    static let AMIIBO_LIKED = "liked_clicked_ios"
    static let AMIIBO_CREATE_POST = "create_post_clicked_ios"
    static let AMIIBO_CREATE_AVATAR = "create_avatar_clicked_ios"
    
    // Collections Screen
    static let AMIIBO_COLLECTIONS_SCREEN_OPENED = "collections_screen_opened_ios"
    static let AMIIBO_REMOVE_ADS = "remove_ads_clicked_ios"
    static let AMIIBO_THEME = "theme_clicked_ios"
    static let AMIIBO_IMAGE_DOWNLOAD = "image_download_clicked_ios"
    static let AMIIBO_IMAGE_DOWNLOAD_CONFIRMED = "image_download_confirmed_ios"
    static let AMIIBO_FILTER_TYPE_COLLECTION = "filter_type_collection_selected_ios"
    static let AMIIBO_FILTER_SET_COLLECTION = "filter_set_collection_selected_ios"
    static let AMIIBO_SORT_COLLECTION = "sort_collection_selected_ios"
    static let AMIIBO_FILTER_TYPE_WISHLIST = "filter_type_wishlist_selected_ios"
    static let AMIIBO_FILTER_SET_WISHLIST = "filter_set_wishlist_selected_ios"
    static let AMIIBO_SORT_WISHLIST = "sort_wishlist_selected_ios"
    
    // Support Screen
    static let AMIIBO_SUPPORT_SCREEN_OPENED = "support_screen_opened_ios"
    static let AMIIBO_RATE = "rate_clicked_ios"
    static let AMIIBO_KOFI = "kofi_clicked_ios"
    
    // MARK: - Logging Methods
    
    func logEvent(_ eventId: String, id: String = "", name: String = "") {
        var parameters: [String: Any] = [:]
        
        if !id.isEmpty {
            parameters[AnalyticsParameterItemID] = id
        }
        
        if !name.isEmpty {
            parameters[AnalyticsParameterItemName] = name
        }
        
        parameters[AnalyticsParameterContentType] = "button"
        
        Analytics.logEvent(eventId, parameters: parameters)
    }
    
    func logScreenView(_ screenName: String, screenClass: String = "") {
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName
        ]
        
        if !screenClass.isEmpty {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }
        
        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
    }
}
