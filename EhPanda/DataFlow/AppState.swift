//
//  AppState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import SwiftUI
import Foundation

struct AppState {
    var environment = Environment()
    var settings = Settings()
    var homeInfo = HomeInfo()
    var detailInfo = DetailInfo()
    var contentInfo = ContentInfo()
}

extension AppState {
    // MARK: Environment
    struct Environment {
        var isPreview = false
        var isAppUnlocked = true
        var blurRadius: CGFloat = 0
        var viewControllersCount = 1
        var isSlideMenuClosed = true
        var navBarHidden = false
        var favoritesIndex = -1
        var homeListType: HomeListType = .frontpage
        var homeViewSheetState: HomeViewSheetState?
        var settingViewSheetState: SettingViewSheetState?
        var settingViewActionSheetState: SettingViewActionSheetState?
        var filterViewActionSheetState: FilterViewActionSheetState?
        var detailViewSheetState: DetailViewSheetState?
        var commentViewSheetState: CommentViewSheetState?

        var mangaItemReverseID: String?
        var mangaItemReverseLoading = false
        var mangaItemReverseLoadFailed = false
    }

    // MARK: Settings
    struct Settings {
        var userInfoLoading = false
        var favoriteNamesLoading = false
        var greetingLoading = false

        var appEnv: AppEnv {
            PersistenceController.fetchAppEnvNonNil()
        }

        @AppEnvStorage(type: User.self)
        var user: User

        @AppEnvStorage(type: Filter.self)
        var filter: Filter

        @AppEnvStorage(type: Setting.self)
        var setting: Setting

        mutating func update(user: User) {
            if let displayName = user.displayName {
                self.user.displayName = displayName
            }
            if let avatarURL = user.avatarURL {
                self.user.avatarURL = avatarURL
            }
            if let currentGP = user.currentGP,
               let currentCredits = user.currentCredits
            {
                self.user.currentGP = currentGP
                self.user.currentCredits = currentCredits
            }
        }

        mutating func insert(greeting: Greeting) {
            guard let currDate = greeting.updateTime
            else { return }

            if let prevGreeting = user.greeting,
               let prevDate = prevGreeting.updateTime,
               prevDate < currDate
            {
                user.greeting = greeting
            } else if user.greeting == nil {
                user.greeting = greeting
            }
        }
    }
}

extension AppState {
    // MARK: HomeInfo
    struct HomeInfo {
        var searchKeyword = ""

        var searchItems: [Manga]?
        var searchLoading = false
        var searchNotFound = false
        var searchLoadFailed = false
        var searchCurrentPageNum = 0
        var searchPageNumMaximum = 1
        var moreSearchLoading = false
        var moreSearchLoadFailed = false

        var frontpageItems: [Manga]?
        var frontpageLoading = false
        var frontpageNotFound = false
        var frontpageLoadFailed = false
        var frontpageCurrentPageNum = 0
        var frontpagePageNumMaximum = 1
        var moreFrontpageLoading = false
        var moreFrontpageLoadFailed = false

        var popularItems: [Manga]?
        var popularLoading = false
        var popularNotFound = false
        var popularLoadFailed = false

        var watchedItems: [Manga]?
        var watchedLoading = false
        var watchedNotFound = false
        var watchedLoadFailed = false
        var watchedCurrentPageNum = 0
        var watchedPageNumMaximum = 1
        var moreWatchedLoading = false
        var moreWatchedLoadFailed = false

        var favoritesItems = [Int: [Manga]]()
        var favoritesLoading = generateBoolDict()
        var favoritesNotFound = generateBoolDict()
        var favoritesLoadFailed = generateBoolDict()
        var favoritesCurrentPageNum = generateIntDict()
        var favoritesPageNumMaximum = generateIntDict(defaultValue: 1)
        var moreFavoritesLoading = generateBoolDict()
        var moreFavoritesLoadFailed = generateBoolDict()

        @AppEnvStorage(type: [String].self, key: "historyKeywords")
        var historyKeywords: [String]

        static func generateBoolDict(defaultValue: Bool = false) -> [Int: Bool] {
            var tmp = [Int: Bool]()
            (-1..<10).forEach { index in
                tmp[index] = defaultValue
            }
            return tmp
        }

        static func generateIntDict(defaultValue: Int = 0) -> [Int: Int] {
            var tmp = [Int: Int]()
            (-1..<10).forEach { index in
                tmp[index] = defaultValue
            }
            return tmp
        }

        mutating func insertSearchItems(mangas: [Manga]) {
            mangas.forEach { manga in
                if searchItems?.contains(manga) == false {
                    searchItems?.append(manga)
                }
            }
        }
        mutating func insertFrontpageItems(mangas: [Manga]) {
            mangas.forEach { manga in
                if frontpageItems?.contains(manga) == false {
                    frontpageItems?.append(manga)
                }
            }
        }
        mutating func insertWatchedItems(mangas: [Manga]) {
            mangas.forEach { manga in
                if watchedItems?.contains(manga) == false {
                    watchedItems?.append(manga)
                }
            }
        }
        mutating func insertFavoritesItems(favIndex: Int, mangas: [Manga]) {
            mangas.forEach { manga in
                if favoritesItems[favIndex]?.contains(manga) == false {
                    favoritesItems[favIndex]?.append(manga)
                }
            }
        }
        mutating func insertHistoryKeyword(text: String) {
            guard !text.isEmpty else { return }

            if let index = historyKeywords.firstIndex(of: text) {
                if historyKeywords.last != text {
                    historyKeywords.remove(at: index)
                    historyKeywords.append(text)
                }
            } else {
                historyKeywords.append(text)

                let overflow = historyKeywords.count - 10

                if overflow > 0 {
                    historyKeywords = Array(
                        historyKeywords.dropFirst(overflow)
                    )
                }
            }

            self.historyKeywords = historyKeywords
        }
    }

    // MARK: DetailInfo
    struct DetailInfo {
        var detailLoading = [String: Bool]()
        var detailLoadFailed = [String: Bool]()
        var archiveFundsLoading = false
        var previews = [String: [Int: String]]()
        var previewsLoading = [String: [Int: Bool]]()
        var previewConfig = PreviewConfig.normal(rows: 4)

        @AppEnvStorage(type: Translator.self)
        var translator: Translator

        mutating func fulfillPreviews(gid: String) {
            let mangaState = PersistenceController
                .fetchMangaStateNonNil(gid: gid)
            previews[gid] = mangaState.previews
        }

        mutating func update(gid: String, previews: [Int: String]) {
            guard !previews.isEmpty else { return }

            if self.previews[gid] == nil {
                self.previews[gid] = [:]
            }
            self.previews[gid] = self.previews[gid]?.merging(
                previews, uniquingKeysWith:
                    { stored, _ in stored }
            )
        }
    }

    struct ContentInfo {
        var mpvKeys = [String: String]()
        var mpvImageKeys = [String: [Int: String]]()
        var mpvImageLoading = [String: [Int: Bool]]()
        var contents = [String: [Int: String]]()
        var contentsLoading = [String: [Int: Bool]]()
        var contentsLoadFailed = [String: [Int: Bool]]()

        mutating func fulfillContents(gid: String) {
            let mangaState = PersistenceController
                .fetchMangaStateNonNil(gid: gid)
            contents[gid] = mangaState.contents
        }

        mutating func update(gid: String, contents: [Int: String]) {
            guard !contents.isEmpty else { return }

            if self.contents[gid] == nil {
                self.contents[gid] = [:]
            }
            self.contents[gid] = self.contents[gid]?.merging(
                contents, uniquingKeysWith:
                    { stored, _ in stored }
            )
        }
    }
}
