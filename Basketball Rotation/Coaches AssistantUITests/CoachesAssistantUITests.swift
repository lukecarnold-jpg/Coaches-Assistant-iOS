//
//  CoachesAssistantUITests.swift
//  Coaches AssistantUITests
//

import XCTest

final class CoachesAssistantUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        return app
    }

    /// First button whose label starts with `prefix` — row and banner buttons
    /// combine their text for VoiceOver ("Set Starting Lineup, Tap to select…").
    @MainActor
    private func button(startingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @MainActor
    private func addPlayer(_ name: String, jersey: Int, in app: XCUIApplication) {
        app.buttons["Add player"].tap()
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        let jerseyField = app.textFields["Jersey Number (optional)"]
        jerseyField.tap()
        jerseyField.typeText("\(jersey)")
        app.navigationBars.buttons["Add"].tap()
    }

    /// End-to-end Basketball flow: build a roster, start a game, set the lineup,
    /// score for both teams, and end the game.
    @MainActor
    func testBasketballGameFlow() throws {
        let app = launchApp()

        let basketballTile = app.buttons["Basketball"]
        XCTAssertTrue(basketballTile.waitForExistence(timeout: 5))
        basketballTile.tap()

        // Roster: six players so there's a bench.
        let names = ["Avery", "Blake", "Casey", "Drew", "Emery", "Finley"]
        for (index, name) in names.enumerated() {
            addPlayer(name, jersey: index + 1, in: app)
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Finley")).firstMatch.waitForExistence(timeout: 5))

        // New game.
        app.tabBars.buttons["Games"].tap()
        app.buttons["New game"].tap()
        let opponentField = app.textFields["Opponent Name"]
        XCTAssertTrue(opponentField.waitForExistence(timeout: 5))
        opponentField.tap()
        opponentField.typeText("Wildcats")
        app.navigationBars.buttons["Create"].tap()

        XCTAssertTrue(app.staticTexts["vs Wildcats"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["vs Wildcats"].firstMatch.tap()

        // Starting lineup: first five players.
        button(startingWith: "Set Starting Lineup", in: app).tap()
        for name in names.prefix(5) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.tap()
        }
        app.navigationBars.buttons["Set Lineup"].tap()
        XCTAssertTrue(app.staticTexts["On Court"].waitForExistence(timeout: 5))

        // Team hits a 3-pointer, opponent makes a field goal.
        app.buttons["Add score for our team"].tap()
        app.buttons["3-Pointer (3)"].tap()
        app.navigationBars.buttons["Log +3"].tap()
        app.buttons["Add score for Wildcats"].tap()
        app.buttons["Field Goal (2)"].tap()
        app.navigationBars.buttons["Log +2"].tap()

        XCTAssertTrue(app.staticTexts["US score 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Wildcats score 2"].exists)

        // End the game.
        app.swipeUp()
        app.buttons["End Game"].firstMatch.tap()
        // The confirmation is a popover anchored to the button; its own
        // "End Game" action is the second match once it appears.
        let endButtons = app.buttons.matching(NSPredicate(format: "label == %@", "End Game"))
        XCTAssertTrue(endButtons.element(boundBy: 1).waitForExistence(timeout: 5))
        endButtons.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["Final"].waitForExistence(timeout: 5))
    }

    /// Cricket is stats-only: Matches and Stats tabs, no Fixtures clock.
    @MainActor
    func testCricketShowsMatchesAndStatsTabs() throws {
        let app = launchApp()

        let cricketTile = app.buttons["Cricket"]
        XCTAssertTrue(cricketTile.waitForExistence(timeout: 5))
        cricketTile.tap()

        XCTAssertTrue(app.tabBars.buttons["Matches"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists)
        XCTAssertFalse(app.tabBars.buttons["Fixtures"].exists)

        app.tabBars.buttons["Matches"].tap()
        app.buttons["New match"].tap()
        let opponentField = app.textFields["Opponent Name"]
        XCTAssertTrue(opponentField.waitForExistence(timeout: 5))
        opponentField.tap()
        opponentField.typeText("Rovers")
        app.navigationBars.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["vs Rovers"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("-uiTesting")
            app.launch()
        }
    }
}
