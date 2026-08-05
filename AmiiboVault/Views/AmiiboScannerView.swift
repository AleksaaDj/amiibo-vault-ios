import SwiftUI
import FirebaseAnalytics

// Suppress deprecation warning for NavigationLink - will be updated when migrating to NavigationStack

struct AmiiboScannerView: View {
    @Binding var isDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var nfcReader = NTAG215Reader()
    @StateObject private var adMobService = AdMobService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
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
            scannerNavigationBar
            scannerMainContent
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
            
            // Log screen view
            analyticsService.logScreenView("scanner_screen", screenClass: "AmiiboScannerView")
            analyticsService.logEvent(AnalyticsService.AMIIBO_SCANNER_SCREEN_OPENED)
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
                        destination: AmiiboDetailsView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented, amiiboList: nil),
                        isActive: $showingAmiiboDetails
                    ) {
                        EmptyView()
                    }
                }
            }
        )
    }

    private var scannerNavigationBar: some View {
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
    }

    private var scannerMainContent: some View {
        VStack(spacing: 8) {
            Spacer()
                .frame(height: 100)

            if purchaseManager.isAmiiboScanPurchased {
                ScannerRadarAnimationView(animationScale: animationScale)
                    .padding(.bottom, 10)
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            animationScale = 1.2
                        }
                        nfcReader.setRepository(amiiboRepository)
                    }
                    .onDisappear {
                        nfcReader.stopScanning()
                    }
            } else {
                Image("link_scanner")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250, height: 250)
                    .padding(.bottom, 10)
                    .onAppear {
                        nfcReader.setRepository(amiiboRepository)
                    }
            }

            if purchaseManager.isAmiiboScanPurchased {
                scannerPurchasedControls
            } else {
                scannerPurchasePrompt
            }

            Spacer()

            if !purchaseManager.isNoAdsPurchased {
                LargeBannerAdView(adUnitID: adMobService.getBannerAdUnitID())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scannerPurchasedControls: some View {
        Group {
            Text("Tap the scan button below\nto start scanning for Amiibo")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Button(action: toggleScanning) {
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
            .padding(.top, 8)
        }
    }

    private var scannerPurchasePrompt: some View {
        Group {
            Text("Enable NFC Scanning")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Text("Scan your Amiibo figures and get all the details instantaneously. Simply tap your Amiibo to the back of your phone to unlock character information, game compatibility, and more.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
                .padding(.top, 5)

            Button(action: enableScanningPurchase) {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .medium))
                    Text("Enable Scanning")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.appRed)
                )
            }
            .padding(.top, 8)
        }
    }

    private func toggleScanning() {
        if nfcReader.isScanning {
            nfcReader.stopScanning()
        } else {
            nfcReader.startScanning()
        }
    }

    private func enableScanningPurchase() {
        Task {
            await purchaseManager.makeAmiiboScanPurchase()
            analyticsService.logEvent(AnalyticsService.AMIIBO_ENABLE_SCANNER, name: "enable_scanner_button_clicked")
        }
    }
}

private struct ScannerRadarAnimationView: View {
    let animationScale: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                ScannerRadarRingView(index: index, animationScale: animationScale)
            }

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
    }
}

private struct ScannerRadarRingView: View {
    let index: Int
    let animationScale: CGFloat

    private var ringSize: CGFloat {
        120 + CGFloat(index * 25)
    }

    private var ringColor: Color {
        if index == 6 {
            return Color.gray.opacity(0.3)
        }
        if index == 0 {
            return Color.gray.opacity(0.8)
        }
        return Color.gray.opacity(0.6)
    }

    private var ringOpacity: Double {
        1 - Double(index) * 0.12
    }

    var body: some View {
        Circle()
            .stroke(ringColor, lineWidth: 3)
            .frame(width: ringSize, height: ringSize)
            .scaleEffect(animationScale)
            .opacity(ringOpacity)
    }
}

#Preview {
    AmiiboScannerView(isDetailsPresented: .constant(false), viewModel: AmiiboListViewModel())
}
