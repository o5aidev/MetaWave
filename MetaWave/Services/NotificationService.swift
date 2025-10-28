//
//  NotificationService.swift
//  MetaWave
//
//  v2.4: プッシュ通知サービス
//

import Foundation
import UserNotifications
import CoreData

/// プッシュ通知サービス
@MainActor
final class NotificationService: ObservableObject {
    
    private let context: NSManagedObjectContext
    static let shared = NotificationService()
    
    @Published var isPermissionGranted = false
    @Published var scheduledReminders: [ScheduledReminder] = []
    
    private init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        Task {
            await checkPermission()
            await loadScheduledReminders()
        }
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            
            await MainActor.run {
                isPermissionGranted = granted
            }
            
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        await MainActor.run {
            isPermissionGranted = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Daily Reminder
    
    func scheduleDailyReminder(time: Date) async {
        guard await requestNotificationPermission() else {
            return
        }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        
        // 既存のリマインダーを削除
        await cancelAllReminders()
        
        // 新しいリマインダーをスケジュール
        let content = UNMutableNotificationContent()
        content.title = "メタ認知記録の時間です"
        content.body = "今日の思考や感情を記録して、自己理解を深めましょう"
        content.sound = .default
        content.badge = 1
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            await MainActor.run {
                scheduledReminders.append(ScheduledReminder(
                    id: "daily_reminder",
                    title: "毎日の記録リマインダー",
                    time: time,
                    type: .daily
                ))
            }
        } catch {
            print("Failed to schedule reminder: \(error)")
        }
    }
    
    // MARK: - Pattern Detection Notification
    
    func sendPatternDetectionNotification(pattern: String) async {
        guard await requestNotificationPermission() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "新しいパターンを検出しました"
        content.body = "「\(pattern)」に関する思考パターンが繰り返し出現しています"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "pattern_detection_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send pattern notification: \(error)")
        }
    }
    
    // MARK: - Trend Alert Notification
    
    func sendTrendAlertNotification(trend: String) async {
        guard await requestNotificationPermission() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "感情トレンドの変化"
        content.body = trend
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "trend_alert_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send trend notification: \(error)")
        }
    }
    
    // MARK: - Weekly Summary
    
    func scheduleWeeklySummary() async {
        guard await requestNotificationPermission() else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "週間サマリー"
        content.body = "今週の思考と感情のパターンを確認しましょう"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 2 // 月曜日
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "weekly_summary",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            
            await MainActor.run {
                scheduledReminders.append(ScheduledReminder(
                    id: "weekly_summary",
                    title: "週間サマリー",
                    time: Date(),
                    type: .weekly
                ))
            }
        } catch {
            print("Failed to schedule weekly summary: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    func cancelAllReminders() async {
        await UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        await MainActor.run {
            scheduledReminders.removeAll()
        }
    }
    
    func cancelReminder(id: String) async {
        await UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        
        await MainActor.run {
            scheduledReminders.removeAll { $0.id == id }
        }
    }
    
    private func loadScheduledReminders() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        
        await MainActor.run {
            scheduledReminders = requests.compactMap { request in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let dateComponents = trigger.dateComponents,
                      let time = Calendar.current.date(from: dateComponents) else {
                    return nil
                }
                
                return ScheduledReminder(
                    id: request.identifier,
                    title: request.content.title,
                    time: time,
                    type: determineReminderType(request.identifier)
                )
            }
        }
    }
    
    private func determineReminderType(_ identifier: String) -> ReminderType {
        if identifier.contains("daily") {
            return .daily
        } else if identifier.contains("weekly") {
            return .weekly
        } else {
            return .pattern
        }
    }
}

// MARK: - Data Models

struct ScheduledReminder: Identifiable {
    let id: String
    let title: String
    let time: Date
    let type: ReminderType
}

enum ReminderType {
    case daily
    case weekly
    case pattern
    
    var displayName: String {
        switch self {
        case .daily: return "毎日"
        case .weekly: return "毎週"
        case .pattern: return "パターン"
        }
    }
}

