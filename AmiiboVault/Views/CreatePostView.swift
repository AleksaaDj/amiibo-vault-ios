import SwiftUI

// Suppress ViewBuilder warning for iOS version compatibility
import PhotosUI

// ImagePicker for iOS < 16.0 compatibility
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var adMobService = AdMobService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar Section
                    avatarSection
                    
                    // Name Field
                    nameField
                    
                    // Description Field
                    descriptionField
                    
                    // Image Upload Section
                    imageUploadSection
                    
                    // Publish Button
                    publishButton
                    
                    // Banner Ad
                    LargeBannerAdView(adUnitID: adMobService.getBannerAdUnitID())
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appRed)
                }
            }
        }
        .background(Color(.systemBackground))
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onChange(of: selectedItem) { newItem in
            if #available(iOS 16.0, *) {
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        viewModel.selectedImage = UIImage(data: data)
                    }
                }
            }
        }
        .onChange(of: viewModel.postPublished) { published in
            if published {
                dismiss()
            }
        }
        .sheet(isPresented: $viewModel.showAvatarPicker) {
            AvatarPickerView(
                selectedAvatarIndex: $viewModel.selectedAvatarIndex,
                selectedBackgroundIndex: $viewModel.selectedBackgroundIndex,
                avatarColors: viewModel.avatarColors,
                avatarImages: viewModel.avatarImages
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $viewModel.selectedImage)
        }
    }
    
    private var avatarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Avatar")
                    .font(.headline)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                Spacer()
            }
            
            Button(action: {
                viewModel.showAvatarPicker = true
            }) {
                HStack {
                    // Avatar Preview with rainbow border
                    ZStack {
                        // Rainbow border (sweep gradient like Android)
                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.584, green: 0.459, blue: 0.804), // #9575CD
                                        Color(red: 0.729, green: 0.408, blue: 0.784), // #BA68C8
                                        Color(red: 0.898, green: 0.451, blue: 0.451), // #E57373
                                        Color(red: 1.0, green: 0.718, blue: 0.302),   // #FFB74D
                                        Color(red: 1.0, green: 0.945, blue: 0.463),   // #FFF176
                                        Color(red: 0.682, green: 0.835, blue: 0.506), // #AED581
                                        Color(red: 0.302, green: 0.816, blue: 0.882), // #4DD0E1
                                        Color(red: 0.584, green: 0.459, blue: 0.804)  // #9575CD
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 66, height: 66)
                        
                        // Background circle
                        Circle()
                            .fill(viewModel.avatarColors[viewModel.selectedBackgroundIndex])
                            .frame(width: 60, height: 60)
                        
                        // Avatar image
                        Image(viewModel.avatarImages[viewModel.selectedAvatarIndex])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Create your avatar")
                            .font(.subheadline)
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        Text("Tap to customize")
                            .font(.caption)
                            .foregroundColor(themeManager.isDarkMode ? .white : .secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.gray.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name to be displayed")
                .font(.headline)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
            
            TextField("Enter your name", text: $viewModel.name)
                .padding()
                .background(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.gray.opacity(0.1))
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .accentColor(themeManager.isDarkMode ? .white : .black)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.5), lineWidth: 1)
                )
                .onChange(of: viewModel.name) { newValue in
                    if newValue.count > 20 {
                        viewModel.name = String(newValue.prefix(20))
                    }
                }
        }
    }
    
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description (optional)")
                .font(.headline)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
            
            if #available(iOS 16.0, *) {
                TextField("Describe your collection...", text: $viewModel.description, axis: .vertical)
                    .padding()
                    .background(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.gray.opacity(0.1))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .accentColor(themeManager.isDarkMode ? .white : .black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .lineLimit(3...6)
            } else {
                TextField("Describe your collection...", text: $viewModel.description)
                    .padding()
                    .background(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.gray.opacity(0.1))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .accentColor(themeManager.isDarkMode ? .white : .black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .lineLimit(3)
            }
        }
    }
    
    private var imageUploadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload image of amiibo collection")
                .font(.headline)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
            
            if #available(iOS 16.0, *) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .fill(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.gray.opacity(0.1))
                            .frame(height: 280)
                        
                        if let image = viewModel.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 280)
                                .clipped()
                                .cornerRadius(12)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("Tap to select image")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                // Fallback for iOS < 16.0
                Button(action: {
                    showingImagePicker = true
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .fill(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.gray.opacity(0.1))
                            .frame(height: 280)
                        
                        if let image = viewModel.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 280)
                                .clipped()
                                .cornerRadius(12)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("Tap to select image")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var publishButton: some View {
        Button(action: {
            viewModel.publishPost()
        }) {
            HStack {
                if viewModel.isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(viewModel.isUploading ? "Publishing..." : "Publish Collection")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appRed)
            .cornerRadius(12)
        }
        .disabled(viewModel.name.isEmpty || viewModel.isUploading)
        .opacity(viewModel.name.isEmpty ? 0.6 : 1.0)
    }
}

struct AvatarPickerView: View {
    @Binding var selectedAvatarIndex: Int
    @Binding var selectedBackgroundIndex: Int
    let avatarColors: [Color]
    let avatarImages: [String]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Background Color Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Background Color:")
                            .font(.headline)
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                            ForEach(0..<avatarColors.count, id: \.self) { index in
                                Button(action: {
                                    selectedBackgroundIndex = index
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(avatarColors[index])
                                            .frame(width: 50, height: 50)
                                        
                                        if selectedBackgroundIndex == index {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .bold))
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Avatar Image Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Avatar Image:")
                            .font(.headline)
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(0..<avatarImages.count, id: \.self) { index in
                                Button(action: {
                                    selectedAvatarIndex = index
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(avatarColors[selectedBackgroundIndex])
                                            .frame(width: 70, height: 70)
                                        
                                        Image(avatarImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                        
                                        if selectedAvatarIndex == index {
                                            // White checkmark
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.white)
                                                .background(
                                                    Circle()
                                                        .fill(Color.black.opacity(0.7))
                                                        .frame(width: 30, height: 30)
                                                )
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Finish Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Finish Creation")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
            .navigationTitle("Create Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appRed)
                }
            }
        }
    }
}

#Preview {
    CreatePostView()
}