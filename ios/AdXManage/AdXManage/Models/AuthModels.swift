import Foundation

// MARK: - 注册

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let name: String
}

// MARK: - 登录

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable {
    let token: String
    let expiresAt: Date     // APIClient.decoder 使用 .iso8601 策略直接解码
    let user: UserInfo

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case user
    }
}

struct UserInfo: Decodable {
    let id: UInt64
    let email: String
    let name: String
}

// MARK: - 刷新 Token

struct RefreshResponse: Decodable {
    let token: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
    }
}
