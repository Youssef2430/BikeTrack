import XCTest

final class BikeTrackUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testHealthWorkoutLifecycleInSimulator() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This test creates a workout only in the isolated simulator Health store.")
        #else
        let app = XCUIApplication()
        authorizeHealthIfShown()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let start = app.buttons["Record without equipment"]
        for _ in 0..<6 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        authorizeHealthIfShown()
        if !app.staticTexts["RECORDING"].waitForExistence(timeout: 10) {
            print("HEALTH AUTH HIERARCHY: \(app.debugDescription)")
            print("SYSTEM AUTH HIERARCHY: \(XCUIApplication(bundleIdentifier: "com.apple.Carousel").debugDescription)")
            capture(app, name: "Health authorization")
            let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screen.name = "System Health authorization"
            screen.lifetime = .keepAlways
            add(screen)
            XCTFail("Health workout did not start after permission request")
            return
        }
        app.swipeRight()
        app.buttons["endWorkout"].tap()
        app.buttons["Save workout"].tap()
        XCTAssertTrue(app.staticTexts["Workout saved"].waitForExistence(timeout: 20))
        capture(app, name: "Health saved workout")
        #endif
    }

    @MainActor
    private func authorizeHealthIfShown() {
        let system = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        let review = system.buttons["UIA.Health.WatchAuthSheet.ReviewButton"]
        let next = system.cells.matching(NSPredicate(
            format: "identifier == %@ OR identifier == %@", "UIA.Health.WatchAuthSheet.ConfigureCell.Button", "UIA.Health.WatchAuthSheet.TimeBoundedDone.Button"
        )).firstMatch
        if review.waitForExistence(timeout: 4) { review.tap() }
        else if !next.exists && !system.navigationBars["Read Access"].exists { return }
        for _ in 0..<6 {
            if next.exists && next.label == "Done" && next.isHittable { next.tap(); return }
            if system.cells["Past 30 Days"].exists {
                system.cells["Past 30 Days"].tap()
            } else {
                if system.alerts.count == 0 { return }
                let all = system.cells["UIA.Health.WatchAuthSheet.SwitchCellALL_REQUESTED_DATA"].switches.firstMatch
                for _ in 0..<10 where !all.isHittable { system.collectionViews.firstMatch.swipeDown() }
                if all.exists && all.value as? String == "0" { all.tap() }
            }
            for _ in 0..<12 where !next.isHittable { system.collectionViews.firstMatch.swipeUp() }
            guard next.exists else { print("HEALTH FINAL PAGE: \(system.debugDescription)"); return }
            let label = next.label
            next.tap()
            if label == "Done" || label == "Allow" { return }
        }
    }

    @MainActor
    func testDemoPauseResumeSaveAndReturnHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["DEMO"].waitForExistence(timeout: 15))
        capture(app, name: "Live metrics")
        app.swipeRight()
        let pause = app.buttons["pauseResume"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        capture(app, name: "Paused controls")
        app.buttons["pauseResume"].tap()
        app.buttons["endWorkout"].tap()
        // watchOS confirmation dialogs expose their labels but drop the SwiftUI
        // accessibilityIdentifier on their native action buttons.
        let end = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "End demo", "endWorkout")).firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        XCTAssertTrue(app.staticTexts["summaryTitle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Nothing was written to Health."].exists)
        capture(app, name: "Workout summary")
        for _ in 0..<9 where !app.buttons["summaryDone"].isHittable { app.swipeUp() }
        app.buttons["summaryDone"].tap()
        XCTAssertTrue(app.staticTexts["Just ride."].waitForExistence(timeout: 5))
        capture(app, name: "Home")
    }

    @MainActor
    func testDemoDiscardDoesNotCreateHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["DEMO"].waitForExistence(timeout: 15))
        app.swipeRight()
        app.buttons["discardWorkout"].tap()
        app.buttons["Discard workout"].tap()
        XCTAssertTrue(app.staticTexts["Just ride."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBothLiveZoneChartsAndSummaryBreakdown() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["DEMO"].waitForExistence(timeout: 15))
        let heartZone = app.staticTexts["heartRateZoneBadge"]
        let hasZone = NSPredicate(format: "label BEGINSWITH %@", "Zone")
        expectation(for: hasZone, evaluatedWith: heartZone)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.staticTexts["powerZoneBadge"].exists)
        Thread.sleep(forTimeInterval: 12)
        capture(app, name: "Both live zones")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["heartRateLiveZone"].waitForExistence(timeout: 5))
        capture(app, name: "Heart rate trend")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["powerLiveZone"].waitForExistence(timeout: 5))
        capture(app, name: "Power trend")
        scrollGently(app)
        scrollGently(app)
        scrollGently(app)
        capture(app, name: "Power zone distribution")
        app.swipeRight()
        app.swipeRight()
        app.swipeRight()
        XCTAssertTrue(app.buttons["endWorkout"].waitForExistence(timeout: 5))
        app.buttons["endWorkout"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "End demo", "endWorkout")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["summaryTitle"].waitForExistence(timeout: 10))
        let heartChart = app.buttons["heartRateSummaryChart"]
        for _ in 0..<5 where !heartChart.isHittable { app.swipeUp() }
        XCTAssertTrue(heartChart.exists)
        capture(app, name: "Summary charts")
        heartChart.tap()
        XCTAssertTrue(app.navigationBars["Heart rate"].waitForExistence(timeout: 5))
        capture(app, name: "Heart rate analysis")
        scrollGently(app)
        scrollGently(app)
        scrollGently(app)
        capture(app, name: "Heart rate zone distribution")
    }

    @MainActor
    func testTrainingThresholdCanBeSavedAndCleared() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Profile editing test is limited to the simulator.")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let zones = app.buttons["trainingZones"]
        for _ in 0..<7 where !zones.isHittable { app.swipeUp() }
        XCTAssertTrue(zones.exists)
        zones.tap()
        capture(app, name: "Training zone settings")
        app.buttons["editMaxHeartRate"].tap()
        let save = app.buttons["saveThreshold"]
        for _ in 0..<4 where !save.isHittable { app.swipeUp() }
        save.tap()
        XCTAssertTrue(app.buttons["editMaxHeartRate"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["editMaxHeartRate"].label.contains("Set up"))
        capture(app, name: "Configured heart rate")
        app.buttons["editMaxHeartRate"].tap()
        let clear = app.buttons["Clear value"]
        for _ in 0..<5 where !clear.isHittable { app.swipeUp() }
        clear.tap()
        XCTAssertTrue(app.buttons["editMaxHeartRate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["editMaxHeartRate"].label.contains("Set up"))
        #endif
    }

    @MainActor
    private func scrollGently(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)),
                   withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
