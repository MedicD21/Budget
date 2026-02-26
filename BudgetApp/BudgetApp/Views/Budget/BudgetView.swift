import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var vm: BudgetViewModel
    @State private var selectedCategory: BudgetCategory?
    @State private var editingCategory: BudgetCategory?
    @State private var collapsedGroups: Set<String> = []
    @State private var showBudgetMenu = false

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

                                    ForEach(budget.groups) { group in
                                        CategoryGroupSection(
                                            group: group,
                                            collapsed: Binding(
                                                get: { collapsedGroups.contains(group.id) },
                                                set: { isCollapsed in
                                                    if isCollapsed { collapsedGroups.insert(group.id) }
                                                    else { collapsedGroups.remove(group.id) }
                                                }
                                            ),
                                            onTapCategory: { selectedCategory = $0 },
                                            onEditCategory: { editingCategory = $0 },
                                            onDeleteCategory: { cat in
                                                Task { await vm.deleteCategory(id: cat.id) }
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
                Button(action: { showBudgetMenu = true }) {
                    Image(systemName: "plus").foregroundStyle(Theme.green)
                }
            }
        }
        // Assign money to a category
        .sheet(item: $selectedCategory) { cat in
            AssignMoneySheet(
                category: cat,
                readyToAssign: vm.budget?.readyToAssign ?? 0,
                onAssign: { amount in Task { await vm.assign(categoryId: cat.id, amount: amount) } }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        // Rename a category
        .sheet(item: $editingCategory) { cat in
            RenameCategorySheet(category: cat) { newName in
                Task { await vm.renameCategory(id: cat.id, name: newName) }
            }
            .presentationDetents([.height(220)])
            .presentationBackground(Theme.background)
        }
        // + menu: existing categories + create new
        .sheet(isPresented: $showBudgetMenu) {
            BudgetMenuSheet(
                budget: vm.budget,
                onSelectCategory: { cat in
                    showBudgetMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedCategory = cat
                    }
                },
                onCreateNew: { groupName, catName, isSavings, dueDay, recurrence, targetAmount, notes in
                    Task {
                        do {
                            let group = try await APIService.shared.createCategoryGroup(name: groupName)
                            if let gid = (group["id"]?.value as? String) {
                                _ = try await APIService.shared.createCategory(
                                    groupId: gid, name: catName, isSavings: isSavings,
                                    dueDay: dueDay, recurrence: recurrence,
                                    targetAmount: targetAmount, notes: notes
                                )
                            }
                            await vm.load()
                        } catch {
                            vm.error = error.localizedDescription
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .task { await vm.load() }
        .alert("Error", isPresented: .init(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK") { vm.error = nil }
        } message: { Text(vm.error ?? "") }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            MonthNavigator(
                monthName: vm.budget?.monthName ?? "",
                onPrevious: vm.goToPreviousMonth,
                onNext: vm.goToNextMonth
            )
            if let budget = vm.budget {
                ReadyToAssignCard(readyToAssign: budget.readyToAssign, isOverAssigned: budget.isOverAssigned)
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
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.green).cornerRadius(12)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Rename Sheet

struct RenameCategorySheet: View {
    var category: BudgetCategory
    var onRename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    StyledField(text: $name, placeholder: "Category name", icon: "tag")
                        .padding(.horizontal, 16)
                    Spacer()
                    Button(action: { onRename(name); dismiss() }) {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.isEmpty ? Theme.textTertiary : Theme.green)
                            .cornerRadius(14)
                    }
                    .disabled(name.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Rename Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .onAppear { name = category.name }
    }
}

// MARK: - Budget Menu (+ button sheet)

struct BudgetMenuSheet: View {
    var budget: BudgetMonth?
    var onSelectCategory: (BudgetCategory) -> Void
    var onCreateNew: (String, String, Bool, Int?, String?, Int?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showNewCategoryForm = false

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
                        if showNewCategoryForm { showNewCategoryForm = false }
                        else { dismiss() }
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Existing categories grouped
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

                            ForEach(group.categories) { cat in
                                Button(action: { onSelectCategory(cat) }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                if cat.isSavings {
                                                    Image(systemName: "leaf.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(Theme.blue)
                                                }
                                                Text(cat.name)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(Theme.textPrimary)
                                            }
                                            Text("Assigned \(formatCurrency(cat.allocated))")
                                                .font(.caption)
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer()
                                        // Available chip
                                        Text(formatCurrency(abs(cat.available)))
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(cat.available >= 0 ? Theme.green : Theme.red)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background((cat.available >= 0 ? Theme.green : Theme.red).opacity(0.12))
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

                // New category button
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
                .padding(.top, 16)
            }
            .padding(.bottom, 32)
        }
    }

    @State private var newGroupName = ""
    @State private var newCatName = ""
    @State private var newIsSavings = false
    @State private var newDueDay: String = ""
    @State private var newRecurrence: String = "monthly"
    @State private var newTargetAmount: String = ""
    @State private var newNotes: String = ""
    @State private var showDueDateOptions = false
    @State private var showTargetOptions = false

    private var newCategoryForm: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Basic info
                StyledField(text: $newGroupName, placeholder: "Group name (e.g. Housing)", icon: "folder")
                StyledField(text: $newCatName, placeholder: "Category name (e.g. Rent)", icon: "tag")

                // Savings toggle
                Toggle(isOn: $newIsSavings) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill").foregroundStyle(Theme.blue)
                        Text("Savings goal").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.surfaceHigh).cornerRadius(10).tint(Theme.blue)

                // Due date toggle
                Toggle(isOn: $showDueDateOptions.animation()) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar").foregroundStyle(Theme.green)
                        Text("Has a due date").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.surfaceHigh).cornerRadius(10).tint(Theme.green)

                if showDueDateOptions {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock").foregroundStyle(Theme.green)
                            Text("Due day of month").foregroundStyle(Theme.textSecondary).font(.system(size: 14))
                            Spacer()
                            TextField("e.g. 15", text: $newDueDay)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 60)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.surfaceHigh).cornerRadius(10)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("REPEATS").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textTertiary).tracking(0.8)
                            HStack(spacing: 8) {
                                ForEach(["monthly", "yearly", "once"], id: \.self) { opt in
                                    Button(action: { newRecurrence = opt }) {
                                        Text(opt.capitalized)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(newRecurrence == opt ? .black : Theme.textSecondary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(newRecurrence == opt ? Theme.green : Theme.surfaceHigh)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Target amount toggle
                Toggle(isOn: $showTargetOptions.animation()) {
                    HStack(spacing: 8) {
                        Image(systemName: "target").foregroundStyle(Theme.yellow)
                        Text("Has a savings target").foregroundStyle(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.surfaceHigh).cornerRadius(10).tint(Theme.yellow)

                if showTargetOptions {
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle").foregroundStyle(Theme.yellow)
                        Text("Target amount").foregroundStyle(Theme.textSecondary).font(.system(size: 14))
                        Spacer()
                        TextField("e.g. 500", text: $newTargetAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surfaceHigh).cornerRadius(10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Notes
                StyledField(text: $newNotes, placeholder: "Notes (optional)", icon: "note.text")

                Button(action: {
                    let dueDayInt = Int(newDueDay)
                    let targetAmountCents = Double(newTargetAmount).map { Int($0 * 100) }
                    let rec = showDueDateOptions ? newRecurrence : nil
                    let notes = newNotes.isEmpty ? nil : newNotes
                    onCreateNew(newGroupName, newCatName, newIsSavings, showDueDateOptions ? dueDayInt : nil, rec, showTargetOptions ? targetAmountCents : nil, notes)
                    dismiss()
                }) {
                    Text("Add Category")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background((!newGroupName.isEmpty && !newCatName.isEmpty) ? Theme.green : Theme.textTertiary)
                        .cornerRadius(14)
                }
                .disabled(newGroupName.isEmpty || newCatName.isEmpty)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
}
