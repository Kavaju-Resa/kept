import XCTest
@testable import Kept

final class PatternServiceTests: XCTestCase {
    func testDetectsRegularMonthlyLikeHistory() {
        let calendar = Calendar(identifier: .gregorian)
        let dates = [0, 30, 60].map { calendar.date(byAdding: .day, value: $0, to: Date(timeIntervalSince1970: 1_700_000_000))! }
        let memories = dates.map {
            MemoryItem(text: "Haircut", title: "Haircut", category: "health", recurringKey: "haircut", eventDate: $0)
        }
        let result = PatternService().detect(in: memories, now: dates.last!)
        XCTAssertEqual(result.first?.recurringKey, "haircut")
        XCTAssertEqual(result.first?.intervalDays, 30)
    }
}
