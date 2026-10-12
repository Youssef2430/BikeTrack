import XCTest

final class ScreenHeaderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testSupportingScreensAndBackNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        checkHeader("BikeTrack", in: app)
        capture("Home")
        app.buttons["connectEquipment"].tap()
        checkHeader("Equipment", in: app)
        capture("Equipment")
        back(to: "BikeTrack", in: app)
        reveal(app.buttons["activityPicker"], in: app)
        app.buttons["activityPicker"].tap()
        checkHeader("Workout", in: app)
        capture("Workout selection")
        back(to: "BikeTrack", in: app)
        reveal(app.buttons["settings"], in: app)
        app.buttons["settings"].tap()
        checkHeader("Settings", in: app)
        capture("Settings")
        app.buttons["settingsTrainingZones"].tap()
        checkHeader("Training zones", in: app)
        capture("Training zones")
        app.buttons["editMaxHeartRate"].tap()
        checkHeader("Heart rate", in: app)
        capture("Heart rate threshold")
        back(to: "Training zones", in: app)
        app.buttons["editFTP"].tap()
        checkHeader("Power", in: app)
        capture("Power threshold")
        back(to: "Training zones", in: app)
        back(to: "Settings", in: app)
        let diagnostics = app.buttons["View diagnostics"]
        reveal(diagnostics, in: app)
        diagnostics.tap()
        checkHeader("Diagnostics", in: app)
        capture("Diagnostics")
        back(to: "Settings", in: app)
        reveal(app.buttons["privacyPolicy"], in: app)
        app.buttons["privacyPolicy"].tap()
        checkHeader("Privacy policy", in: app)
        capture("Privacy")
        back(to: "Settings", in: app)
        back(to: "BikeTrack", in: app)
        let history = app.buttons["Workout history"]
        reveal(history, in: app)
        history.tap()
        checkHeader("History", in: app)
        capture("History")
        back(to: "BikeTrack", in: app)
    }

    @MainActor
    func testWorkoutScreensAndAnalysisBackNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--uitesting"]
        app.launch()
        checkHeader("Indoor ride", in: app)
        capture("Overview")
        app.swipeRight()
        checkHeader("Controls", in: app)
        capture("Controls")
        app.swipeLeft()
        checkHeader("Indoor ride", in: app)
        app.swipeLeft()
        checkHeader("Heart rate", in: app)
        capture("Heart rate live")
        app.swipeLeft()
        checkHeader("Power", in: app)
        capture("Power live")
        app.swipeLeft()
        checkHeader("Details", in: app)
        capture("Details")
        for _ in 0..<4 { app.swipeRight() }
        checkHeader("Controls", in: app)
        app.buttons["endWorkout"].tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "End demo", "endWorkout")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        checkHeader("Summary", in: app)
        capture("Summary")
        let heart = app.buttons["heartRateSummaryChart"]
        reveal(heart, in: app)
        heart.tap()
        checkHeader("Heart rate", in: app)
        capture("Heart rate analysis")
        back(to: "Summary", in: app)
        let power = app.buttons["powerSummaryChart"]
        reveal(power, in: app)
        power.tap()
        checkHeader("Power", in: app)
        capture("Power analysis")
        back(to: "Summary", in: app)
        reveal(app.buttons["summaryDone"], in: app)
        app.buttons["summaryDone"].tap()
        checkHeader("BikeTrack", in: app)
    }

    @MainActor
    private func checkHeader(_ title: String, in app: XCUIApplication) {
        let header = app.descendants(matching: .any)["screenHeader"].firstMatch
        XCTAssertTrue(header.exists || header.waitForExistence(timeout: 10))
        if header.label != title {
            let titleAppeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: header)
            let result = XCTWaiter.wait(for: [titleAppeared], timeout: 5)
            XCTAssertEqual(result, .completed, "Expected \(title), found \(header.label)")
        }
        XCTAssertLessThanOrEqual(header.frame.maxY, app.frame.height * 0.25)
    }

    @MainActor
    private func back(to title: String, in app: XCUIApplication) {
        app.buttons["screenHeader"].firstMatch.tap()
        checkHeader(title, in: app)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<20 where !element.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)),
                       withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
