//
//  Pocket_DexUITests.swift
//  Pocket DexUITests
//
//  Created by Valerie Carruthers on 2026-07-01.
//

import XCTest

final class Pocket_DexUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testPokemonDetailLoads() throws {
        let app = XCUIApplication()
        app.launch()

        // Open a Pokemon from the list. On compact width the app launches on the list;
        // on regular width the row is in the always-visible sidebar. Rows expose a combined
        // label (e.g. "#0001, Bulbasaur, Kanto"), so match on the name.
        let bulbasaur = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch
        XCTAssertTrue(bulbasaur.waitForExistence(timeout: 30), "Pokemon list never populated")
        bulbasaur.tap()

        // The Profile section only renders once the species detail decodes successfully.
        let profileHeader = app.staticTexts["Profile"]
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 30), "Pokemon detail never loaded")
    }

    @MainActor
    func testGalleryNavigatesToTappedPokemon() throws {
        let app = XCUIApplication()
        app.launch()

        // Tap a specific mid-list Pokemon in the gallery.
        let charizard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Charizard")).firstMatch
        XCTAssertTrue(charizard.waitForExistence(timeout: 30), "Gallery cells never appeared")
        charizard.tap()

        // The detail must be for the tapped Pokemon specifically (regression: it used to always
        // open the last Pokemon). The detail sets its navigation title to the Pokemon's name.
        XCTAssertTrue(app.navigationBars["Charizard"].waitForExistence(timeout: 30),
                      "Did not navigate to the tapped Pokemon")
    }

    @MainActor
    func testGameFilterExcludesOtherGenerations() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        // Open the filter menu and choose a Kanto-only game (Red/Blue).
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Filter")).firstMatch.tap()
        app.buttons["Game"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Red Blue")).firstMatch.tap()

        // Chikorita (Gen 2) is not in Red/Blue, so once the filter applies it must disappear.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Chikorita")
        let chikorita = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Chikorita")).firstMatch
        XCTAssertTrue(chikorita.waitForNonExistence(timeout: 25), "Chikorita should be filtered out for Red/Blue")
    }

    @MainActor
    func testSearchEvolutionLineExpansion() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Charizard")

        // Charmander does not match the text "Charizard".
        let charmander = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Charmander")).firstMatch
        XCTAssertFalse(charmander.waitForExistence(timeout: 2), "Charmander should not match the text search alone")

        // Turn on evolution-line inclusion.
        let toggle = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "evolution lines")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Evolution-line toggle missing")
        toggle.tap()

        // Charmander (Charizard's base form) should now be included.
        XCTAssertTrue(charmander.waitForExistence(timeout: 25), "Charmander should appear once evolution lines are included")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
