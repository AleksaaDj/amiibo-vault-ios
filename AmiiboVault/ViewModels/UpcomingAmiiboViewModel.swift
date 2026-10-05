import Foundation
import Combine

final class UpcomingAmiiboViewModel: ObservableObject {
    @Published var items: [UpcomingAmiibo] = []
    @Published var isLoading = true

    func loadUpcoming() {
        isLoading = true
        UpcomingAmiiboSync.shared.tryLoadUpcoming { [weak self] response in
            DispatchQueue.main.async {
                self?.items = response?.items ?? []
                self?.isLoading = false
            }
        }
    }
}
