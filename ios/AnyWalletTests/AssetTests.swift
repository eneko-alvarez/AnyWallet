import XCTest
import UIKit
@testable import AnyWallet

final class AssetTests: XCTestCase {
    func testWalletIconIsAvailableToTheApp() {
        let image = UIImage(named: "WalletIcon")

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.renderingMode, .alwaysOriginal)
    }
}
