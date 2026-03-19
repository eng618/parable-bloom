import XCTest

final class RunnerUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testCaptureScreenshots() throws {
    let app = XCUIApplication()
    setupSnapshot(app)
    app.launch()

    // Initial launch screenshot; add app-specific navigation + snapshot(...) calls as needed.
    snapshot("01Launch")
  }
}
