import XCTest
@testable import App

final class TravelTopicsTests: XCTestCase {
    
    func testRandomLifehackTopicReturnsNonEmptyString() throws {
        let topic = TravelTopics.randomLifehackTopic()
        XCTAssertFalse(topic.isEmpty, "Lifehack topic should not be empty")
        XCTAssertTrue(TravelTopics.lifehackTopics.contains(topic), "Should return a topic from the list")
    }
    
    func testRandomDestinationReturnsNonEmptyString() throws {
        let destination = TravelTopics.randomDestination()
        XCTAssertFalse(destination.isEmpty, "Destination should not be empty")
        XCTAssertTrue(TravelTopics.destinations.contains(destination), "Should return a destination from the list")
    }
    
    func testRandomTravelTypeReturnsNonEmptyString() throws {
        let travelType = TravelTopics.randomTravelType()
        XCTAssertFalse(travelType.isEmpty, "Travel type should not be empty")
        XCTAssertTrue(TravelTopics.travelTypes.contains(travelType), "Should return a travel type from the list")
    }
    
    func testRandomSpecificTopicReturnsNonEmptyString() throws {
        let specificTopic = TravelTopics.randomSpecificTopic()
        XCTAssertFalse(specificTopic.isEmpty, "Specific topic should not be empty")
        XCTAssertTrue(TravelTopics.specificTopics.contains(specificTopic), "Should return a specific topic from the list")
    }
    
    func testRandomSeasonalTopicReturnsNonEmptyString() throws {
        let seasonalTopic = TravelTopics.randomSeasonalTopic()
        XCTAssertFalse(seasonalTopic.isEmpty, "Seasonal topic should not be empty")
        XCTAssertTrue(TravelTopics.seasonalTopics.contains(seasonalTopic), "Should return a seasonal topic from the list")
    }
    
    func testGenerateTopicForLifehackCategory() throws {
        let topic = TravelTopics.generateTopic(for: .lifehack)
        XCTAssertFalse(topic.isEmpty, "Lifehack topic should not be empty")
        XCTAssertTrue(TravelTopics.lifehackTopics.contains(topic), "Should return a lifehack topic")
    }
    
    func testGenerateTopicForComparisonCategory() throws {
        let topic = TravelTopics.generateTopic(for: .comparison)
        XCTAssertFalse(topic.isEmpty, "Comparison topic should not be empty")
        XCTAssertTrue(topic.contains(" vs "), "Comparison topic should contain ' vs '")
    }
    
    func testGenerateTopicForBudgetCategory() throws {
        let topic = TravelTopics.generateTopic(for: .budget)
        XCTAssertFalse(topic.isEmpty, "Budget topic should not be empty")
        XCTAssertTrue(topic.contains("бюджет"), "Budget topic should contain 'бюджет'")
    }
    
    func testGenerateTopicForTrendingCategory() throws {
        let topic = TravelTopics.generateTopic(for: .trending)
        XCTAssertFalse(topic.isEmpty, "Trending topic should not be empty")
    }
    
    func testGenerateTopicForDestinationCategory() throws {
        let topic = TravelTopics.generateTopic(for: .destination)
        XCTAssertFalse(topic.isEmpty, "Destination topic should not be empty")
        XCTAssertTrue(TravelTopics.destinations.contains(topic), "Should return a destination")
    }
    
    func testGenerateDestinationsForComparisonReturnsCorrectCount() throws {
        let destinations = TravelTopics.generateDestinationsForComparison(count: 2)
        XCTAssertEqual(destinations.count, 2, "Should return exactly 2 destinations")
        XCTAssertNotEqual(destinations[0], destinations[1], "Destinations should be different")
    }
    
    func testGenerateDestinationsForOverviewReturnsCorrectCount() throws {
        let destinations = TravelTopics.generateDestinationsForOverview(count: 5)
        XCTAssertEqual(destinations.count, 5, "Should return exactly 5 destinations")
        
        // Проверяем, что все направления уникальны
        let uniqueDestinations = Set(destinations)
        XCTAssertEqual(uniqueDestinations.count, destinations.count, "All destinations should be unique")
    }
    
    func testRandomnessInLifehackTopics() throws {
        // Генерируем 100 тем и проверяем, что есть разнообразие
        var topics = Set<String>()
        for _ in 0..<100 {
            topics.insert(TravelTopics.randomLifehackTopic())
        }
        
        XCTAssertGreaterThan(topics.count, 5, "Should generate diverse topics (got \(topics.count) unique from 100)")
    }
    
    func testRandomnessInDestinations() throws {
        // Генерируем 100 направлений и проверяем, что есть разнообразие
        var destinations = Set<String>()
        for _ in 0..<100 {
            destinations.insert(TravelTopics.randomDestination())
        }
        
        XCTAssertGreaterThan(destinations.count, 10, "Should generate diverse destinations (got \(destinations.count) unique from 100)")
    }
    
    func testLifehackTopicsListNotEmpty() throws {
        XCTAssertFalse(TravelTopics.lifehackTopics.isEmpty, "Lifehack topics list should not be empty")
        XCTAssertGreaterThan(TravelTopics.lifehackTopics.count, 20, "Should have at least 20 lifehack topics")
    }
    
    func testDestinationsListNotEmpty() throws {
        XCTAssertFalse(TravelTopics.destinations.isEmpty, "Destinations list should not be empty")
        XCTAssertGreaterThan(TravelTopics.destinations.count, 30, "Should have at least 30 destinations")
    }
    
    func testTravelTypesListNotEmpty() throws {
        XCTAssertFalse(TravelTopics.travelTypes.isEmpty, "Travel types list should not be empty")
        XCTAssertGreaterThan(TravelTopics.travelTypes.count, 20, "Should have at least 20 travel types")
    }
    
    func testSpecificTopicsListNotEmpty() throws {
        XCTAssertFalse(TravelTopics.specificTopics.isEmpty, "Specific topics list should not be empty")
        XCTAssertGreaterThan(TravelTopics.specificTopics.count, 20, "Should have at least 20 specific topics")
    }
    
    func testSeasonalTopicsListNotEmpty() throws {
        XCTAssertFalse(TravelTopics.seasonalTopics.isEmpty, "Seasonal topics list should not be empty")
        XCTAssertGreaterThan(TravelTopics.seasonalTopics.count, 10, "Should have at least 10 seasonal topics")
    }
    
    func testAllLifehackTopicsAreValid() throws {
        for topic in TravelTopics.lifehackTopics {
            XCTAssertFalse(topic.isEmpty, "Lifehack topic should not be empty")
            XCTAssertTrue(topic.contains("как"), "Lifehack topic should start with 'как'")
        }
    }
    
    func testGenerateTopicReturnsUniqueTopics() throws {
        // Генерируем 50 тем и проверяем разнообразие
        var topics = Set<String>()
        for _ in 0..<50 {
            topics.insert(TravelTopics.generateTopic(for: .lifehack))
        }
        
        XCTAssertGreaterThan(topics.count, 10, "Should generate diverse topics (got \(topics.count) unique from 50)")
    }
}


