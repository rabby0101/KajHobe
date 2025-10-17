import SwiftUI
import UniformTypeIdentifiers
import Supabase
import PostgREST

struct DragDropJobBoard: View {
    @State private var openJobs: [Job] = []
    @State private var inProgressJobs: [Job] = []
    @State private var completedJobs: [Job] = []
    @State private var isLoading = false
    
    enum JobColumn: String, CaseIterable {
        case open = "Open"
        case inProgress = "In Progress"
        case completed = "Completed"
        
        var color: Color {
            switch self {
            case .open: return .blue
            case .inProgress: return .orange
            case .completed: return .green
            }
        }
        
        var systemImage: String {
            switch self {
            case .open: return "folder.badge.plus"
            case .inProgress: return "hammer.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    // Open Jobs Column
                    JobColumnView(
                        title: JobColumn.open.rawValue,
                        color: JobColumn.open.color,
                        systemImage: JobColumn.open.systemImage,
                        jobs: openJobs,
                        onJobDropped: { job in
                            moveJob(job, to: .open)
                        },
                        onJobDeleted: {
                            Task {
                                await loadJobs()
                            }
                        }
                    )
                    
                    // In Progress Jobs Column
                    JobColumnView(
                        title: JobColumn.inProgress.rawValue,
                        color: JobColumn.inProgress.color,
                        systemImage: JobColumn.inProgress.systemImage,
                        jobs: inProgressJobs,
                        onJobDropped: { job in
                            moveJob(job, to: .inProgress)
                        },
                        onJobDeleted: {
                            Task {
                                await loadJobs()
                            }
                        }
                    )
                    
                    // Completed Jobs Column
                    JobColumnView(
                        title: JobColumn.completed.rawValue,
                        color: JobColumn.completed.color,
                        systemImage: JobColumn.completed.systemImage,
                        jobs: completedJobs,
                        onJobDropped: { job in
                            moveJob(job, to: .completed)
                        },
                        onJobDeleted: {
                            Task {
                                await loadJobs()
                            }
                        }
                    )
                }
                .padding(.horizontal)
            }
            .navigationTitle("Job Board")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadJobs()
            }
            .refreshable {
                await loadJobs()
            }
        }
    }
    
    private func loadJobs() async {
        isLoading = true
        do {
            let allJobs = try await Networking.shared.fetchJobs()
            
            await MainActor.run {
                openJobs = allJobs.filter { $0.status == "open" }
                inProgressJobs = allJobs.filter { $0.status == "in_progress" }
                completedJobs = allJobs.filter { $0.status == "completed" }
            }
        } catch {
            print("Error loading jobs: \(error)")
        }
        isLoading = false
    }
    
    private func moveJob(_ job: Job, to column: JobColumn) {
        // Remove from current arrays
        openJobs.removeAll { $0.id == job.id }
        inProgressJobs.removeAll { $0.id == job.id }
        completedJobs.removeAll { $0.id == job.id }
        
        // Create updated job
        var updatedJob = job
        let newStatus = column.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        updatedJob.status = newStatus
        
        // Add to appropriate array
        switch column {
        case .open:
            openJobs.append(updatedJob)
        case .inProgress:
            inProgressJobs.append(updatedJob)
        case .completed:
            completedJobs.append(updatedJob)
        }
        
        // Update in database
        Task {
            do {
                try await updateJobStatus(job.id, status: newStatus)
                
                // Provide haptic feedback
                if #available(iOS 17.0, *) {
                    // Use modern sensory feedback
                } else {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } catch {
                print("Error updating job status: \(error)")
                // Revert the change on error
                await loadJobs()
            }
        }
    }
    
    private func updateJobStatus(_ jobId: String, status: String) async throws {
        let _ = try await supabase
            .from("jobs")
            .update(["status": status])
            .eq("id", value: jobId)
            .execute()
    }
}

struct JobColumnView: View {
    let title: String
    let color: Color
    let systemImage: String
    let jobs: [Job]
    let onJobDropped: (Job) -> Void
    let onJobDeleted: () -> Void
    
    @State private var isTargeted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Column Header
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(jobs.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundColor(color)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // Jobs List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(jobs) { job in
                        DraggableJobCard(
                            job: job,
                            color: color,
                            onJobDeleted: onJobDeleted
                        )
                    }
                    
                    if jobs.isEmpty {
                        EmptyColumnView(
                            title: title,
                            color: color,
                            systemImage: systemImage
                        )
                        .frame(height: 200)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .shadow(color: isTargeted ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
        // Temporarily commented out due to Transferable conformance issues
        /*
        .dropDestination(for: Job.self) { jobs, location in
            if let job = jobs.first {
                onJobDropped(job)
                return true
            }
            return false
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        */
    }
}

struct DraggableJobCard: View {
    let job: Job
    let color: Color
    let onJobDeleted: () -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(job.category)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .cornerRadius(6)
                
                Spacer()
                
                if job.urgent == true {
                    Text("URGENT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            // Title
            Text(job.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            // Description
            Text(job.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Budget and Location
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(color)
                        .font(.caption)
                    Text("৳\(job.budget)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text(job.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Footer
            HStack {
                Text("Posted \(formatDate(job.created_at ?? ""))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Drag indicator
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(isDragging ? 0.15 : 0.05), radius: isDragging ? 8 : 2, x: 0, y: isDragging ? 4 : 1)
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        // Temporarily commented out due to Transferable conformance issues
        /*
        .draggable(job) {
            // Drag preview
            VStack(alignment: .leading, spacing: 8) {
                Text(job.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text("৳\(job.budget)")
                    .font(.subheadline)
                    .foregroundColor(color)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 8)
            )
            .frame(width: 200)
        }
        */
        .onChange(of: isDragging) { _, newValue in
            if newValue {
                // Provide haptic feedback when drag starts
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
        .contextMenu {
            Button(action: {
                // View details
            }) {
                Label("View Details", systemImage: "eye")
            }
            
            Button(action: {
                // Edit job
            }) {
                Label("Edit Job", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                // Delete job
                onJobDeleted()
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .none
            displayFormatter.doesRelativeDateFormatting = true
            
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                displayFormatter.dateStyle = .short
                return displayFormatter.string(from: date)
            }
        }
        return "Recently"
    }
}

struct EmptyColumnView: View {
    let title: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(color.opacity(0.5))
            
            VStack(spacing: 4) {
                Text("No \(title) Jobs")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Drag jobs here to organize them")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .background(color.opacity(0.05))
        )
        .padding()
    }
}

// MARK: - Make Job Transferable for Drag and Drop
// Note: Temporarily commented out due to main actor isolation issues
/*
extension Job: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .job)
    }
}

extension UTType {
    static let job = UTType(exportedAs: "com.kajhobe.job")
}
*/

#Preview {
    DragDropJobBoard()
}