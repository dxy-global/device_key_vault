import Flutter
import UIKit
import XCTest


@testable import device_key_vault

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testUnknownMethodIsNotImplemented() {
    let plugin = DeviceKeyVaultPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue((result as AnyObject) === FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testStoreWithoutArgumentsFails() {
    let plugin = DeviceKeyVaultPlugin()

    let call = FlutterMethodCall(methodName: "store", arguments: [:])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual((result as? FlutterError)?.code, "failed")
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
