import Foundation
import Combine

protocol AmiiboRepository {
    func getAmiiboByTailId(_ tailId: String) -> AnyPublisher<Amiibo?, Never>
    func getAmiiboByTailId(_ tailId: String, completion: @escaping (Amiibo?) -> Void)
}

class AmiiboRepositoryImpl: AmiiboRepository {
    private let coreDataService: CoreDataService
    
    init(coreDataService: CoreDataService) {
        self.coreDataService = coreDataService
    }
    
    func getAmiiboByTailId(_ tailId: String) -> AnyPublisher<Amiibo?, Never> {
        return Future<Amiibo?, Never> { [weak self] promise in
            guard let self = self else {
                promise(.success(nil))
                return
            }
            
            // Use the existing getAmiiboByTail method from CoreDataService
            let foundAmiibo = self.coreDataService.getAmiiboByTail(tailId)
            promise(.success(foundAmiibo))
        }
        .eraseToAnyPublisher()
    }
    
    func getAmiiboByTailId(_ tailId: String, completion: @escaping (Amiibo?) -> Void) {
        // Use the existing getAmiiboByTail method from CoreDataService
        let foundAmiibo = coreDataService.getAmiiboByTail(tailId)
        completion(foundAmiibo)
    }
}
