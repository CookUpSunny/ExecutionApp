import SwiftUI
import UIKit
import UserNotifications

private let executionRed = Color(red: 0.84, green: 0.035, blue: 0.125)

enum Priority: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard", high = "High", critical = "Critical"
    var id: String { rawValue }
}

struct Commitment: Identifiable, Codable {
    var id = UUID()
    var title: String
    var priority: Priority
    var createdAt = Date()
    var deadline: Date
    var startedAt: Date?
    var completedAt: Date?
    var reminders: Bool
    var isComplete: Bool { completedAt != nil }
    var isOverdue: Bool { !isComplete && deadline < Date() }
}

@MainActor final class ExecutionStore: ObservableObject {
    @Published private(set) var commitments: [Commitment] = []
    @Published var notificationStatus: String = ""
    private let key = "execution.commitments.v1"
    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key) {
            do { commitments = try JSONDecoder().decode([Commitment].self, from: data) }
            catch { notificationStatus = "Saved commitments could not be read." }
        }
    }

    var active: [Commitment] {
        commitments.filter { !$0.isComplete }.sorted { $0.deadline < $1.deadline }
    }
    var completed: [Commitment] {
        commitments.filter { $0.isComplete }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    var completedToday: Int {
        completed.filter { Calendar.current.isDateInToday($0.completedAt ?? .distantPast) }.count
    }
    var averageStartMinutes: Int? {
        let started = commitments.compactMap { item in
            item.startedAt.map { max(0, $0.timeIntervalSince(item.createdAt)) }
        }
        guard !started.isEmpty else { return nil }
        return Int(started.reduce(0, +) / Double(started.count) / 60)
    }

    private func save() {
        do { defaults.set(try JSONEncoder().encode(commitments), forKey: key) }
        catch { notificationStatus = "Could not save commitments." }
    }

    func add(title: String, priority: Priority, deadline: Date, reminders: Bool) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, deadline > Date() else { return }
        let item = Commitment(title: cleaned, priority: priority, deadline: deadline, reminders: reminders)
        commitments.append(item)
        save()
        if reminders { Task { await schedule(item) } }
    }
    func start(_ id: UUID) {
        guard let i = commitments.firstIndex(where: { $0.id == id && !$0.isComplete }),
              commitments[i].startedAt == nil else { return }
        commitments[i].startedAt = Date()
        save()
    }
    func complete(_ id: UUID) {
        guard let i = commitments.firstIndex(where: { $0.id == id && !$0.isComplete }) else { return }
        let now = Date()
        if commitments[i].startedAt == nil { commitments[i].startedAt = now }
        commitments[i].completedAt = now
        cancel(id)
        save()
    }
    func remove(_ id: UUID) {
        commitments.removeAll { $0.id == id }
        cancel(id)
        save()
    }

    private func cancel(_ id: UUID) {
        let ids = [1, 2, 3, 4, 6, 8, 12, 24, 72, 0].map { "\(id.uuidString)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func schedule(_ item: Commitment) async {
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                notificationStatus = "Notifications are off. Enable them in Settings to receive reminders."
                return
            }
            // iOS limits pending local notifications. Reserve capacity for deadlines.
            let pending = await center.pendingNotificationRequests()
            var capacity = max(0, 60 - pending.count)
            for hours in [0, 1, 2, 3, 4, 6, 8, 12, 24, 72] {
                guard commitments.contains(where: { $0.id == item.id && !$0.isComplete }) else {
                    cancel(item.id); return
                }
                let remaining = item.deadline.addingTimeInterval(-Double(hours) * 3600).timeIntervalSinceNow
                guard remaining >= 1 else { continue }
                guard capacity > 0 else {
                    notificationStatus = "Some reminders could not be scheduled because the device notification queue is full."
                    break
                }
                let body = UNMutableNotificationContent()
                body.title = hours == 0 ? "Time to execute" : "\(hours)h remaining"
                body.body = item.title
                body.sound = .default
                body.threadIdentifier = "execution"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
                try await center.add(UNNotificationRequest(identifier: "\(item.id.uuidString)-\(hours)", content: body, trigger: trigger))
                capacity -= 1
                if !commitments.contains(where: { $0.id == item.id && !$0.isComplete }) {
                    cancel(item.id); return
                }
            }
        } catch { notificationStatus = "Reminder scheduling failed: \(error.localizedDescription)" }
    }
}

@main struct ExecutionApp: App {
    @StateObject private var store = ExecutionStore()
    var body: some Scene {
        WindowGroup { ExecutionHome().environmentObject(store).tint(executionRed) }
    }
}

struct ExecutionHome: View {
    @EnvironmentObject private var store: ExecutionStore
    @AppStorage("execution.appearance") private var appearance = "System"
    @State private var showingComposer = false
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        masthead
                        metricPanel
                        HStack {
                            Text("ACTIVE COMMITMENTS").font(.caption.weight(.heavy)).tracking(1.5)
                            Spacer()
                            Text(String(store.active.count)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        if store.active.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: "scope").font(.system(size: 38, weight: .light)).foregroundStyle(executionRed)
                                Text("Your next move.").font(.title2.bold())
                                Text("Capture an intention. Set a deadline. Make it happen.").foregroundStyle(.secondary)
                                Button("Create commitment") { showingComposer = true }.buttonStyle(.borderedProminent)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                             .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26))
                        } else {
                            ForEach(store.active) { CommitmentCard(item: $0) }
                        }
                        if !store.notificationStatus.isEmpty {
                            Text(store.notificationStatus).font(.footnote).foregroundStyle(.secondary)
                        }
                    }.padding(20)
                }
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    Button { showingComposer = true } label: {
                        Label("NEW COMMITMENT", systemImage: "plus")
                            .font(.headline.weight(.heavy)).tracking(1)
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                            .foregroundStyle(.white)
                            .background(executionRed, in: Capsule())
                    }.buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                }
            }.tabItem { Label("Execute", systemImage: "bolt.fill") }.tag(0)
            NavigationStack {
                List {
                    Section("Accomplishments") {
                        if store.completed.isEmpty {
                            Text("Completed commitments will appear here.").foregroundStyle(.secondary)
                        }
                        ForEach(store.completed) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Label(item.title, systemImage: "checkmark.circle.fill").font(.headline)
                                if let date = item.completedAt {
                                    Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                    Text(date <= item.deadline ? "On time" : "Completed after deadline").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.onDelete { indices in
                            let ids = indices.map { store.completed[$0].id }
                            ids.forEach { store.remove($0) }
                        }
                    }
                }.navigationTitle("History")
            }.tabItem { Label("History", systemImage: "chart.bar.xaxis") }.tag(1)
            NavigationStack {
                Form {
                    Section("Appearance") {
                        Picker("Theme", selection: $appearance) {
                            ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) }
                        }
                    }
                    Section("Reminders") {
                        Text("Opt in when creating a commitment. Eligible reminders are scheduled 72, 24, 12, 8, 6, 4, 3, 2 and 1 hours before the deadline, plus at the deadline.")
                        Button("Open device settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    Section("Execution") {
                        Text("Shorten the time between thought and execution.")
                        Text("Designed for winning.").fontWeight(.heavy)
                    }
                }.navigationTitle("Settings")
            }.tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
        }
        .preferredColorScheme(appearance == "Light" ? .light : appearance == "Dark" ? .dark : nil)
        .sheet(isPresented: $showingComposer) { CommitmentComposer() }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Image(systemName: "bolt.fill").foregroundStyle(executionRed)
                Text("EXECUTION").font(.system(size: 32, weight: .black, design: .default)).tracking(-1.6)
                Spacer()
            }
            Text("DO OR DIE").font(.caption.weight(.heavy)).tracking(4).foregroundStyle(executionRed)
            Text("Designed for winning.").font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var metricPanel: some View {
        HStack(spacing: 12) {
            metric("COMPLETED TODAY", "\(store.completedToday)")
            Divider().frame(height: 45).overlay(.white.opacity(0.25))
            metric("AVG. TIME TO START", store.averageStartMinutes.map { "\($0)m" } ?? "—")
        }.padding(20).frame(maxWidth: .infinity)
         .foregroundStyle(.white)
         .background(
            LinearGradient(colors: [executionRed, Color(red: 0.46, green: 0.015, blue: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26)
         )
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .heavy)).tracking(0.8)
            Text(value).font(.system(size: 34, weight: .black, design: .rounded)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CommitmentCard: View {
    @EnvironmentObject private var store: ExecutionStore
    let item: Commitment
    @State private var confirmRemoval = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(item.priority.rawValue.uppercased()).font(.caption.weight(.heavy)).tracking(1)
                    .foregroundStyle(item.priority == .standard ? Color.secondary : executionRed)
                Spacer()
                Menu {
                    Button("Delete commitment", role: .destructive) { confirmRemoval = true }
                } label: { Image(systemName: "ellipsis").padding(7) }.accessibilityLabel("Commitment options")
            }
            Text(item.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = Int(item.deadline.timeIntervalSince(context.date))
                VStack(alignment: .leading, spacing: 6) {
                    Text(seconds <= 0 ? "OVERDUE" : "TIME REMAINING").font(.caption2.weight(.heavy)).tracking(1.2)
                    Text(countdown(abs(seconds))).font(.system(size: 36, weight: .heavy, design: .monospaced)).monospacedDigit()
                    Text("Due " + item.deadline.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }.foregroundStyle(executionRed)
            }
            HStack(spacing: 10) {
                if item.startedAt == nil {
                    Button("START") { store.start(item.id) }.buttonStyle(.bordered).font(.caption.weight(.heavy))
                } else {
                    Label("IN PROGRESS", systemImage: "bolt.fill").font(.caption.weight(.heavy)).foregroundStyle(executionRed)
                }
                Spacer()
                Button { store.complete(item.id) } label: {
                    Label("COMPLETE", systemImage: "checkmark").font(.caption.weight(.heavy))
                }.buttonStyle(.borderedProminent)
            }
        }.padding(20).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(executionRed.opacity(0.15), lineWidth: 1))
        .confirmationDialog("Delete this commitment?", isPresented: $confirmRemoval, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { store.remove(item.id) }
        }
    }
    private func countdown(_ seconds: Int) -> String {
        let days = seconds / 86400
        let h = (seconds / 3600) % 24
        let m = (seconds / 60) % 60
        let s = seconds % 60
        let clock = String(format: "%02d:%02d:%02d", h, m, s)
        return days > 0 ? "\(days)d " + clock : clock
    }
}

struct CommitmentComposer: View {
    @EnvironmentObject private var store: ExecutionStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var priority: Priority = .high
    @State private var hours = 24
    @State private var custom = false
    @State private var deadline = Date().addingTimeInterval(86400)
    @State private var reminders = true
    @FocusState private var focused: Bool
    private let intervals = [1, 2, 3, 4, 6, 8, 12, 24, 72]
    var body: some View {
        NavigationStack {
            Form {
                Section("The commitment") {
                    TextField("What will you execute?", text: $title, axis: .vertical).focused($focused)
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Section("Deadline") {
                    Toggle("Custom deadline", isOn: $custom)
                    if custom {
                        DatePicker("Due", selection: $deadline, in: Date()...)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                            ForEach(intervals, id: \.self) { interval in
                                Button { hours = interval } label: {
                                    Text("\(interval)h").font(.headline.monospacedDigit())
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .foregroundStyle(hours == interval ? .white : executionRed)
                                        .background(hours == interval ? executionRed : executionRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).accessibilityAddTraits(hours == interval ? .isSelected : [])
                            }
                        }.padding(.vertical, 6)
                    }
                }
                Section("Accountability") {
                    Toggle("Deadline reminders", isOn: $reminders)
                    Text("Reminders are optional and can be controlled in device settings.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Commit to it")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("COMMIT") {
                        store.add(title: title, priority: priority, deadline: custom ? deadline : Date().addingTimeInterval(Double(hours) * 3600), reminders: reminders)
                        dismiss()
                    }.fontWeight(.heavy)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (custom && deadline <= Date()))
                }
            }
            .onAppear { focused = true }
        }
    }
}
