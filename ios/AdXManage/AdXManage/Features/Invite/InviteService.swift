import Foundation

// MARK: - InviteService

final class InviteService {
    static let shared = InviteService()
    private let client = APIClient.shared
    private init() {}

    func fetchInviteInfo() async throws -> InviteInfo {
        try await client.request(.userInvite)
    }

    func fetchQuota() async throws -> UserQuota {
        try await client.request(.userQuota)
    }
}
