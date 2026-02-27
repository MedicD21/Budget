import SwiftUI

private func parseDollarsToCents(_ text: String) -> Int? {
    let normalized = text.replacingOccurrences(of: ",", with: "")
    guard !normalized.isEmpty else { return nil }
    guard let dollars = Double(normalized) else { return nil }
    return Int((dollars * 100.0).rounded())
}

struct BudgetView: View {
    @EnvironmentObject var vm: BudgetViewModel

    @State private var selectedCategory: BudgetCategory?
    @State private var editingCategory: BudgetCategory?
    @State private var collapsedGroups: Set<String> = []

    @State private var showBudgetMenu = false
    @State private var showBudgetTools = false
    @State private var showGroupManager = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if vm.isLoading && vm.budget == nil {
                VStack(spacing: 12) {
                    ProgressView().tint(Theme.green)
                    Text("Loading budget…").foregroundStyle(Theme.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section(header: headerView) {
                            if let budget = vm.budget {
                                if budget.groups.isEmpty {
                                    emptyState
                                } else {
                                    columnHeaders
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Theme.background)

                                    Text(
                                        "Tap a category to assign money. Swipe rows for edit/delete."
                                    )
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)

                                    ForEach(budget.groups) { group in
                                        CategoryGroupSection(
                                            group: group,
                                            collapsed: Binding(
                                                get: { collapsedGroups.contains(group.id) },
                                                set: { isCollapsed in
                                                    if isCollapsed {
                                                        collapsedGroups.insert(group.id)
                                                    } else {
                                                        collapsedGroups.remove(group.id)
                                                    }
                                                }
                                            ),
                                            onTapCategory: { selectedCategory = $0 },
                                            onEditCategory: { editingCategory = $0 },
                                            onDeleteCategory: { category in
                                                Task { await vm.deleteCategory(id: category.id) }
                                            }
                                        )
                                    }
                                    Spacer().frame(height: 100)
                                }
                            }
                        }
                    }
                }
                .refreshable { await vm.load() }
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Menu {
                        Button {
                            showBudgetTools = true
                        } label: {
                            Label("Budget Tools", systemImage: "slider.horizontal.3")
                        }

                        Button {
                            showGroupManager = true
                        } label: {
                            Label("Manage Groups", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Button(action: { showBudgetMenu = true }) {
                        Image(systemName: "plus").foregroundStyle(Theme.green)
                    }
                }
            }
        }
        .sheet(item: $selectedCategory) { category in
            AssignMoneySheet(
                category: category,
                readyToAssign: vm.budget?.readyToAssign ?? 0,
                onAssign: { amount in
                    Task { await vm.assign(categoryId: category.id, amount: amount) }
                },
                onEdit: {
                    selectedCategory = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        editingCategory = category
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorSheet(
                category: category,
                groups: vm.budget?.groups ?? [],
                onSave: { name, groupId, isSavings, dueDay, recurrence, targetAmount, knownPaymentAmount, notes in
                    Task {
                        await vm.updateCategory(
                            id: category.id,
                            name: name,
                            groupId: groupId,
                            isSavings: isSavings,
                            dueDay: dueDay,
                            recurrence: recurrence,
                            targetAmount: targetAmount,
                            knownPaymentAmount: knownPaymentAmount,
                            notes: notes
                        )
                    }
                },
                onDelete: {
                    Task { await vm.deleteCategory(id: category.id) }
                }
            )
            .presentationDetents([.large])
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showBudgetMenu) {
            BudgetMenuSheet(
                budget: vm.budget,
                onSelectCategory: { category in
                    showBudgetMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedCategory = category
                    }
                },
                onCreateNew: {
                    groupId, newGroupName, categoryName, isSavings, dueDay, recurrence,
                    targetAmount, knownPaymentAmount, notes in
                    Task {
                        await vm.createCategory(
                            groupId: groupId,
                            newGroupName: newGroupName,
                            categoryName: categoryName,
                            isSavings: isSavings,
                            dueDay: dueDay,
                            recurrence: recurrence,
                            targetAmount: targetAmount,
                            knownPaymentAmount: knownPaymentAmount,
                            notes: notes
                        )
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showBudgetTools) {
            BudgetToolsSheet(
                monthName: vm.budget?.monthName ?? "",
                onCoverOverspent: {
                    Task { await vm.coverOverspent() }
                },
                onFundTargets: {
                    Task { await vm.fundTargets() }
                },
                onCopyPreviousMonth: {
                    Task { await vm.copyPreviousMonthPlan() }
                },
                onResetMonth: {
                    Task { await vm.resetCurrentMonthPlan() }
                }
            )
            .presentationDetents([.medium])
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showGroupManager) {
            ManageGroupsSheet(
                groups: vm.budget?.groups ?? [],
                onCreateGroup: { name in
                    Task { await vm.createGroup(name: name) }
                },
                onRenameGroup: { group, name in
                    Task { await vm.renameGroup(id: group.id, name: name) }
                },
                onDeleteGroup: { group in
                    Task { await vm.deleteGroup(id: group.id) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .task { await vm.load() }
        .alert(
            "Error",
            isPresented: .init(
                get: { vm.error != nil },
                set: { if !$0 { vm.error = nil } }
            )
        ) {
            Button("OK") { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            MonthNavigator(
                monthName: vm.budget?.monthName ?? "",
                onPrevious: vm.goToPreviousMonth,
                onNext: vm.goToNextMonth
            )
            if let budget = vm.budget {
                ReadyToAssignCard(
                    readyToAssign: budget.readyToAssign, isOverAssigned: budget.isOverAssigned
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("CATEGORY").frame(maxWidth: .infinity, alignment: .leading)
            Text("ASSIGNED").frame(width: 84, alignment: .trailing)
            Text("ACTIVITY").frame(width: 84, alignment: .trailing)
            Text("AVAILABLE").frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Theme.textTertiary)
        .tracking(0.5)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray").font(.system(size: 48)).foregroundStyle(Theme.textTertiary)
            Text("No categories yet").font(.title3).foregroundStyle(Theme.textSecondary)
            Button(action: { showBudgetMenu = true }) {
                Label("Add a category", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.green)
                    .cornerRadius(12)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Category Editor

struct CategoryEditorSheet: View {
    var category: BudgetCategory
    var groups: [CategoryGroup]
    var onSave: (String, String, Bool, Int?, String?, Int?, Int?, String?) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedGroupId = ""
    @State private var isSavings = false
    @State private var hasDueDate = false
    @State private var dueDayText = ""
    @State private var recurrence = "monthly"
    @State private var hasTargetAmount = false
    @State private var targetAmountText = ""
    @State private var knownPaymentAmountText = ""
    @State private var notes = ""

    private var dueDayInt: Int? {
        Int(dueDayText)
    }

    private var dueDayIsValid: Bool {
        guard hasDueDate else { return true }
        guard let dueDayInt else { return false }
        return (1...31).contains(dueDayInt)
    }

    private var targetAmountCents: Int? {
        parseDollarsToCents(targetAmountText)
    }

    private var targetIsValid: Bool {
        guard hasTargetAmount else { return true }
        guard let targetAmountCents else { return false }
        return targetAmountCents >= 0
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedGroupId.isEmpty
            && dueDayIsValid && targetIsValid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        StyledField(text: $name, placeholder: "Category name", icon: "tag")

                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "folder")
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 20)
                                Text("Group").foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Picker("Group", selection: $selectedGroupId) {
                                    ForEach(groups) { group in
                                        Text(group.name).tag(group.id)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Theme.surfaceHigh)
                            .cornerRadius(10)
                        }

                        Toggle(isOn: $isSavings) {
                            HStack(spacing: 8) {
                                Image(systemName: "leaf.fill").foregroundStyle(Theme.blue)
                                Text("Savings goal").foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceHigh)
                        .cornerRadius(10)
                        .tint(Theme.blue)

                        Toggle(isOn: $hasDueDate.animation()) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar").foregroundStyle(Theme.green)
                                Text("Has a due date").foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceHigh)
                        .cornerRadius(10)
                        .tint(Theme.green)

                        if hasDueDate {
                            VStack(spacing: 10) {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock").foregroundStyle(Theme.green)
                                    Text("Due day of month").foregroundStyle(Theme.textSecondary).font(.system(size: 14))
                                    Spacer()
                                    TextField("1-31", text: $dueDayText)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(width: 60)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Theme.surfaceHigh)
                                .cornerRadius(10)

                                if !dueDayIsValid {
                                    Text("Due day must be between 1 and 31")
                                        .font(.caption)
                                        .foregroundStyle(Theme.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                HStack(spacing: 8) {
                                    ForEach(["monthly", "yearly", "once", "bi-monthly", "weekly", "bi-weekly"], id: \.self) { option in
                                        Button(action: { recurrence = option }) {
                                            Text(option.capitalized)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(recurrence == option ? .black : Theme.textSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(recurrence == option ? Theme.green : Theme.surfaceHigh)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                HStack(spacing: 12) {
                                    Image(systemName: "creditcard").foregroundStyle(Theme.blue)
                                    Text("Known payment amount").foregroundStyle(Theme.textSecondary).font(.system(size: 14))
                                    Spacer()
                                    TextField("e.g. 120.00", text: $knownPaymentAmountText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(width: 90)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Theme.surfaceHigh)
                                .cornerRadius(10)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        Toggle(isOn: $hasTargetAmount.animation()) {
                            HStack(spacing: 8) {
                                Image(systemName: "target").foregroundStyle(Theme.yellow)
                                Text("Has a target amount").foregroundStyle(Theme.textPrimary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.surfaceHigh)
                        .cornerRadius(10)
                        .tint(Theme.yellow)

                        if hasTargetAmount {
                            HStack(spacing: 12) {
                                Image(systemName: "dollarsign.circle").foregroundStyle(Theme.yellow)
                                Text("Target amount").foregroundStyle(Theme.textSecondary).font(.system(size: 14))
                                Spacer()
                                TextField("e.g. 500", text: $targetAmountText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 90)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.surfaceHigh)
                            .cornerRadius(10)
                        }

                        StyledField(text: $notes, placeholder: "Notes (optional)", icon: "note.text")

                        Button(action: {
                            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                            onSave(
                                cleanName,
                                selectedGroupId,
                                isSavings,
                                hasDueDate ? dueDayInt : nil,
                                hasDueDate ? recurrence : nil,
                                hasTargetAmount ? targetAmountCents : nil,
                                hasDueDate && !knownPaymentAmountText.isEmpty ? parseDollarsToCents(knownPaymentAmountText) : nil,
                                cleanNotes.isEmpty ? nil : cleanNotes
                            )
                            dismiss()
                        }) {
                            Text("Save Category")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSave ? Theme.green : Theme.textTertiary)
                                .cornerRadius(14)
                        }
                        .disabled(!canSave)

                        Button(role: .destructive, action: {
                            onDelete()
                            dismiss()
                        }) {
                            Text("Delete Category")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.red.opacity(0.16))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear {
            name = category.name
            selectedGroupId = category.groupId
            isSavings = category.isSavings
            hasDueDate = category.dueDay != nil
            dueDayText = category.dueDay.map(String.init) ?? ""
            recurrence = category.recurrence ?? "monthly"
            hasTargetAmount = category.targetAmount != nil
            if let targetAmount = category.targetAmount {
                targetAmountText = String(format: "%.2f", Double(targetAmount) / 100.0)
            } else {
                targetAmountText = ""
            }
            notes = category.notes ?? ""

            if selectedGroupId.isEmpty {
                selectedGroupId = groups.sorted(by: { $0.sortOrder < $1.sortOrder }).first?.id ?? ""
            }
        }
    }

}

// MARK: - Manage Groups

struct ManageGroupsSheet: View {
    var groups: [CategoryGroup]
    var onCreateGroup: (String) -> Void
    var onRenameGroup: (CategoryGroup, String) -> Void
    var onDeleteGroup: (CategoryGroup) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var newGroupName = ""
    @State private var renamingGroup: CategoryGroup?
    @State private var groupToDelete: CategoryGroup?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        StyledField(
                            text: $newGroupName, placeholder: "New group name",
                            icon: "folder.badge.plus")

                        Button("Add") {
                            let trimmed = newGroupName.trimmingCharacters(
                                in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onCreateGroup(trimmed)
                            newGroupName = ""
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Theme.green)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)

                    if groups.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.textTertiary)
                            Text("No groups yet")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 1) {
                                ForEach(groups.sorted(by: { $0.sortOrder < $1.sortOrder })) {
                                    group in
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(group.name)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(Theme.textPrimary)
                                            Text("\(group.categories.count) categories")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer()

                                        Menu {
                                            Button {
                                                renamingGroup = group
                                            } label: {
                                                Label("Rename", systemImage: "pencil")
                                            }

                                            Button(role: .destructive) {
                                                groupToDelete = group
                                            } label: {
                                                Label("Delete Group", systemImage: "trash")
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Theme.surface)

                                    Divider()
                                        .background(Theme.surfaceHigh)
                                        .padding(.leading, 16)
                                }
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Manage Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .sheet(item: $renamingGroup) { group in
            RenameGroupSheet(groupName: group.name) { newName in
                onRenameGroup(group, newName)
            }
            .presentationDetents([.height(220)])
            .presentationBackground(Theme.background)
        }
        .alert(
            "Delete group?",
            isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { groupToDelete = nil }
            Button("Delete", role: .destructive) {
                if let groupToDelete {
                    onDeleteGroup(groupToDelete)
                }
                groupToDelete = nil
            }
        } message: {
            Text("Deleting a group also deletes all categories inside it.")
        }
    }
}

struct RenameGroupSheet: View {
    var groupName: String
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    StyledField(text: $name, placeholder: "Group name", icon: "folder")
                        .padding(.horizontal, 16)

                    Spacer()

                    Button(action: {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Theme.textTertiary : Theme.green
                            )
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Rename Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { name = groupName }
    }
}

// MARK: - Budget Tools

struct BudgetToolsSheet: View {
    var monthName: String
    var onCoverOverspent: () -> Void
    var onFundTargets: () -> Void
    var onCopyPreviousMonth: () -> Void
    var onResetMonth: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 10) {
                    Text(monthName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    toolButton(
                        title: "Cover Overspent Categories",
                        subtitle: "Set allocation so available is no longer negative",
                        icon: "shield.lefthalf.filled",
                        tint: Theme.red
                    ) {
                        onCoverOverspent()
                        dismiss()
                    }

                    toolButton(
                        title: "Fund Targets",
                        subtitle: "Set each target category to its target amount",
                        icon: "target",
                        tint: Theme.yellow
                    ) {
                        onFundTargets()
                        dismiss()
                    }

                    toolButton(
                        title: "Copy Previous Month Plan",
                        subtitle: "Apply last month allocations to this month",
                        icon: "doc.on.doc",
                        tint: Theme.blue
                    ) {
                        onCopyPreviousMonth()
                        dismiss()
                    }

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.counterclockwise")
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset This Month Allocations")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Delete all assigned amounts for this month")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Theme.red.opacity(0.12))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("Budget Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .alert("Reset this month?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                onResetMonth()
                dismiss()
            }
        } message: {
            Text("This clears all category allocations for the current month.")
        }
    }

    private func toolButton(
        title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .cornerRadius(10)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Budget Menu (+ button sheet)

struct BudgetMenuSheet: View {
    var budget: BudgetMonth?
    var onSelectCategory: (BudgetCategory) -> Void
    var onCreateNew: (String?, String?, String, Bool, Int?, String?, Int?, Int?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showNewCategoryForm = false

    @State private var useNewGroup = false
    @State private var selectedGroupId = ""
    @State private var newGroupName = ""
    @State private var newCatName = ""
    @State private var newIsSavings = false
    @State private var newDueDay = ""
    @State private var newRecurrence = "monthly"
    @State private var newKnownPaymentAmount = ""
    @State private var newTargetAmount = ""
    @State private var newNotes = ""
    @State private var showDueDateOptions = false
    @State private var showTargetOptions = false

    private var availableGroups: [CategoryGroup] {
        (budget?.groups ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private var canCreateCategory: Bool {
        let categoryNameValid = !newCatName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let groupValid =
            useNewGroup
            ? !newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : !selectedGroupId.isEmpty
        let dueDayValid =
            !showDueDateOptions
            || {
                guard let dueDay = Int(newDueDay) else { return false }
                return (1...31).contains(dueDay)
            }()
        let targetValid = !showTargetOptions || parseDollarsToCents(newTargetAmount) != nil
        return categoryNameValid && groupValid && dueDayValid && targetValid
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if showNewCategoryForm {
                    newCategoryForm
                } else {
                    categoryList
                }
            }
            .navigationTitle(showNewCategoryForm ? "New Category" : "Assign Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showNewCategoryForm ? "Back" : "Cancel") {
                        if showNewCategoryForm {
                            showNewCategoryForm = false
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear {
            if selectedGroupId.isEmpty {
                selectedGroupId = availableGroups.first?.id ?? ""
            }
        }
    }

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Move Create New Category button to the top
                Button(action: { showNewCategoryForm = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.green)
                        Text("Create New Category")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.green)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Theme.surface)
                }
                .padding(.top, 0)

                if let budget, !budget.groups.isEmpty {
                    ForEach(budget.groups) { group in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.name.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                                .tracking(0.8)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 4)

                            ForEach(group.categories) { category in
                                Button(action: { onSelectCategory(category) }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                if category.isSavings {
                                                    Image(systemName: "leaf.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(Theme.blue)
                                                }
                                                Text(category.name)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(Theme.textPrimary)
                                            }
                                            Text("Assigned \(formatCurrency(category.allocated))")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }

                                        Spacer()

                                        Text(formatCurrency(abs(category.available)))
                                            .font(
                                                .system(
                                                    size: 13, weight: .semibold, design: .rounded)
                                            )
                                            .foregroundStyle(
                                                category.available >= 0 ? Theme.green : Theme.red
                                            )
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                (category.available >= 0 ? Theme.green : Theme.red)
                                                    .opacity(0.12)
                                            )
                                            .cornerRadius(8)

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.textTertiary)
                                            .padding(.leading, 4)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Theme.surface)
                                }
                                Divider().background(Theme.surfaceHigh).padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var newCategoryForm: some View {
        ScrollView {
            VStack(spacing: 14) {
                Toggle(isOn: $useNewGroup.animation()) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus").foregroundStyle(Theme.blue)
                        Text("Create new group").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surfaceHigh)
                .cornerRadius(10)
                .tint(Theme.blue)

                if useNewGroup {
                    StyledField(
                        text: $newGroupName, placeholder: "Group name (e.g. Housing)",
                        icon: "folder")
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 20)
                        Text("Group").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if availableGroups.isEmpty {
                            Text("No groups")
                                .foregroundStyle(Theme.textTertiary)
                        } else {
                            Picker("Group", selection: $selectedGroupId) {
                                ForEach(availableGroups) { group in
                                    Text(group.name).tag(group.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.textPrimary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.surfaceHigh)
                    .cornerRadius(10)
                }

                StyledField(
                    text: $newCatName, placeholder: "Category name (e.g. Rent)", icon: "tag")

                Toggle(isOn: $newIsSavings) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill").foregroundStyle(Theme.blue)
                        Text("Savings goal").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surfaceHigh)
                .cornerRadius(10)
                .tint(Theme.blue)

                Toggle(isOn: $showDueDateOptions.animation()) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar").foregroundStyle(Theme.green)
                        Text("Has a due date").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surfaceHigh)
                .cornerRadius(10)
                .tint(Theme.green)

                if showDueDateOptions {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock").foregroundStyle(Theme.green)
                            Text("Due day of month").foregroundStyle(Theme.textSecondary).font(
                                .system(size: 14))
                            Spacer()
                            TextField("1-31", text: $newDueDay)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 60)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.surfaceHigh)
                        .cornerRadius(10)

                        // Recurrence options with new types
                        HStack(spacing: 8) {
                            ForEach(
                                ["monthly", "yearly", "once", "bi-monthly", "weekly", "bi-weekly"],
                                id: \.self
                            ) { option in
                                Button(action: { newRecurrence = option }) {
                                    Text(option.capitalized)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(
                                            newRecurrence == option ? .black : Theme.textSecondary
                                        )
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            newRecurrence == option
                                                ? Theme.green : Theme.surfaceHigh
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Known payment amount field
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard").foregroundStyle(Theme.blue)
                            Text("Known payment amount").foregroundStyle(Theme.textSecondary).font(
                                .system(size: 14))
                            Spacer()
                            TextField("e.g. 120.00", text: $newKnownPaymentAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 90)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.surfaceHigh)
                        .cornerRadius(10)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Toggle(isOn: $showTargetOptions.animation()) {
                    HStack(spacing: 8) {
                        Image(systemName: "target").foregroundStyle(Theme.yellow)
                        Text("Has a target amount").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surfaceHigh)
                .cornerRadius(10)
                .tint(Theme.yellow)

                if showTargetOptions {
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle").foregroundStyle(Theme.yellow)
                        Text("Target amount").foregroundStyle(Theme.textSecondary).font(
                            .system(size: 14))
                        Spacer()
                        TextField("e.g. 500", text: $newTargetAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 90)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.surfaceHigh)
                    .cornerRadius(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                StyledField(text: $newNotes, placeholder: "Notes (optional)", icon: "note.text")

                Button(action: {
                    let dueDay = showDueDateOptions ? Int(newDueDay) : nil
                    let targetAmount =
                        showTargetOptions ? parseDollarsToCents(newTargetAmount) : nil
                    let recurrence = showDueDateOptions ? newRecurrence : nil
                    let notes = newNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                    let categoryName = newCatName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let newGroupName =
                        useNewGroup
                        ? self.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                    let knownPaymentAmount =
                        showDueDateOptions && !newKnownPaymentAmount.isEmpty
                        ? parseDollarsToCents(newKnownPaymentAmount) : nil
                    onCreateNew(
                        useNewGroup ? nil : selectedGroupId,
                        newGroupName,
                        categoryName,
                        newIsSavings,
                        dueDay,
                        recurrence,
                        targetAmount,
                        knownPaymentAmount,
                        notes.isEmpty ? nil : notes
                    )
                    dismiss()
                }) {
                    Text("Add Category")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canCreateCategory ? Theme.green : Theme.textTertiary)
                        .cornerRadius(14)
                }
                .disabled(!canCreateCategory)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

}
