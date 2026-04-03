import Foundation
import Testing
import UserNotifications
@testable import traders_guild

@MainActor
struct PushNotificationManagerTests {
    @Test
    func requestPermissionAndRegisterPromptsWhenStatusIsUndetermined() async {
        let authProvider = PushNotificationAuthProviderFake(
            currentStatus: .notDetermined,
            requestResult: true,
            statusAfterRequest: .authorized
        )
        let registrar = RemoteNotificationRegistrarFake()
        let api = DeviceTokenAPIFake()
        let manager = PushNotificationManager(
            authorizationProvider: authProvider,
            remoteRegistrar: registrar
        )
        manager.configure(apiService: api)

        await manager.requestPermissionAndRegister(reason: .login)

        #expect(authProvider.requestAuthorizationCalls == 1)
        #expect(registrar.registerCalls == 1)
        #expect(manager.permissionStatus == .authorized)
        #expect(manager.diagnostics.lastAPNsRegistrationReason == PushRegistrationReason.login.rawValue)
        #expect(manager.diagnostics.lastAPNsRegistrationAttemptAt != nil)
    }

    @Test
    func didReceiveDeviceTokenRegistersWithBackendAndUpdatesDiagnostics() async {
        let authProvider = PushNotificationAuthProviderFake(currentStatus: .authorized)
        let registrar = RemoteNotificationRegistrarFake()
        let api = DeviceTokenAPIFake()
        let manager = PushNotificationManager(
            authorizationProvider: authProvider,
            remoteRegistrar: registrar
        )
        manager.configure(apiService: api)

        await manager.didReceiveDeviceToken("deadbeef")

        #expect(api.registerCalls.count == 1)
        #expect(api.registerCalls.first?.deviceToken == "deadbeef")
        #expect(api.registerCalls.first?.platform == "ios")
        #expect(manager.isRegistered)
        #expect(manager.diagnostics.lastAPNsToken == "deadbeef")
        #expect(manager.diagnostics.lastBackendRegisteredToken == "deadbeef")
        #expect(manager.diagnostics.lastBackendRegistrationState == .success)
        #expect(manager.diagnostics.lastBackendRegistrationReason == PushRegistrationReason.apnsCallback.rawValue)
        #expect(manager.diagnostics.isBackendRegisteredThisSession)
        #expect(manager.diagnostics.lastErrorMessage == nil)
    }

    @Test
    func manualRegistrationReregistersCachedTokenWithBackend() async {
        let authProvider = PushNotificationAuthProviderFake(currentStatus: .authorized)
        let registrar = RemoteNotificationRegistrarFake()
        let api = DeviceTokenAPIFake()
        let manager = PushNotificationManager(
            authorizationProvider: authProvider,
            remoteRegistrar: registrar
        )
        manager.configure(apiService: api)

        await manager.didReceiveDeviceToken("feedface")
        await manager.registerForRemoteNotifications(reason: .manual)

        #expect(registrar.registerCalls == 1)
        #expect(api.registerCalls.count == 2)
        #expect(api.registerCalls.last?.deviceToken == "feedface")
        #expect(manager.diagnostics.lastBackendRegistrationReason == PushRegistrationReason.manual.rawValue)
        #expect(manager.diagnostics.lastBackendRegistrationState == .success)
    }

    @Test
    func backendRegistrationFailureIsSurfacedInDiagnostics() async {
        let authProvider = PushNotificationAuthProviderFake(currentStatus: .authorized)
        let registrar = RemoteNotificationRegistrarFake()
        let api = DeviceTokenAPIFake()
        api.shouldFailRegister = true
        let manager = PushNotificationManager(
            authorizationProvider: authProvider,
            remoteRegistrar: registrar
        )
        manager.configure(apiService: api)

        await manager.didReceiveDeviceToken("broken-token")

        #expect(!manager.isRegistered)
        #expect(manager.diagnostics.lastBackendRegistrationState == .failure)
        #expect(!manager.diagnostics.isBackendRegisteredThisSession)
        #expect(manager.diagnostics.lastErrorMessage?.contains("Failed to register device token") == true)
        #expect(manager.diagnostics.lastErrorAt != nil)
    }
}

private final class PushNotificationAuthProviderFake: PushNotificationAuthorizationProviding {
    var currentStatus: UNAuthorizationStatus
    var requestResult: Bool
    var statusAfterRequest: UNAuthorizationStatus
    var requestAuthorizationCalls = 0

    init(
        currentStatus: UNAuthorizationStatus,
        requestResult: Bool = true,
        statusAfterRequest: UNAuthorizationStatus? = nil
    ) {
        self.currentStatus = currentStatus
        self.requestResult = requestResult
        self.statusAfterRequest = statusAfterRequest ?? currentStatus
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCalls += 1
        currentStatus = statusAfterRequest
        return requestResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        currentStatus
    }
}

private final class RemoteNotificationRegistrarFake: RemoteNotificationRegistering {
    var registerCalls = 0

    func registerForRemoteNotifications() {
        registerCalls += 1
    }
}

private enum DeviceTokenAPIFailure: Error {
    case simulated
}

private final class DeviceTokenAPIFake: DeviceTokenAPIClient {
    struct RegisterCall: Equatable {
        let deviceToken: String
        let platform: String
    }

    var registerCalls: [RegisterCall] = []
    var deregisterCalls: [String] = []
    var shouldFailRegister = false

    func registerDeviceToken(deviceToken: String, platform: String) async throws {
        registerCalls.append(RegisterCall(deviceToken: deviceToken, platform: platform))
        if shouldFailRegister {
            throw DeviceTokenAPIFailure.simulated
        }
    }

    func deregisterDeviceToken(deviceToken: String) async throws {
        deregisterCalls.append(deviceToken)
    }
}
