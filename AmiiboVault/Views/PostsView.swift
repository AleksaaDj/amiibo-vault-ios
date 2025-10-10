import SwiftUI

struct PostsView: View {
    @StateObject private var viewModel = PostsViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingCreatePost = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Community collections")
                    .font(.title2)
                    .fontWeight(.regular)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                Spacer()
                
                Button(action: {
                    showingCreatePost = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.appRed)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading posts...")
                    .foregroundColor(.appRed)
                Spacer()
            } else if viewModel.posts.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No posts yet")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                // Posts List
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.posts) { post in
                            CollectionPostItemView(
                                post: post,
                                isLiked: viewModel.isLiked(postId: post.postId),
                                onLikeTapped: {
                                    if let postId = post.postId {
                                        viewModel.toggleLike(postId: postId)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
        }
    }
}

struct CollectionPostItemView: View {
    let post: CollectionPost
    let isLiked: Bool
    let onLikeTapped: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // User Info and Likes
            HStack(alignment: .center) {
                // Avatar
                ZStack {
                    Circle()
                        .stroke(AvatarHelper.getRainbowGradient(), lineWidth: 2)
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .fill(AvatarHelper.getAvatarColor(backgroundColorIndex: post.backgroundColor))
                        .frame(width: 44, height: 44)
                    
                    Image(post.avatarId == 0 ? "avatar_placeholder" : AvatarHelper.getAvatarImage(avatarId: post.avatarId))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    if let name = post.name {
                        Text("Shared by: \(name)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    }
                    
                    if let date = post.date {
                        Text(formatDate(date))
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    }
                }
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Like Button and Count
                HStack(spacing: 4) {
                    Button(action: onLikeTapped) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(.appRed)
                            .font(.system(size: 20))
                    }
                    
                    if let likes = post.likes {
                        Text(likes)
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    }
                }
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            
            // Post Image
            if let imageUrl = post.image {
                CachedAsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        ZStack {
                            // Fixed-size black background container
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 280)
                            
                            // Image centered within the black container
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 280)
                        }
                    case .failure(_):
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 280)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white)
                                    .font(.system(size: 30))
                            )
                    case .empty:
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 280)
                            .overlay(
                                ProgressView()
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 280)
                    }
                } placeholder: {
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 280)
                        .overlay(
                            ProgressView()
                                .foregroundColor(.white)
                        )
                }
                .clipped()
                .cornerRadius(8)
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
            }
            
            // Post Text
            if let text = post.text, !text.isEmpty {
                HStack {
                    if let name = post.name {
                        Text("\(name): \(text)")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Extract just the date part (before space)
        return dateString.components(separatedBy: " ").first ?? dateString
    }
}

#Preview {
    PostsView()
}
