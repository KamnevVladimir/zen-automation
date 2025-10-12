import Foundation

struct ScheduleConfig {
    struct DailySchedule {
        let hour: Int
        let minute: Int
        let templateType: PostCategory
        let topic: String
        
        var timeString: String {
            String(format: "%02d:%02d", hour, minute)
        }
    }
    
    // Массивы тем для ротации (чтобы контент был разнообразным)
    static let morningTopics = [
        "Лайфхаки для экономии в путешествиях",
        "Как найти дешёвые билеты",
        "Секреты бронирования отелей",
        "Ошибки туристов которых можно избежать",
        "Способы сэкономить на трансферах"
    ]
    
    static let eveningTopics = [
        "Бюджетные направления для отдыха",
        "Куда поехать без визы из России",
        "Сравнение популярных направлений",
        "Недорогие страны для зимнего отдыха",
        "Экзотические направления с хорошим бюджетом"
    ]
    
    static var defaultSchedules: [DailySchedule] {
        // Ротация тем каждый день
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        
        return [
            // УТРЕННИЙ ПОСТ (08:00) - лайфхаки и практика
            DailySchedule(
                hour: 8,
                minute: 0,
                templateType: .lifehack,
                topic: morningTopics[dayOfYear % morningTopics.count]
            ),
            // ВЕЧЕРНИЙ ПОСТ (20:00) - направления и бюджет
            DailySchedule(
                hour: 20,
                minute: 0,
                templateType: .budget,
                topic: eveningTopics[dayOfYear % eveningTopics.count]
            )
        ]
    }
    
    static func nextScheduledTime(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let now = date
        
        for schedule in defaultSchedules.sorted(by: { $0.hour * 60 + $0.minute < $1.hour * 60 + $1.minute }) {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = schedule.hour
            components.minute = schedule.minute
            components.second = 0
            
            if let scheduledTime = calendar.date(from: components), scheduledTime > now {
                return scheduledTime
            }
        }
        
        // Если все расписания на сегодня прошли, берём первое на завтра
        if let firstSchedule = defaultSchedules.first {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.day! += 1
            components.hour = firstSchedule.hour
            components.minute = firstSchedule.minute
            components.second = 0
            
            return calendar.date(from: components)
        }
        
        return nil
    }
    
    static func getCurrentSchedule(for date: Date = Date()) -> DailySchedule? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentMinutes = hour * 60 + minute
        
        // Находим ближайшее прошедшее расписание
        return defaultSchedules
            .filter { $0.hour * 60 + $0.minute <= currentMinutes }
            .max { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }
}

