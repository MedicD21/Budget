import Foundation

struct CategoryGroup: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var sortOrder: Int
    var categories: [BudgetCategory]
    var totalAllocated: Int    // cents
    var totalActivity: Int     // cents
    var totalAvailable: Int    // cents

    enum CodingKeys: String, CodingKey {
        case id, name, categories
        case sortOrder = "sort_order"
        case totalAllocated = "total_allocated"
        case totalActivity = "total_activity"
        case totalAvailable = "total_available"
    }
}

struct BudgetCategory: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var isSavings: Bool
    var sortOrder: Int
    var allocated: Int    // cents — budgeted this month
    var activity: Int     // cents — spent this month (negative)
    var available: Int    // cents — allocated + activity
    var dueDay: Int?
    var recurrence: String?
    var targetAmount: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, allocated, activity, available, notes, recurrence
        case isSavings = "is_savings"
        case sortOrder = "sort_order"
        case dueDay = "due_day"
        case targetAmount = "target_amount"
    }

    var availableColor: AvailableColor {
        if available > 0 { return .green }
        if available == 0 { return .neutral }
        return .red
    }

    enum AvailableColor { case green, neutral, red }
}

// Flat category (used for pickers/selects — from /api/categories)
struct FlatCategory: Identifiable, Codable, Hashable {
    let id: String
    var groupId: String
    var groupName: String
    var name: String
    var isSavings: Bool
    var sortOrder: Int
    var dueDay: Int?
    var recurrence: String?
    var targetAmount: Int?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, notes, recurrence
        case groupId = "group_id"
        case groupName = "group_name"
        case isSavings = "is_savings"
        case sortOrder = "sort_order"
        case dueDay = "due_day"
        case targetAmount = "target_amount"
    }
}
