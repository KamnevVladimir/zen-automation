import XCTest
@testable import App

final class ScheduleConfigTests: XCTestCase {
    
    func testDefaultSchedulesCount() throws {
        XCTAssertEqual(ScheduleConfig.defaultSchedules.count, 4)
    }
    
    func testScheduleTimings() throws {
        let schedules = ScheduleConfig.defaultSchedules
        
        XCTAssertEqual(schedules[0].hour, 8)
        XCTAssertEqual(schedules[0].minute, 0)
        
        XCTAssertEqual(schedules[1].hour, 12)
        XCTAssertEqual(schedules[1].minute, 0)
        
        XCTAssertEqual(schedules[2].hour, 16)
        XCTAssertEqual(schedules[2].minute, 0)
        
        XCTAssertEqual(schedules[3].hour, 20)
        XCTAssertEqual(schedules[3].minute, 0)
    }
    
    func testScheduleTypes() throws {
        let schedules = ScheduleConfig.defaultSchedules
        
        XCTAssertEqual(schedules[0].templateType, .weekend)
        XCTAssertEqual(schedules[1].templateType, .budget)
        XCTAssertEqual(schedules[2].templateType, .lifehack)
        XCTAssertEqual(schedules[3].templateType, .trending)
    }
    
    func testTimeStringFormat() throws {
        let schedule = ScheduleConfig.defaultSchedules[0]
        XCTAssertEqual(schedule.timeString, "08:00")
        
        let schedule2 = ScheduleConfig.defaultSchedules[3]
        XCTAssertEqual(schedule2.timeString, "20:00")
    }
    
    func testNextScheduledTimeBeforeFirstSchedule() throws {
        // Тест в 07:00 - должен вернуть 08:00 сегодня
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        components.second = 0
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Не удалось создать тестовую дату")
            return
        }
        
        let next = ScheduleConfig.nextScheduledTime(from: testDate)
        XCTAssertNotNil(next)
        
        let nextComponents = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(nextComponents.hour, 8)
        XCTAssertEqual(nextComponents.minute, 0)
    }
    
    func testNextScheduledTimeBetweenSchedules() throws {
        // Тест в 10:00 - должен вернуть 12:00 сегодня
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 10
        components.minute = 0
        components.second = 0
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Не удалось создать тестовую дату")
            return
        }
        
        let next = ScheduleConfig.nextScheduledTime(from: testDate)
        XCTAssertNotNil(next)
        
        let nextComponents = calendar.dateComponents([.hour, .minute], from: next!)
        XCTAssertEqual(nextComponents.hour, 12)
        XCTAssertEqual(nextComponents.minute, 0)
    }
    
    func testNextScheduledTimeAfterLastSchedule() throws {
        // Тест в 22:00 - должен вернуть 08:00 завтра
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 22
        components.minute = 0
        components.second = 0
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Не удалось создать тестовую дату")
            return
        }
        
        let next = ScheduleConfig.nextScheduledTime(from: testDate)
        XCTAssertNotNil(next)
        
        let nextComponents = calendar.dateComponents([.year, .month, .day, .hour], from: next!)
        let testComponents = calendar.dateComponents([.year, .month, .day], from: testDate)
        
        // Проверяем что день следующий
        XCTAssertEqual(nextComponents.day, testComponents.day! + 1)
        XCTAssertEqual(nextComponents.hour, 8)
    }
    
    func testGetCurrentScheduleMorning() throws {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 30
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Не удалось создать тестовую дату")
            return
        }
        
        let current = ScheduleConfig.getCurrentSchedule(for: testDate)
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.hour, 8)
        XCTAssertEqual(current?.templateType, .weekend)
    }
    
    func testGetCurrentScheduleBeforeFirst() throws {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Не удалось создать тестовую дату")
            return
        }
        
        let current = ScheduleConfig.getCurrentSchedule(for: testDate)
        XCTAssertNil(current, "До первого расписания не должно быть текущего")
    }
}

