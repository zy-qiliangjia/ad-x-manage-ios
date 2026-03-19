import Foundation

// MARK: - AppConfig（服务端下发的客户端配置）

struct AppConfig: Decodable {
    let wechatURL: String
    let telegramURL: String

    enum CodingKeys: String, CodingKey {
        case wechatURL   = "wechat_url"
        case telegramURL = "telegram_url"
    }
}
