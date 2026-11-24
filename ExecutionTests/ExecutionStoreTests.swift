import XCTest
@testable import Execution

final class ExecutionStoreTests: XCTestCase {
    @MainActor func testCommitmentLifecycleAndPersistence() throws {
        let suite = "execution.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ExecutionStore(defaults: defaults)
        store.add(title: " Ship the build ", priority: .critical,
                  deadline: Date().addingTimeInterval(3600), reminders: false)
        let item = try XCTUnwrap(store.active.first)
        XCTAssertEqual(item.title, "Ship the build")
        XCTAssertNil(item.startedAt)
        store.start(item.id)
        XCTAssertNotNil(store.active.first?.startedAt)
        store.complete(item.id)
        XCTAssertTrue(store.active.isEmpty)
        XCTAssertEqual(store.completedToday, 1)
        XCTAssertEqual(ExecutionStore(defaults: defaults).completed.first?.id, item.id)
        store.remove(item.id)
        XCTAssertTrue(ExecutionStore(defaults: defaults).completed.isEmpty)
    }

    @MainActor func testRejectBlankAndExpiredCommitments() throws {
        let suite = "execution.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ExecutionStore(defaults: defaults)
        store.add(title: "  ", priority: .standard, deadline: Date().addingTimeInterval(60), reminders: false)
        store.add(title: "Expired", priority: .standard, deadline: Date().addingTimeInterval(-60), reminders: false)
        XCTAssertTrue(store.active.isEmpty)
    }
}
