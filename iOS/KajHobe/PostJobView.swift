import SwiftUI
import Supabase
import PhotosUI

struct JobSubmission: Sendable {
    let title: String
    let description: String
    let category: String
    let budget: Double
    let location: String
    let urgent: Bool
    let status: String
    let client_id: String
}

nonisolated extension JobSubmission: Encodable {}

struct PostJobView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var category = "Technology & IT"
    @State private var budget = ""
    @State private var location = "Khulna Sadar"
    @State private var isUrgent = false
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var isTabLoading = false

    // Media upload states
    @State private var selectedMedia: [SelectedMediaItem] = []
    @State private var uploadedMediaItems: [Job.MediaItem] = []
    @State private var isUploadingMedia = false
    @State private var uploadProgress: Double = 0.0
    @StateObject private var mediaUploadManager = MediaUploadManager.shared

    // Keyboard focus management — drives field-to-field flow and the Done button.
    private enum Field { case title, budget, description }
    @FocusState private var focusedField: Field?

    let categories = HardcodedServiceCategory.getCategoryNames()
    
    let locations = [
        "Khulna Sadar",
        "Daulatpur",
        "Khalishpur",
        "Sonadanga",
        "Khan Jahan Ali",
        "Harintana",
        "Labanchara",
        "Batiaghata",
        "Paikgachha",
        "Dighalia"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Tab Loading Indicator
                    if isTabLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading...")
                                .padding(.vertical, 8)
                            Spacer()
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal, 20)
                    }
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create New Job")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Fill out the details to post your job and connect with skilled professionals")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Job Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Job Title")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Enter a clear, descriptive title", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.body)
                                .focused($focusedField, equals: .title)
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .description }
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }

                        // Media Upload Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Photos & Videos")
                                    .font(.headline)
                                    .fontWeight(.semibold)

                                Spacer()

                                Text("Optional")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            MediaPickerView(selectedMedia: $selectedMedia, maxSelections: 5)

                            if isUploadingMedia {
                                HStack(spacing: 8) {
                                    ProgressView(value: uploadProgress)
                                        .progressViewStyle(LinearProgressViewStyle())

                                    Text("\(Int(uploadProgress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 40)
                                }
                            }

                            if !uploadedMediaItems.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("\(uploadedMediaItems.count) file(s) ready to upload")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Job Description")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextEditor(text: $description)
                                .focused($focusedField, equals: .description)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                                .overlay(alignment: .topLeading) {
                                    // Static placeholder — kept in the hierarchy and just
                                    // shown/hidden, so no view is inserted/removed (and no
                                    // layout reflow) on each keystroke.
                                    if description.isEmpty {
                                        Text("Describe what you need done, required skills, timeline, and any specific requirements")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 13)
                                            .padding(.vertical, 16)
                                            .allowsHitTesting(false)
                                    }
                                }
                        }
                        
                        // Budget and Location Row
                        HStack(spacing: 16) {
                            // Budget
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Budget (৳)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                TextField("0", text: $budget)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .font(.body)
                                    .focused($focusedField, equals: .budget)
                            }
                            
                            // Location
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Picker("Location", selection: $location) {
                                    ForEach(locations, id: \.self) { location in
                                        Text(location).tag(location)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Urgent Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mark as Urgent")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Urgent jobs get higher visibility")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $isUrgent)
                                .toggleStyle(SwitchToggleStyle(tint: .red))
                        }
                        
                        // Submit Button
                        Button(action: submitJob) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.headline)
                                }
                                
                                Text(isLoading ? "Posting Job..." : "Post Job")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Post a Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        focusedField = nil // dismiss keyboard before leaving
                        NotificationCenter.default.post(name: NSNotification.Name("NavigateToJobs"), object: nil)
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .alert("Success!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    clearForm()
                }
            } message: {
                Text("Your job has been posted successfully!")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPostJob"))) { _ in
                // Simulate loading when tab is selected
                isTabLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTabLoading = false
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && 
        !description.isEmpty && 
        !budget.isEmpty && 
        Double(budget) != nil &&
        Double(budget)! > 0
    }
    
    @MainActor
    private func submitJob() {
        guard let budgetValue = Double(budget) else {
            alertMessage = "Please enter a valid budget amount"
            showingAlert = true
            return
        }

        isLoading = true

        // Capture main actor values before entering Task
        let titleValue = title
        let descriptionValue = description
        let categoryValue = category
        let locationValue = location
        let urgentValue = isUrgent

        Task {
            do {
                let user = try supabase.auth.requireCurrentUser()

                // Step 1: Upload media files if any are selected
                var mediaItems: [Job.MediaItem] = []

                if !selectedMedia.isEmpty {
                    isUploadingMedia = true
                    uploadProgress = 0.0

                    // Process each selected media item
                    for (index, mediaItem) in selectedMedia.enumerated() {
                        do {
                            let uploadedItem: Job.MediaItem?

                            // Check if we have a PhotosPickerItem (from photo library)
                            if let pickerItem = mediaItem.pickerItem {
                                // Upload via PhotosPickerItem
                                uploadedItem = try await mediaUploadManager.uploadMediaItems([pickerItem]).first
                            }
                            // Check if we have a direct UIImage (from camera)
                            else if let image = mediaItem.image {
                                // Upload UIImage directly
                                uploadedItem = try await mediaUploadManager.uploadImage(image)
                            }
                            // Check if we have a video URL
                            else if let videoURL = mediaItem.videoURL {
                                // Upload video directly
                                uploadedItem = try await mediaUploadManager.uploadVideo(from: videoURL)
                            } else {
                                uploadedItem = nil
                            }

                            if let uploadedItem = uploadedItem {
                                mediaItems.append(uploadedItem)
                            }

                            // Update progress
                            await MainActor.run {
                                uploadProgress = Double(index + 1) / Double(selectedMedia.count)
                            }
                        } catch {
                            print("❌ Error uploading media item \(index): \(error)")
                            // Continue with other items
                        }
                    }

                    await MainActor.run {
                        uploadedMediaItems = mediaItems
                        uploadProgress = 1.0
                        isUploadingMedia = false
                    }

                    print("📤 Uploaded \(mediaItems.count) out of \(selectedMedia.count) media items")
                }

                // Step 2: Create job submission struct
                // Create the struct in a way that's Sendable-safe
                struct JobSubmissionData: Encodable, Sendable {
                    let title: String
                    let description: String
                    let category: String
                    let location: String
                    let status: String
                    let urgent: Bool
                    let client_id: String
                    let budget: Int
                    let media_urls: [Job.MediaItem]?
                }

                let jobData = JobSubmissionData(
                    title: titleValue,
                    description: descriptionValue,
                    category: categoryValue,
                    location: locationValue,
                    status: "open",
                    urgent: urgentValue,
                    client_id: user.id.uuidString,
                    budget: Int(budgetValue),
                    media_urls: mediaItems.isEmpty ? nil : mediaItems
                )

                // Step 3: Insert job into database
                let _ = try await supabase
                    .from("jobs")
                    .insert(jobData)
                    .select()
                    .execute()

                print("✅ Job posted successfully with \(mediaItems.count) media items")

                await MainActor.run {
                    isLoading = false
                    showingSuccessAlert = true
                }
                print("✅ Job posted successfully with \(mediaItems.count) media items")
            } catch {
                await MainActor.run {
                    isLoading = false
                    isUploadingMedia = false
                    alertMessage = "Failed to post job: \(error.localizedDescription)"
                    showingAlert = true
                }
                print("❌ Error posting job: \(error)")
            }
        }
    }
    
    private func clearForm() {
        title = ""
        description = ""
        category = "Technology & IT"
        budget = ""
        location = "Khulna Sadar"
        isUrgent = false
        selectedMedia = []
        uploadedMediaItems = []
        uploadProgress = 0.0
    }
}

#Preview {
    PostJobView()
} 
