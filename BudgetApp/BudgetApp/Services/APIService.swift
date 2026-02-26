import Foundation

// Set your Vercel deployment URL here, or use the env var API_BASE_URL in your Xcode scheme
private let baseURL: String = {
    if let env = ProcessInfo.processInfo.environment["API_BASE_URL"] {
        return env
    }
    // For local development with vercel dev (default port 3000)
    return "http://localhost:3000"
}()

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .networkError(let e):  return "Network error: \(e.localizedDescription)"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .noData:               return "No data received"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    // MARK: - Generic Request

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, msg)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func requestEmpty(_ path: String, method: String) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        let (_, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw APIError.serverError(httpResponse.statusCode, "Request failed")
        }
    }

    // MARK: - Accounts

    func fetchAccounts() async throws -> [Account] {
        try await request("/api/accounts")
    }

    func createAccount(name: String, type: Account.AccountType, startingBalance: Int, isSavingsBucket: Bool) async throws -> Account {
        try await request("/api/accounts", method: "POST", body: [
            "name": name,
            "type": type.rawValue,
            "starting_balance": startingBalance,
            "is_savings_bucket": isSavingsBucket
        ])
    }

    func updateAccount(
        id: String,
        name: String? = nil,
        type: Account.AccountType? = nil,
        startingBalance: Int? = nil,
        isSavingsBucket: Bool? = nil
    ) async throws -> Account {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let type { body["type"] = type.rawValue }
        if let startingBalance { body["starting_balance"] = startingBalance }
        if let isSavingsBucket { body["is_savings_bucket"] = isSavingsBucket }
        return try await request("/api/accounts/\(id)", method: "PUT", body: body)
    }

    func deleteAccount(id: String) async throws {
        try await requestEmpty("/api/accounts/\(id)", method: "DELETE")
    }

    // MARK: - Budget

    func fetchBudget(year: Int, month: Int) async throws -> BudgetMonth {
        try await request("/api/budget/\(year)/\(month)")
    }

    func allocate(year: Int, month: Int, categoryId: String, amount: Int) async throws {
        let _: [String: AnyCodable] = try await request("/api/budget/\(year)/\(month)/allocate", method: "PUT", body: [
            "category_id": categoryId,
            "allocated": amount
        ])
    }

    func bulkAllocate(year: Int, month: Int, assignments: [(categoryId: String, allocated: Int)]) async throws {
        let payload: [[String: Any]] = assignments.map { item in
            ["category_id": item.categoryId, "allocated": item.allocated]
        }
        let _: [String: AnyCodable] = try await request("/api/budget/\(year)/\(month)/allocate", method: "PUT", body: [
            "assignments": payload
        ])
    }

    func resetMonthAllocations(year: Int, month: Int) async throws {
        let _: [String: AnyCodable] = try await request("/api/budget/\(year)/\(month)/allocate", method: "PUT", body: [
            "reset_all": true
        ])
    }

    // MARK: - Categories

    func fetchCategoryGroups() async throws -> [CategoryGroupMeta] {
        try await request("/api/category-groups")
    }

    func fetchCategories() async throws -> [FlatCategory] {
        try await request("/api/categories")
    }

    func createCategoryGroup(name: String, sortOrder: Int = 0) async throws -> CategoryGroupMeta {
        try await request("/api/category-groups", method: "POST", body: [
            "name": name,
            "sort_order": sortOrder
        ])
    }

    func updateCategoryGroup(id: String, name: String? = nil, sortOrder: Int? = nil) async throws -> CategoryGroupMeta {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let sortOrder { body["sort_order"] = sortOrder }
        return try await request("/api/category-groups/\(id)", method: "PUT", body: body)
    }

    func deleteCategoryGroup(id: String) async throws {
        try await requestEmpty("/api/category-groups/\(id)", method: "DELETE")
    }

    func createCategory(groupId: String, name: String, isSavings: Bool = false, dueDay: Int? = nil, recurrence: String? = nil, targetAmount: Int? = nil, notes: String? = nil) async throws -> [String: AnyCodable] {
        var body: [String: Any] = [
            "group_id": groupId,
            "name": name,
            "is_savings": isSavings
        ]
        if let d = dueDay { body["due_day"] = d }
        if let r = recurrence { body["recurrence"] = r }
        if let t = targetAmount { body["target_amount"] = t }
        if let n = notes, !n.isEmpty { body["notes"] = n }
        return try await request("/api/categories", method: "POST", body: body)
    }

    func updateCategory(id: String, name: String, groupId: String, isSavings: Bool, dueDay: Int?, recurrence: String?, targetAmount: Int?, notes: String?) async throws {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        var body: [String: Any] = [
            "name": name,
            "group_id": groupId,
            "is_savings": isSavings,
            "due_day": dueDay ?? NSNull(),
            "recurrence": recurrence ?? NSNull(),
            "target_amount": targetAmount ?? NSNull()
        ]
        body["notes"] = (trimmed?.isEmpty == false) ? trimmed! : NSNull()
        let _: [String: AnyCodable] = try await request("/api/categories/\(id)", method: "PUT", body: body)
    }

    func renameCategory(id: String, name: String) async throws {
        let _: [String: AnyCodable] = try await request("/api/categories/\(id)", method: "PUT", body: ["name": name])
    }

    func deleteCategory(id: String) async throws {
        try await requestEmpty("/api/categories/\(id)", method: "DELETE")
    }

    // MARK: - Transactions

    func fetchTransactions(accountId: String? = nil, categoryId: String? = nil, year: Int? = nil, month: Int? = nil) async throws -> [Transaction] {
        var params: [String] = []
        if let a = accountId { params.append("account_id=\(a)") }
        if let c = categoryId { params.append("category_id=\(c)") }
        if let y = year { params.append("year=\(y)") }
        if let m = month { params.append("month=\(m)") }
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request("/api/transactions\(query)")
    }

    func createTransaction(accountId: String, categoryId: String?, payeeName: String?, amount: Int, date: String, memo: String?, cleared: Bool = false) async throws -> Transaction {
        var body: [String: Any] = [
            "account_id": accountId,
            "amount": amount,
            "date": date,
            "cleared": cleared
        ]
        if let c = categoryId { body["category_id"] = c }
        if let p = payeeName, !p.isEmpty { body["payee_name"] = p }
        if let m = memo, !m.isEmpty { body["memo"] = m }
        return try await request("/api/transactions", method: "POST", body: body)
    }

    func updateTransaction(id: String, categoryId: String? = nil, payeeName: String? = nil, amount: Int? = nil, date: String? = nil, memo: String? = nil, cleared: Bool? = nil) async throws -> Transaction {
        var body: [String: Any] = [:]
        if let c = categoryId { body["category_id"] = c }
        if let p = payeeName { body["payee_name"] = p }
        if let a = amount { body["amount"] = a }
        if let d = date { body["date"] = d }
        if let m = memo { body["memo"] = m }
        if let cl = cleared { body["cleared"] = cl }
        return try await request("/api/transactions/\(id)", method: "PUT", body: body)
    }

    func deleteTransaction(id: String) async throws {
        try await requestEmpty("/api/transactions/\(id)", method: "DELETE")
    }

    // MARK: - Payees

    func fetchPayees() async throws -> [Payee] {
        try await request("/api/payees")
    }
}

// Helper for flexible JSON decoding
struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if let d = try? container.decode(Double.self) { value = d }
        else { value = NSNull() }
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let s as String: try container.encode(s)
        case let i as Int: try container.encode(i)
        case let b as Bool: try container.encode(b)
        case let d as Double: try container.encode(d)
        default: try container.encodeNil()
        }
    }
}
