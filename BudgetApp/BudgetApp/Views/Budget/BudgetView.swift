import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var vm: BudgetViewModel
    @State private var selectedCategory: BudgetCategory?
    @State private var collapsedGroups: Set<String> = []
    @State private var showAddCategory = false
    @State private var errorAlert: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if vm.isLoading && vm.budget == nil {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Theme.green)
                    Text("Loading budget…")
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Sticky header
                        Section(header: headerView) {
                            if let budget = vm.budget {
                                if budget.groups.isEmpty {
                                    emptyState
                                } else {
                                    // Column headers
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
                Button(action: { showAddCategory = true }) {
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.green)
                }
            }
        }
        .sheet(item: $selectedCategory) { cat in
            AssignMoneySheet(
                category: cat,
                readyToAssign: vm.budget?.readyToAssign ?? 0,
                onAssign: { amount in
                    Task { await vm.assign(categoryId: cat.id, amount: amount) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet { groupName, catName, isSavings in
                Task {
                    do {
                        let group = try await APIService.shared.createCategoryGroup(name: groupName)
                        if let gid = (group["id"]?.value as? String) {
                            _ = try await APIService.shared.createCategory(groupId: gid, name: catName, isSavings: isSavings)
                        }
                        await vm.load()
                    } catch {
                        vm.error = error.localizedDescription
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationBackground(Theme.background)
        }
        .task { await vm.load() }
        .alert("Error", isPresented: .init(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
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
                    readyToAssign: budget.readyToAssign,
                    isOverAssigned: budget.isOverAssigned
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
            Text("CATEGORY")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("ASSIGNED")
                .frame(width: 84, alignment: .trailing)
            Text("ACTIVITY")
                .frame(width: 84, alignment: .trailing)
            Text("AVAILABLE")
                .frame(width: 90, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Theme.textTertiary)
        .tracking(0.5)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("No categories yet")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            Button(action: { showAddCategory = true }) {
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

struct AddCategorySheet: View {
    var onAdd: (String, String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var groupName = ""
    @State private var categoryName = ""
    @State private var isSavings = false

    var isValid: Bool { !groupName.isEmpty && !categoryName.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    StyledField(text: $groupName, placeholder: "Group name (e.g. Housing)", icon: "folder")
                    StyledField(text: $categoryName, placeholder: "Category name (e.g. Rent)", icon: "tag")

                    Toggle(isOn: $isSavings) {
                        HStack(spacing: 8) {
                            Image(systemName: "leaf.fill").foregroundStyle(Theme.blue)
                            Text("Savings goal (excluded from spending)")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.surfaceHigh)
                    .cornerRadius(10)
                    .tint(Theme.blue)

                    Spacer()

                    Button(action: { onAdd(groupName, categoryName, isSavings); dismiss() }) {
                        Text("Add Category")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? Theme.green : Theme.textTertiary)
                            .cornerRadius(14)
                    }
                    .disabled(!isValid)
                }
                .padding(16)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
