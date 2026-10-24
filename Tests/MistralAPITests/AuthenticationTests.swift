import Foundation
import HTTPTypes
import MistralAPI
import OpenAPIRuntime
import Testing

struct AuthenticationTests {
    @Test(arguments: [
        ("audio_api_v1_transcriptions_post", "ApiKey", "regular-placeholder"),
        ("users_api_admin_users_get_users", "AdminApiKey", "admin-placeholder"),
        ("users_api_get_identity", "DashboardUserContextAuth", "dashboard-placeholder"),
    ])
    func selectsOperationCredential(operationID: String, scheme: String, value: String) async throws {
        let middleware = AuthenticationMiddleware(
            authentication: .credentials([
                "ApiKey": .init("regular-placeholder"),
                "AdminApiKey": .init("admin-placeholder"),
                "DashboardUserContextAuth": .init("dashboard-placeholder"),
            ])
        )
        _ = try await middleware.intercept(
            .init(method: .get, scheme: "https", authority: "offline.invalid", path: "/"),
            body: nil,
            baseURL: URL(string: "https://offline.invalid")!,
            operationID: operationID
        ) { request, _, _ in
            if scheme == "DashboardUserContextAuth" {
                #expect(request.headerFields[HTTPField.Name("x-api-key")!] == value)
                #expect(request.headerFields[.authorization] == nil)
            } else {
                #expect(request.headerFields[.authorization] == "Bearer \(value)")
                #expect(request.headerFields[HTTPField.Name("x-api-key")!] == nil)
            }
            return (.init(status: .ok), nil)
        }
    }

    @Test func missingAdminCredentialFailsBeforeTransport() async {
        let middleware = AuthenticationMiddleware(authentication: .credentials(["ApiKey": .init("placeholder")]))
        do {
            _ = try await middleware.intercept(
                .init(method: .get, scheme: "https", authority: "offline.invalid", path: "/"),
                body: nil,
                baseURL: URL(string: "https://offline.invalid")!,
                operationID: "users_api_admin_users_get_users"
            ) { _, _, _ in
                Issue.record("Transport must not run when authentication is missing")
                return (.init(status: .ok), nil)
            }
            Issue.record("Expected missing administration credential to fail")
        } catch AuthenticationError.unsatisfiedSecurityRequirements(let operationID) {
            #expect(operationID == "users_api_admin_users_get_users")
        } catch {
            Issue.record("Unexpected authentication error: \(error)")
        }
    }
}
