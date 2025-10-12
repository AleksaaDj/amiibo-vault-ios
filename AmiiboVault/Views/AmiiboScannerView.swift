import SwiftUI

// Suppress deprecation warning for NavigationLink - will be updated when migrating to NavigationStack

struct AmiiboScannerView: View {
    @Binding var isDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var nfcReader = NTAG215Reader()
    @StateObject private var adMobService = AdMobService.shared
    @State private var animationScale: CGFloat = 1.0
    @State private var showingAmiiboDetails = false
    @State private var scannedAmiibo: Amiibo?
    
    private let amiiboRepository: AmiiboRepository
    private let viewModel: AmiiboListViewModel
    
    init(isDetailsPresented: Binding<Bool>, viewModel: AmiiboListViewModel) {
        self._isDetailsPresented = isDetailsPresented
        self.viewModel = viewModel
        self.amiiboRepository = AmiiboRepositoryImpl(coreDataService: CoreDataService.shared)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Spacer()
                
                Text("amiibo scanner")
                    .foregroundColor(.appRed)
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(.systemBackground))
            
            // Main Content
            VStack(spacing: 15) {
                Spacer()
                    .frame(height: 60) // Further reduced space to push content up
                
                // Radar animation with fixed center - smaller radius, closer to icon
                ZStack {
                    // Circles expanding and shrinking - smaller radius, closer to icon
                    ForEach(0..<7, id: \.self) { index in
                        Circle()
                            .stroke(
                                index == 6 ? Color.gray.opacity(0.3) : // Lighter outer circle
                                index == 0 ? Color.gray.opacity(0.8) : // Darker inner circle
                                Color.gray.opacity(0.6), // Regular circles
                                lineWidth: 3
                            )
                            .frame(width: 120 + CGFloat(index * 25), height: 120 + CGFloat(index * 25))
                            .scaleEffect(animationScale)
                            .opacity(1 - Double(index) * 0.12)
                    }
                    
                    // NFC icon - absolutely centered with black circle background
                    Image("nfc_icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                        .background(
                            Circle()
                                .fill(Color.black)
                                .frame(width: 75, height: 75)
                        )
                }
                .frame(width: 250, height: 250)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                    ) {
                        animationScale = 1.2
                    }
                    
                    // Set up repository when view appears
                    nfcReader.setRepository(amiiboRepository)
                }
                .onDisappear {
                    // Stop NFC scanning when view disappears
                    nfcReader.stopScanning()
                }
                
                // Instruction Text
                Text("Tap the scan button below\nto start scanning for Amiibo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .padding(.top, 20) // Reduced padding to bring text closer
                
                
                // Scan Button
                Button(action: {
                    if nfcReader.isScanning {
                        nfcReader.stopScanning()
                    } else {
                        nfcReader.startScanning()
                    }
                }) {
                    HStack {
                        Image(systemName: nfcReader.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .medium))
                        Text(nfcReader.isScanning ? "Stop Scanning" : "Start Scanning")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(nfcReader.isScanning ? Color.gray : Color.appRed)
                    )
                }
                .padding(.top, 20)
                
                Spacer() // Push content up
                
                // Banner Ad at bottom
                LargeBannerAdView(adUnitID: adMobService.getBannerAdUnitID())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20) // Reduced padding for system tab bar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .alert("NFC Error", isPresented: .constant(nfcReader.errorMessage != nil)) {
            Button("OK") {
                nfcReader.errorMessage = nil
            }
        } message: {
            Text(nfcReader.errorMessage ?? "")
        }
        .onAppear {
            // Set up the repository for the NFC reader
            nfcReader.setRepository(amiiboRepository)
        }
        .onChange(of: nfcReader.scannedAmiibo) { amiibo in
            if let amiibo = amiibo {
                // Add a small delay to prevent rapid updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scannedAmiibo = amiibo
                    showingAmiiboDetails = true
                }
            }
        }
        .background(
            Group {
                if showingAmiiboDetails, let amiibo = scannedAmiibo {
                    // Suppress deprecation warning for NavigationLink
                    NavigationLink(
                        destination: AmiiboDetailsView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented),
                        isActive: $showingAmiiboDetails
                    ) {
                        EmptyView()
                    }
                }
            }
        )
    }
}

#Preview {
    AmiiboScannerView(isDetailsPresented: .constant(false), viewModel: AmiiboListViewModel())
}
