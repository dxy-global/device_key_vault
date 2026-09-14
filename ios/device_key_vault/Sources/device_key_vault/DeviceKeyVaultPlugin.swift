import Flutter
import LocalAuthentication
import Security
import UIKit

/// One secret per app install, behind the phone's biometrics.
///
/// The secret is a Keychain item whose access control is `.biometryCurrentSet`:
/// reading it needs a biometric match, the passcode is refused, and adding or
/// removing a face or finger invalidates it. Beside it sits an UNPROTECTED
/// marker holding the biometric domain state captured at store time. Comparing
/// that state at unlock reports `invalidated` before any prompt, so the answer
/// does not depend on which Keychain status an iOS version returns for an
/// invalidated item.
public class DeviceKeyVaultPlugin: NSObject, FlutterPlugin {
  private let service = "global.dxy.device_key_vault"
  private let secretAccount = "secret"
  private let markerAccount = "marker"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "device_key_vault", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(DeviceKeyVaultPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "availability":
      result(availability())
    case "store":
      guard let secret = args["secret"] as? String, let prompt = args["prompt"] as? String else {
        result(FlutterError(code: "failed", message: "store needs secret and prompt", details: nil))
        return
      }
      store(secret: secret, prompt: prompt, result: result)
    case "unlock":
      guard let prompt = args["prompt"] as? String else {
        result(FlutterError(code: "failed", message: "unlock needs prompt", details: nil))
        return
      }
      unlock(prompt: prompt, result: result)
    case "clear":
      clear()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: availability

  private func availability() -> [String: Any?] {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
      return ["ready": true, "kind": kind(of: context), "reason": nil]
    }
    return ["ready": false, "kind": nil, "reason": unavailableReason(error)]
  }

  private func kind(of context: LAContext) -> String {
    switch context.biometryType {
    case .faceID: return "face"
    case .touchID: return "fingerprint"
    default:
      if #available(iOS 17.0, *), context.biometryType == .opticID { return "iris" }
      return "other"
    }
  }

  private func unavailableReason(_ error: NSError?) -> String {
    guard let error = error, let code = LAError.Code(rawValue: error.code) else { return "no_hardware" }
    switch code {
    case .biometryNotEnrolled, .passcodeNotSet: return "not_enrolled"
    case .biometryLockout: return "locked_out"
    default: return "no_hardware"
    }
  }

  // MARK: store

  private func store(secret: String, prompt: String, result: @escaping FlutterResult) {
    let context = LAContext()
    context.localizedFallbackTitle = ""
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      result(FlutterError(code: failureCode(availability: error), message: error?.localizedDescription, details: nil))
      return
    }
    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: prompt) { ok, evalError in
      guard ok else {
        DispatchQueue.main.async {
          result(FlutterError(code: self.failureCode(evaluation: evalError), message: evalError?.localizedDescription, details: nil))
        }
        return
      }
      var cfError: Unmanaged<CFError>?
      guard let access = SecAccessControlCreateWithFlags(
        nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, &cfError
      ) else {
        DispatchQueue.main.async { result(FlutterError(code: "failed", message: "access control", details: nil)) }
        return
      }
      self.clear()
      let secretStatus = SecItemAdd([
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecAttrAccount as String: self.secretAccount,
        kSecValueData as String: Data(secret.utf8),
        kSecAttrAccessControl as String: access,
        kSecUseAuthenticationContext as String: context,
      ] as CFDictionary, nil)
      let markerStatus = secretStatus == errSecSuccess ? SecItemAdd([
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecAttrAccount as String: self.markerAccount,
        kSecValueData as String: self.domainState(context),
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      ] as CFDictionary, nil) : secretStatus
      DispatchQueue.main.async {
        if secretStatus == errSecSuccess && markerStatus == errSecSuccess {
          result(nil)
        } else {
          self.clear()
          result(FlutterError(code: "failed", message: "keychain \(secretStatus)/\(markerStatus)", details: nil))
        }
      }
    }
  }

  // MARK: unlock

  private func unlock(prompt: String, result: @escaping FlutterResult) {
    let read = readMarker()
    if read.status == errSecItemNotFound {
      result(FlutterError(code: "not_found", message: nil, details: nil))
      return
    }
    guard read.status == errSecSuccess, let marker = read.data else {
      // Not a definite "nothing stored", so the slot is kept.
      result(FlutterError(code: "failed", message: "keychain marker \(read.status)", details: nil))
      return
    }
    let context = LAContext()
    context.localizedFallbackTitle = ""
    context.localizedReason = prompt
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      if let code = error.flatMap({ LAError.Code(rawValue: $0.code) }), code == .biometryNotEnrolled {
        // Every face or finger was removed: the item is already unusable.
        clear()
        result(FlutterError(code: "invalidated", message: nil, details: nil))
        return
      }
      result(FlutterError(code: failureCode(availability: error), message: error?.localizedDescription, details: nil))
      return
    }
    if !marker.isEmpty && marker != domainState(context) {
      clear()
      result(FlutterError(code: "invalidated", message: nil, details: nil))
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      var item: CFTypeRef?
      let status = SecItemCopyMatching([
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.service,
        kSecAttrAccount as String: self.secretAccount,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecUseAuthenticationContext as String: context,
      ] as CFDictionary, &item)
      DispatchQueue.main.async {
        switch status {
        case errSecSuccess:
          if let data = item as? Data, let secret = String(data: data, encoding: .utf8) {
            result(secret)
          } else {
            result(FlutterError(code: "failed", message: "unreadable secret", details: nil))
          }
        case errSecItemNotFound:
          // The marker exists and the secret does not: .biometryCurrentSet removed it.
          self.clear()
          result(FlutterError(code: "invalidated", message: nil, details: nil))
        case errSecUserCanceled:
          result(FlutterError(code: "cancelled", message: nil, details: nil))
        default:
          result(FlutterError(code: "failed", message: "keychain \(status)", details: nil))
        }
      }
    }
  }

  // MARK: helpers

  private func clear() {
    for account in [secretAccount, markerAccount] {
      SecItemDelete([
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ] as CFDictionary)
    }
  }

  /// The status comes back with the data so that only `errSecItemNotFound`
  /// reads as "nothing stored".
  private func readMarker() -> (status: OSStatus, data: Data?) {
    var item: CFTypeRef?
    let status = SecItemCopyMatching([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: markerAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ] as CFDictionary, &item)
    return (status, item as? Data)
  }

  /// Valid only after `canEvaluatePolicy` has run on this context.
  private func domainState(_ context: LAContext) -> Data {
    if #available(iOS 18.0, *) {
      return context.domainState.biometry.stateHash ?? Data()
    }
    return context.evaluatedPolicyDomainState ?? Data()
  }

  private func failureCode(availability error: NSError?) -> String {
    guard let error = error, let code = LAError.Code(rawValue: error.code) else { return "unavailable" }
    return code == .biometryLockout ? "locked_out" : "unavailable"
  }

  private func failureCode(evaluation error: Error?) -> String {
    guard let la = error as? LAError else { return "failed" }
    switch la.code {
    case .userCancel, .appCancel, .systemCancel, .userFallback: return "cancelled"
    case .biometryLockout: return "locked_out"
    case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet: return "unavailable"
    default: return "failed"
    }
  }
}
