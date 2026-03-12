import Foundation

// MARK: - 标准响应包装（匹配后端 response.OK）

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

// MARK: - 分页响应包装（匹配后端 response.OKPage）

struct APIPageResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: [T]?
    let pagination: APIPagination
}

struct APIPagination: Decodable {
    let page: Int
    let pageSize: Int
    let total: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case total
        case hasMore  = "has_more"
    }
}
