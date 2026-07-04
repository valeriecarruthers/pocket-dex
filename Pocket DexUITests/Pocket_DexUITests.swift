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

        // The profile should list the Pokemon's region.
        XCTAssertTrue(app.staticTexts["Region"].waitForExistence(timeout: 10), "Region not shown in detail")
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
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Red & Blue")).firstMatch.tap()

        // An active-filter chip for the selected game should appear in the gallery.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Red & Blue")).firstMatch.waitForExistence(timeout: 15),
                      "Active filter chip not shown")

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
    func testGalleryShowsRegionHeaders() throws {
        let app = XCUIApplication()
        app.launch()

        // Sorted by number by default, the first section header is the Kanto region.
        XCTAssertTrue(app.staticTexts["Kanto"].waitForExistence(timeout: 30),
                      "Region header not shown in the gallery")
    }

    @MainActor
    func testRegionFilterShowsNumberRanges() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Filter")).firstMatch.tap()
        app.buttons["Region"].firstMatch.tap()

        // The Kanto option should include its dex range (1–151).
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "151")).firstMatch.waitForExistence(timeout: 10),
                      "Region option is missing its number range")
    }

    @MainActor
    func testDetailGamesGroupedByGeneration() throws {
        let app = XCUIApplication()
        app.launch()

        let bulbasaur = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch
        XCTAssertTrue(bulbasaur.waitForExistence(timeout: 30), "Gallery never appeared")
        bulbasaur.tap()

        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 30), "Detail never loaded")

        // Bulbasaur appears in Gen 1 games, so the games list should be grouped by generation.
        XCTAssertTrue(app.staticTexts["Generation I"].waitForExistence(timeout: 15),
                      "Games are not grouped by generation")
    }

    @MainActor
    func testShinyToggleVisibleWhileSearching() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("char")

        // The shiny toggle must remain reachable while searching.
        XCTAssertTrue(app.buttons["Shiny"].waitForExistence(timeout: 5), "Shiny toggle hidden during search")
    }

    @MainActor
    func testAbilityDescriptionPopover() throws {
        let app = XCUIApplication()
        app.launch()

        let bulbasaur = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch
        XCTAssertTrue(bulbasaur.waitForExistence(timeout: 30), "Gallery never appeared")
        bulbasaur.tap()

        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 30), "Detail never loaded")

        // Tap Bulbasaur's Overgrow ability; a popover should show its Grass-related description.
        let overgrow = app.buttons["Overgrow"]
        XCTAssertTrue(overgrow.waitForExistence(timeout: 10), "Ability chip missing")
        overgrow.tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Grass")).firstMatch.waitForExistence(timeout: 20),
                      "Ability description not shown")
    }

    @MainActor
    func testGalleryHasSectionIndex() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        // The index bar is revealed on scroll; Johto's short label "Joh" only appears there
        // (the section header reads "Johto").
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Joh"].waitForExistence(timeout: 10), "Section index not shown on scroll")
    }

    @MainActor
    func testScrollToTopButton() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        // Scroll down far enough to reveal the scroll-to-top button.
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()

        let topButton = app.buttons["Scroll to top"]
        XCTAssertTrue(topButton.waitForExistence(timeout: 10), "Scroll-to-top button not shown")
        topButton.tap()

        // Back at the top: the first Pokemon should be visible again.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 10),
                      "Did not scroll back to top")
    }

    @MainActor
    func testFormSwitcher() throws {
        let app = XCUIApplication()
        app.launch()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 30), "Search field missing")
        search.tap()
        search.typeText("Deoxys")

        let deoxys = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Deoxys")).firstMatch
        XCTAssertTrue(deoxys.waitForExistence(timeout: 20), "Deoxys not found")
        deoxys.tap()

        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 30), "Detail never loaded")

        // Deoxys has multiple forms; switch to the Attack form.
        let attack = app.buttons["Attack"]
        XCTAssertTrue(attack.waitForExistence(timeout: 15), "Form switcher missing")
        attack.tap()

        // The hero title should now reflect the selected form.
        XCTAssertTrue(app.staticTexts["Deoxys (Attack)"].waitForExistence(timeout: 15), "Form not applied")
    }

    @MainActor
    func testGalleryFormsBadge() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        // Venusaur (#3) has an alternate (Mega) form, so its cell should indicate that.
        let venusaur = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Venusaur", "alternate forms")).firstMatch
        XCTAssertTrue(venusaur.waitForExistence(timeout: 10), "Forms badge not indicated on Venusaur")
    }

    @MainActor
    func testMegaFormFilter() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bulbasaur")).firstMatch.waitForExistence(timeout: 30),
                      "Gallery never appeared")

        // Filter to Mega Evolutions.
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Filter")).firstMatch.tap()
        app.buttons["Form"].firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Mega Evolution")).firstMatch.tap()

        // Ivysaur (#2) has no Mega, so it must be excluded even when searched.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Ivysaur")
        let ivysaur = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Ivysaur")).firstMatch
        XCTAssertTrue(ivysaur.waitForNonExistence(timeout: 15), "Ivysaur should be filtered out for Mega")
    }

    @MainActor
    func testTabBarShowsTopLevelTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // Both top-level tabs should be present in the tab bar at launch.
        XCTAssertTrue(app.buttons["Pokédex"].waitForExistence(timeout: 15), "Pokédex tab missing")
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15), "Settings tab missing")
    }

    @MainActor
    func testSettingsTabOpensAboutSection() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15), "Settings tab missing")
        settingsTab.tap()

        // Selecting the tab should surface the Settings screen and its About/Version row.
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "Settings screen did not appear")
        XCTAssertTrue(app.staticTexts["Version"].waitForExistence(timeout: 10), "About/Version row not shown")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
