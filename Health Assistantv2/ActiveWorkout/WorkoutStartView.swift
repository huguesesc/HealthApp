import SwiftData
import SwiftUI

/// Entry point for starting a saved plan, resuming an interruption, or reviewing
/// recent execution summaries.
struct WorkoutStartView: View {
    @Query(sort: \WorkoutPlan.updatedAt, order: .reverse)
    private var plans: [WorkoutPlan]

    @Query(sort: \ActiveWorkoutSession.updatedAt, order: .reverse)
    private var sessions: [ActiveWorkoutSession]

    var body: some View {
        List {
            if !resumableSessions.isEmpty {
                Section("Continue workout") {
                    ForEach(resumableSessions, id: \.id) { session in
                        NavigationLink {
                            ActiveWorkoutView(session: session)
                        } label: {
                            sessionLabel(session)
                        }
                    }
                }
            }

            Section {
                if availablePlans.isEmpty {
                    ContentUnavailableView(
                        "No runnable plans",
                        systemImage: "list.clipboard",
                        description: Text("Create a structured workout plan with at least one step first.")
                    )
                } else {
                    ForEach(availablePlans, id: \.id) { plan in
                        NavigationLink {
                            ActiveWorkoutLauncherView(plan: plan)
                        } label: {
                            planLabel(plan)
                        }
                    }
                }
            } header: {
                Text("Start a plan")
            } footer: {
                Text("Starting creates a durable snapshot. Later edits to the plan will not change the workout already in progress.")
            }

            if !recentSessions.isEmpty {
                Section("Recent executions") {
                    ForEach(recentSessions.prefix(10), id: \.id) { session in
                        NavigationLink {
                            ActiveWorkoutView(session: session)
                        } label: {
                            sessionLabel(session)
                        }
                    }
                }
            }
        }
        .navigationTitle("Start workout")
    }

    private var availablePlans: [WorkoutPlan] {
        plans.filter { !$0.isArchived && !$0.steps.isEmpty }
    }

    private var resumableSessions: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .inProgress || $0.status == .paused }
    }

    private var recentSessions: [ActiveWorkoutSession] {
        sessions.filter { $0.status == .completed || $0.status == .abandoned }
    }

    private func planLabel(_ plan: WorkoutPlan) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.evergreen)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.headline)
                Text(planDetail(plan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func sessionLabel(_ session: ActiveWorkoutSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.status == .completed ? "checkmark.circle.fill" : "figure.run.circle.fill")
                .font(.title3)
                .foregroundStyle(session.status == .completed ? Theme.moss : Theme.honey)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.titleSnapshot)
                    .font(.headline)
                Text(sessionDetail(session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func planDetail(_ plan: WorkoutPlan) -> String {
        var parts = ["\(plan.steps.count) step(s)"]
        if let minutes = plan.estimatedDurationMinutes { parts.append("\(minutes) min") }
        if let location = plan.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }

    private func sessionDetail(_ session: ActiveWorkoutSession) -> String {
        var parts = [session.status.displayName]
        let elapsed = session.elapsedSeconds(at: session.completedAt ?? .now)
        parts.append(elapsed < 60 ? "\(elapsed) sec" : "\(elapsed / 60) min")
        if let location = session.locationNameSnapshot { parts.append(location) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { WorkoutStartView() }
        .modelContainer(PersistenceController.preview.container)
}
