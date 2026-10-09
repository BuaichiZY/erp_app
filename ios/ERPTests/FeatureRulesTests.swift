import XCTest
#if !LAYOUT_CHECK
@testable import ERP
#endif

final class FeatureRulesTests: XCTestCase {
    func testBrowseDefaultsToFreeSortAndDropsRevokedMemberSorts() {
        XCTAssertEqual(BrowseRules.sorts(.null), ["hot"])
        XCTAssertEqual(BrowseRules.selected("new", me: .null), "hot")
        let member: JSON = .object(["browse": .object(["sorts": .array([.string("hot"), .string("new"), .string("active"), .string("new"), .string("")])])])
        XCTAssertEqual(BrowseRules.sorts(member), ["hot", "new", "active"])
        XCTAssertEqual(BrowseRules.selected("new", me: member), "new")
        XCTAssertEqual(BrowseRules.selected("unknown", me: member), "hot")
        XCTAssertEqual(BrowseRules.selected("hot", me: member), "hot")
    }
    func testNestedEditorUpdatesPreserveOtherFieldsAndNulls() throws {
        let original: JSON = .object(["adult": .object(["limits": .array([.object(["item": .string("A"), "level": .string("maybe"), "tagId": .string("tag")])]), "safeword": .string("stop")]), "voiceCardId": .string("old")])
        let updated = original.replacing(at: ["adult", "bio"], with: .string("new")).replacing(at: ["voiceCardId"], with: .null)
        XCTAssertEqual(updated["adult"]["limits"], original["adult"]["limits"])
        XCTAssertEqual(updated["adult"]["safeword"].string, "stop")
        let bytes = try JSON.body(updated.object.mapValues(\.foundation))
        XCTAssertEqual(try JSONDecoder().decode(JSON.self, from: bytes), updated)
    }
    func testCategoryMergeDeduplicatesAndPaginatesEachStream() {
        let a: JSON = .object(["id": .string("a"), "createdAt": .string("2026-10-01")])
        let b: JSON = .object(["id": .string("b"), "createdAt": .string("2026-10-03")])
        let c: JSON = .object(["id": .string("c"), "createdAt": .string("2026-10-02")])
        XCTAssertEqual(PostCategoryRules.merge([[a, b], [a, c]], existing: [], sort: "mix").map(\.id), ["a", "b", "c"])
        XCTAssertEqual(PostCategoryRules.merge([[a, b], [c]], existing: [a], sort: "new").map(\.id), ["b", "c", "a"])
    }
    func testSharedProfileLinksAcceptOfficialPathsOnly() {
        for path in ["/s/user-1?invite=ABC", "/u/user-1", "/profiles/user-1", "/likes?u=user-1"] { XCTAssertEqual(ERPRules.profileID("https://erp.sex" + path), "user-1") }
        for link in ["https://erp.sex.evil/s/user-1", "http://erp.sex/s/user-1", "https://erp.sex/s/user-1/more", "https://evil@erp.sex/s/user-1"] { XCTAssertNil(ERPRules.profileID(link)) }
    }
    func testBlurredMediaCannotLeakClearImageOrThumbnail() {
        let media: JSON = .object(["view": .string("blur"), "url": .string("https://erp.sex/clear"), "thumbUrl": .string("https://erp.sex/clear-thumb"), "blurUrl": .string("https://erp.sex/blur")])
        XCTAssertEqual(MediaVisibility.imageURL(media, thumbnail: true)?.path, "/blur")
        XCTAssertNil(MediaVisibility.imageURL(media.replacing(at: ["blurUrl"], with: .null)))
        XCTAssertNil(MediaVisibility.imageURL(media.replacing(at: ["view"], with: .string("hide"))))
        XCTAssertEqual(MediaVisibility.imageURL(media.replacing(at: ["view"], with: .string("show")))?.path, "/clear")
    }
    func testServerPinsKeepConversationOrderStable() {
        let rows: [JSON] = [false, true, false, true].enumerated().map { .object(["id": .string(String($0.offset)), "pinned": .bool($0.element)]) }
        XCTAssertEqual(MatchOrdering.pinnedFirst(rows).map(\.id), ["1", "3", "0", "2"])
    }
    func testReadAcknowledgementsStopRealtimeFeedbackAndRetryFailures() {
        var tracker = ChatReadTracker()
        XCTAssertFalse(tracker.begin(""))
        XCTAssertTrue(tracker.begin("first"))
        XCTAssertFalse(tracker.begin("first"))
        XCTAssertFalse(tracker.begin("second"))
        tracker.finish("other", succeeded: true)
        XCTAssertFalse(tracker.begin("first"))
        tracker.finish("first", succeeded: true)
        for _ in 0..<100 { XCTAssertFalse(tracker.begin("first")) }
        XCTAssertTrue(tracker.begin("second"))
        tracker.finish("second", succeeded: false)
        XCTAssertTrue(tracker.begin("second"))
        tracker.finish("second", succeeded: true)
        XCTAssertEqual(tracker.acknowledged, "second")
    }
    func testRealtimeCounterAndConnectionPacketsDoNotReloadContent() {
        for type in ["counters", "ping", "pong", "hello", "energy.updated", "notification.created"] { XCTAssertFalse(RealtimeRules.refreshesContent(type)) }
        for type in ["message.created", "message.read", "message.recalled", "match.updated", "post.updated", "guestbook.created"] { XCTAssertTrue(RealtimeRules.refreshesContent(type)) }
    }

    func testMatchSearchSupportsCJKCaseAndCompatibilityCharacters() {
        let user: JSON = .object(["displayName": .string("小猫 Alice"), "username": .string("VRC_Player")])
        XCTAssertTrue(MatchSearch.matches(user, query: "猫"))
        XCTAssertTrue(MatchSearch.matches(user, query: "a"))
        XCTAssertTrue(MatchSearch.matches(user, query: "ＡＬＩＣＥ"))
        XCTAssertTrue(MatchSearch.matches(user, query: "player"))
        XCTAssertTrue(MatchSearch.matches(user, query: "  "))
        XCTAssertFalse(MatchSearch.matches(user, query: "Bob"))
    }
    func testVRChatTrustColorsAndNestedVerification() {
        XCTAssertEqual(VRCTrust.background("user"), 0x2bcf5c)
        XCTAssertEqual(VRCTrust.background("known_user"), 0xff7b42)
        XCTAssertEqual(VRCTrust.background("trusted_user"), 0x8143e6)
        XCTAssertTrue(VRCTrust.verified(.object(["badges": .object(["vrcVerified": .bool(true)])])))
        XCTAssertTrue(VRCTrust.verified(.object(["vrcVerified": .bool(true)])))
        XCTAssertFalse(VRCTrust.verified(.object(["vrcVerified": .bool(true), "badges": .object(["vrcVerified": .bool(false)])])))
        XCTAssertEqual(VRCTrust.key(.object(["vrcTrust": .string("trusted_user")])), "trusted_user")
        XCTAssertEqual(VRCTrust.key(.object(["vrcTrust": .string("user"), "badges": .object(["vrcTrust": .string("known_user")])])), "known_user")
    }
    func testOverlappingHoursJoinAcrossMidnight() {
        XCTAssertEqual(IcebreakerRules.hours([23, 0, 22, 1]), "22–2")
        XCTAssertEqual(IcebreakerRules.hours([12, 10, 11, 10, -1, 24]), "10–13")
        XCTAssertEqual(IcebreakerRules.hours(Array(0..<24)), "0–24")
        XCTAssertEqual(IcebreakerRules.hours([]), "")
    }
    func testQuizRequiresValidAnswersForEveryQuestion() {
        let questions: [JSON] = [.object(["id": .string("q"), "type": .string("single"), "options": .array([.object(["id": .string("a")]), .object(["id": .string("b")])])])]
        XCTAssertTrue(IcebreakerRules.complete(questions, answers: ["q": ["a"]]))
        XCTAssertFalse(IcebreakerRules.complete(questions, answers: [:]))
        XCTAssertFalse(IcebreakerRules.complete(questions, answers: ["q": ["a", "b"]]))
        XCTAssertFalse(IcebreakerRules.complete(questions, answers: ["q": ["unknown"]]))
    }
    func testLikeNotificationsReturnToMainLikesTab() {
        for type in ["like", "like_received", "received_like", "new_like", "superlike"] {
            guard case .likes = NotificationRoute.resolve(.object(["type": .string(type), "data": .object(["userId": .string("peer")])])) else { return XCTFail(type) }
        }
        guard case .chat(let id) = NotificationRoute.resolve(.object(["type": .string("new_message"), "data": .object(["matchId": .string("match")])])) else { return XCTFail("message route") }
        XCTAssertEqual(id, "match")
    }
    func testOAuthRetainsClaimOnTransientFailures() {
        for status in [0, 429, 500, 503] { XCTAssertTrue(OAuthRules.retryable(status)) }
        for status in [400, 401, 403, 410] { XCTAssertFalse(OAuthRules.retryable(status)) }
    }
    func testRapidSwipeKeepsFingerDirection() {
        for _ in 0..<100 {
            XCTAssertEqual(ERPRules.swipe(x: -160, y: 15), "pass")
            XCTAssertEqual(ERPRules.swipe(x: 160, y: 15), "like")
        }
        XCTAssertNil(ERPRules.swipe(x: 30, y: 0))
    }
    func testNotificationNestedCopyAndDate() throws {
        let json = Data(#"{"type":"announcement","title":"旧标题","createdAt":"2026-10-08T07:41:17.311701+01:00","data":{"title":"服务更新","message":"新通知正文"}}"#.utf8)
        let value = NotificationPresentation(try JSONDecoder().decode(JSON.self, from: json))
        XCTAssertEqual(value.title, "服务更新")
        XCTAssertEqual(value.message, "新通知正文")
        XCTAssertEqual(value.symbol, "megaphone")
        XCTAssertNotNil(value.date)
    }
    func testNotificationFallbackNeverHasBlankTitle() {
        let reply = NotificationPresentation(.object(["type": .string("guestbook_reply"), "data": .object(["body": .object(["text": .string("留言回复")])])]))
        XCTAssertEqual(reply.title, "你的留言有新回复")
        XCTAssertEqual(reply.message, "留言回复")
        XCTAssertEqual(NotificationPresentation(.object(["type": .string("future_type")])).title, "网站通知")
        XCTAssertEqual(NotificationPresentation(.object(["body": .string("旧版正文")])).message, "旧版正文")
    }
    func testDiscoveryMediaHidesRestrictedPhotosAndRemovesDuplicateCover() {
        let cover: JSON = .object(["id": .string("cover"), "view": .string("show")])
        let hidden: JSON = .object(["id": .string("hidden"), "view": .string("hide")])
        let user: JSON = .object(["cover": cover, "photos": .array([cover, hidden])])
        XCTAssertEqual(DiscoveryMedia.photos(user), [cover])
        XCTAssertEqual(DiscoveryMedia.photos(.object(["avatar": cover])), [cover])
    }

    func testChatSupportsWrappedAndDirectMatchDetails() {
        let match: JSON = .object(["id": .string("m"), "state": .string("active"), "user": .object(["id": .string("peer"), "displayName": .string("好友")])])
        XCTAssertEqual(ChatPayload.detail(match), match)
        XCTAssertEqual(ChatPayload.detail(.object(["match": match]))["user"]["displayName"].string, "好友")
        XCTAssertEqual(ChatPayload.detail(.object(["match": match]))["state"].string, "active")
    }

    func testChatDateSeparatorsUseLocalDayAcrossUTCMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        XCTAssertTrue(ERPDate.sameDay("2026-10-08T23:59:00.123Z", "2026-10-09T00:01:00Z", calendar: calendar))
        XCTAssertFalse(ERPDate.sameDay("2026-10-08T15:59:00Z", "2026-10-08T16:01:00Z", calendar: calendar))
        XCTAssertFalse(ERPDate.sameDay("invalid", "2026-10-09T00:01:00Z", calendar: calendar))
    }

    func testModeThemesAndIndependentBrightness() {
        let adult = ThemeRules(mode: "nsfw", config: .null)
        XCTAssertTrue(adult.pop)
        XCTAssertTrue(adult.dark(preference: "auto", systemDark: false))
        XCTAssertFalse(adult.dark(preference: "light", systemDark: true))
        XCTAssertFalse(adult.dark(preference: "system", systemDark: false))
        let sfw = ThemeRules(mode: "sfw", config: .null)
        XCTAssertFalse(sfw.pop)
        XCTAssertFalse(sfw.dark(preference: "auto", systemDark: true))
        XCTAssertTrue(sfw.dark(preference: "dark", systemDark: false))
        XCTAssertTrue(sfw.dark(preference: "system", systemDark: true))
    }
    func testSiteAppearanceOverridesDefaultModeStyle() throws {
        let config = try JSONDecoder().decode(JSON.self, from: Data(##"{"appearance":{"mixed":{"preset":"pop","scheme":"dark","accent":"#123ABC"},"nsfw":{"preset":"clean","scheme":"light","accent":"bad"}}}"##.utf8))
        let mixed = ThemeRules(mode: "mixed", config: config)
        XCTAssertTrue(mixed.pop)
        XCTAssertTrue(mixed.modeDark)
        XCTAssertEqual(mixed.accent, 0x123abc)
        let adult = ThemeRules(mode: "nsfw", config: config)
        XCTAssertFalse(adult.pop)
        XCTAssertFalse(adult.modeDark)
        XCTAssertEqual(adult.accent, 0xff3e9a)
    }

    func testDanmakuMatchesWebsiteSpeedAcrossCardsAndProfileCovers() {
        XCTAssertEqual(DanmakuTiming.speed(containerWidth: 180), 40)
        XCTAssertEqual(DanmakuTiming.speed(containerWidth: 390), 65)
        XCTAssertEqual(DanmakuTiming.speed(containerWidth: 960), 80)
        for width in [180.0, 390, 960] {
            for message in [60.0, 180, 300] {
                let duration = DanmakuTiming.duration(containerWidth: width, messageWidth: message)
                XCTAssertEqual((width + message) / duration, DanmakuTiming.speed(containerWidth: width), accuracy: 0.001)
            }
        }
    }

}
