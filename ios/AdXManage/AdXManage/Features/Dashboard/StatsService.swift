import Foundation

// MARK: - StatsService

final class StatsService {

    static let shared = StatsService()
    private init() {}

    private let client = APIClient.shared

    func overview(platform: String? = nil) async throws -> StatsOverview {
        var params: [String: String] = [:]
        if let p = platform, !p.isEmpty { params["platform"] = p }
        return try await client.request(
            .stats,
            queryParams: params.isEmpty ? nil : params
        )
    }
}
