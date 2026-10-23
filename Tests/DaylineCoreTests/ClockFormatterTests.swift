import Foundation
import Testing
@testable import DaylineCore

private func utc(_ text: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: text)!
}

private func display(
    _ date: Date,
    in identifier: String,
    _ options: ClockFormatter.Options = ClockFormatter.Options()
) -> String {
    ClockFormatter(timeZone: TimeZone(identifier: identifier)!, options: options).string(from: date)
}

@Suite struct ClockFormatterTests {
    @Test func formatsDateWeekdayAndTimeInSelectedZone() {
        let moment = utc("2026-10-23T01:30:00Z")
        #expect(display(moment, in: "Asia/Shanghai") == "10月23日 周五 09:30")
        // 同一时刻在纽约还是前一天，星期也跟着变。
        #expect(display(moment, in: "America/New_York") == "10月22日 周四 21:30")
    }

    @Test func formatsTwelveHourClock() {
        let moment = utc("2026-10-23T01:30:00Z")
        let twelveHour = ClockFormatter.Options(uses24HourClock: false)
        #expect(display(moment, in: "Asia/Shanghai", twelveHour) == "10月23日 周五 上午9:30")
        #expect(display(moment, in: "America/New_York", twelveHour) == "10月22日 周四 下午9:30")
    }

    @Test func hidesDateAndWeekday() {
        let moment = utc("2026-10-23T01:30:00Z")
        #expect(display(moment, in: "Asia/Shanghai", .init(showsDate: false)) == "周五 09:30")
        #expect(display(moment, in: "Asia/Shanghai", .init(showsWeekday: false)) == "10月23日 09:30")
        #expect(display(moment, in: "Asia/Shanghai", .init(showsDate: false, showsWeekday: false)) == "09:30")
    }

    @Test func formatsInEnglish() {
        let moment = utc("2026-10-23T01:30:00Z")
        #expect(display(moment, in: "Asia/Shanghai", .init(language: .english)) == "Fri Oct 23 09:30")
        #expect(display(moment, in: "America/New_York", .init(uses24HourClock: false, language: .english))
            == "Thu Oct 22 9:30 PM")
        #expect(display(moment, in: "Asia/Shanghai", .init(showsDate: false, language: .english)) == "Fri 09:30")
        #expect(display(moment, in: "Asia/Shanghai", .init(showsWeekday: false, language: .english)) == "Oct 23 09:30")
    }

    @Test func splitsLeadingAndTime() {
        let moment = utc("2026-10-23T01:30:00Z")
        let zone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(ClockFormatter(timeZone: zone, options: .init()).parts(from: moment)
            == .init(leading: "10月23日 周五", time: "09:30"))
        #expect(ClockFormatter(timeZone: zone, options: .init(showsDate: false, showsWeekday: false)).parts(from: moment)
            == .init(leading: nil, time: "09:30"))
    }

    @Test func handlesDaylightSavingStart() {
        // 2026-03-08 02:00 EST 拨到 03:00 EDT。
        #expect(display(utc("2026-03-08T06:59:00Z"), in: "America/New_York") == "3月8日 周日 01:59")
        #expect(display(utc("2026-03-08T07:00:00Z"), in: "America/New_York") == "3月8日 周日 03:00")
    }

    @Test func handlesDaylightSavingEnd() {
        // 2026-11-01 02:00 EDT 拨回 01:00 EST。
        #expect(display(utc("2026-11-01T05:59:00Z"), in: "America/New_York") == "11月1日 周日 01:59")
        #expect(display(utc("2026-11-01T06:00:00Z"), in: "America/New_York") == "11月1日 周日 01:00")
    }

    @Test func ignoresSystemTimeZone() {
        let moment = utc("2026-10-23T01:30:00Z")
        let expected = display(moment, in: "Asia/Tokyo")
        let saved = NSTimeZone.default
        defer { NSTimeZone.default = saved }
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        #expect(display(moment, in: "Asia/Tokyo") == expected)
    }
}

@Suite struct WidgetClockFormatterTests {
    private func parts(_ text: String, in identifier: String, _ language: Language, uses24HourClock: Bool = true)
        -> WidgetClockFormatter.Parts
    {
        WidgetClockFormatter(
            timeZone: TimeZone(identifier: identifier)!,
            language: language,
            uses24HourClock: uses24HourClock
        ).parts(from: utc(text))
    }

    @Test func formatsLikeTheReferenceDesign() {
        #expect(parts("2026-10-22T03:45:00Z", in: "Asia/Shanghai", .english)
            == .init(weekday: "THURSDAY", date: "22 OCT 2026", time: "11:45"))
        #expect(parts("2026-10-22T03:45:00Z", in: "Asia/Shanghai", .english, uses24HourClock: false).time == "11:45 AM")
    }

    @Test func formatsInChinese() {
        #expect(parts("2026-10-22T03:45:00Z", in: "Asia/Shanghai", .chinese)
            == .init(weekday: "星期四", date: "2026年10月22日", time: "11:45"))
    }

    @Test func usesSelectedTimeZone() {
        #expect(parts("2026-10-22T03:45:00Z", in: "America/Los_Angeles", .english)
            == .init(weekday: "WEDNESDAY", date: "21 OCT 2026", time: "20:45"))
    }
}

@Suite struct TimeZoneCatalogTests {
    @Test func describesOffsetsAcrossDaylightSaving() {
        let newYork = TimeZone(identifier: "America/New_York")!
        #expect(TimeZoneCatalog.gmtOffset(of: newYork, at: utc("2026-07-01T00:00:00Z")) == "GMT-4")
        #expect(TimeZoneCatalog.gmtOffset(of: newYork, at: utc("2026-12-01T00:00:00Z")) == "GMT-5")
        #expect(TimeZoneCatalog.gmtOffset(of: TimeZone(identifier: "Asia/Kolkata")!, at: .now) == "GMT+5:30")
        #expect(TimeZoneCatalog.gmtOffset(of: TimeZone(identifier: "UTC")!, at: .now) == "GMT")
    }

    @Test func commonZonesAreValid() {
        for identifier in TimeZoneCatalog.common {
            #expect(TimeZone(identifier: identifier) != nil, "\(identifier)")
        }
    }

    @Test func regionsCoverEveryKnownZone() {
        let grouped = TimeZoneCatalog.regions().flatMap(\.identifiers)
        #expect(Set(grouped) == Set(TimeZone.knownTimeZoneIdentifiers))
    }
}

@Suite struct DisplaySettingsTests {
    private func makeSettings() -> DisplaySettings {
        let suite = "DaylineTests.\(UUID().uuidString)"
        return DisplaySettings(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func defaultsToSystemZoneAnd24HourWithDateAndWeekday() {
        let settings = makeSettings()
        #expect(settings.timeZoneIdentifier == nil)
        #expect(settings.languagePreference == nil)
        #expect(settings.clockOptions == ClockFormatter.Options(language: Language.system))
    }

    @Test func remembersDisplayToggles() {
        let settings = makeSettings()
        settings.showsDate = false
        settings.showsWeekday = false
        settings.languagePreference = .english
        #expect(settings.clockOptions == ClockFormatter.Options(showsDate: false, showsWeekday: false, language: .english))

        settings.languagePreference = nil
        #expect(settings.language == Language.system)
    }

    @Test func widgetDefaultsAndLanguage() {
        let settings = makeSettings()
        #expect(!settings.showsDesktopWidget)
        #expect(settings.widgetSize == .medium)
        #expect(settings.widgetLanguage == .english)
        #expect(!settings.emphasizesTime && !settings.usesWideTracking && !settings.rollsDigits)

        settings.languagePreference = .chinese
        settings.widgetUsesEnglish = false
        settings.widgetSize = .large
        #expect(settings.widgetLanguage == .chinese)
        #expect(settings.widgetSize == .large)
    }

    @Test func remembersChoicesAndRejectsUnknownZones() {
        let settings = makeSettings()
        settings.timeZoneIdentifier = "America/New_York"
        settings.uses24HourClock = false
        #expect(settings.timeZone.identifier == "America/New_York")
        #expect(!settings.uses24HourClock)

        settings.timeZoneIdentifier = "Mars/Olympus_Mons"
        #expect(settings.timeZoneIdentifier == nil)
    }
}
