import Foundation
import UserNotifications
import InvestAppCore

/// 배당 알림 스케줄러.
///
/// - `UNUserNotificationCenter` 를 통해 권한을 요청하고
///   배당 지급 전날 오전 9시에 로컬 알림을 예약한다.
public final class NotificationScheduler: @unchecked Sendable {

    // MARK: - Constants

    private let notificationCenter: UNUserNotificationCenter
    private let categoryIdentifier = "com.investapp.dividend"

    // MARK: - Init

    public init(center: UNUserNotificationCenter = .current()) {
        self.notificationCenter = center
    }

    // MARK: - Public Methods

    /// 알림 권한을 요청한다.
    ///
    /// - Returns: 권한 허용 여부.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            return false
        }
    }

    /// 배당 일정 목록을 기반으로 로컬 알림을 예약한다.
    ///
    /// - 기존 배당 알림은 모두 제거 후 재등록한다.
    /// - 지급 전날 오전 9시에 알림을 예약한다.
    /// - 과거 날짜는 건너뛴다.
    /// - Parameter schedules: 배당 일정 목록 (`DividendSchedule`).
    public func scheduleDividendReminders(_ schedules: [DividendSchedule]) async {
        // 기존 배당 알림 제거
        let pending = await notificationCenter.pendingNotificationRequests()
        let dividendIds = pending
            .filter { $0.identifier.hasPrefix(categoryIdentifier) }
            .map(\.identifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: dividendIds)

        let now = Date()
        let calendar = Calendar.current

        for schedule in schedules {
            // 지급 전날 계산
            guard let reminderDay = calendar.date(
                byAdding: .day, value: -1, to: schedule.paymentDate
            ) else { continue }

            // 과거 날짜 스킵
            guard reminderDay > now else { continue }

            // 오전 9시로 설정
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDay)
            components.hour = 9
            components.minute = 0
            components.second = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let content = UNMutableNotificationContent()
            content.title = "배당 지급 예정"
            content.body = "\(schedule.symbol) 배당금이 내일 지급됩니다. (\(CurrencyFormat.formattedKRW(schedule.totalAmount)))"
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            let identifier = "\(categoryIdentifier).\(schedule.id.uuidString)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                // 개별 알림 등록 실패는 무시하고 계속 진행
            }
        }
    }

    /// 모든 배당 알림을 취소한다.
    public func cancelAllDividendReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let dividendIds = pending
            .filter { $0.identifier.hasPrefix(categoryIdentifier) }
            .map(\.identifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: dividendIds)
    }
}
