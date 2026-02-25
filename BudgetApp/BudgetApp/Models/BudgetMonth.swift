import Foundation

struct BudgetMonth: Codable {
    var year: Int
    var month: Int
    var readyToAssign: Int    // cents
    var totalBudgeted: Int    // cents
    var groups: [CategoryGroup]

    enum CodingKeys: String, CodingKey {
        case year, month, groups
        case readyToAssign = "ready_to_assign"
        case totalBudgeted = "total_budgeted"
    }

    var isOverAssigned: Bool { readyToAssign < 0 }

    var formattedReadyToAssign: String {
        formatCurrency(abs(readyToAssign))
    }

    var monthName: String {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// Global currency formatter — used across models
func formatCurrency(_ cents: Int) -> String {
    let dollars = Double(cents) / 100.0
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: dollars)) ?? "$0.00"
}
