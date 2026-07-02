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

        // Wait for the Pokemon list to finish loading from PokeAPI.
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30), "Pokemon list never populated")
        firstCell.tap()

        // The Profile section only renders once the species detail decodes successfully.
        let profileHeader = app.staticTexts["Profile"]
        XCTAssertTrue(profileHeader.waitForExistence(timeout: 30), "Pokemon detail never loaded")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
