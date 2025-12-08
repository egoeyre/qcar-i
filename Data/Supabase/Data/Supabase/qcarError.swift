import Foundation

enum qcarError: Error, LocalizedError {
    case notAuthenticated
    case forbidden(String)
    case invalidState(String)
    case notFound(String)
    case decodeFailed
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "未登录"
        case .forbidden(let msg):
            return "无权限：\(msg)"
        case .invalidState(let msg):
            return "状态不合法：\(msg)"
        case .notFound(let msg):
            return "未找到：\(msg)"
        case .decodeFailed:
            return "数据解析失败"
        case .underlying(let e):
            return e.localizedDescription
        }
    }
}
