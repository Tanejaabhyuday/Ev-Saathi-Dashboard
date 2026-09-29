import Foundation
import FirebaseFirestore

// MARK: - FirestoreService
// Singleton that wraps all Firestore operations.
// Offline persistence is enabled on init so the app works without network.

final class FirestoreService {

    static let shared = FirestoreService()
    let db: Firestore

    private init() {
        // Enable offline persistence (caches all Firestore data on-device)
        // Uses the modern cacheSettings API (Firebase iOS SDK 10.12+)
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(
            sizeBytes: FirestoreCacheSizeUnlimited as NSNumber
        )
        let db = Firestore.firestore()
        db.settings = settings
        self.db = db
    }

    // MARK: - Collection References

    var busesRef:    CollectionReference { db.collection("buses") }
    var chargersRef: CollectionReference { db.collection("chargers") }
    var alertsRef:   CollectionReference { db.collection("alerts") }
    var usersRef:    CollectionReference { db.collection("users") }

    // MARK: - Bus Operations

    /// Adds a real-time listener on the buses collection.
    /// Returns a ListenerRegistration that the caller must retain and remove on deinit.
    func listenToBuses(completion: @escaping ([BusModel]) -> Void) -> ListenerRegistration {
        return busesRef.addSnapshotListener(includeMetadataChanges: false) { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let buses = docs.compactMap { BusModel(from: $0.data()) }
            completion(buses)
        }
    }

    func updateBus(_ bus: BusModel) {
        busesRef.document(bus.id).setData(bus.toFirestoreDict(), merge: true)
    }

    func setBuses(_ buses: [BusModel], completion: (() -> Void)? = nil) {
        let batch = db.batch()
        for bus in buses {
            batch.setData(bus.toFirestoreDict(), forDocument: busesRef.document(bus.id))
        }
        batch.commit { _ in completion?() }
    }

    // MARK: - Charger Operations

    func listenToChargers(completion: @escaping ([ChargerModel]) -> Void) -> ListenerRegistration {
        return chargersRef.addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            let chargers = docs.compactMap { ChargerModel(from: $0.data()) }
            completion(chargers)
        }
    }

    func setChargers(_ chargers: [ChargerModel], completion: (() -> Void)? = nil) {
        let batch = db.batch()
        for c in chargers {
            batch.setData(c.toFirestoreDict(), forDocument: chargersRef.document(c.id))
        }
        batch.commit { _ in completion?() }
    }

    // MARK: - Alert Operations

    func listenToAlerts(completion: @escaping ([AlertModel]) -> Void) -> ListenerRegistration {
        return alertsRef
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let alerts = docs.compactMap { AlertModel(from: $0.data()) }
                completion(alerts)
            }
    }

    func addAlert(_ alert: AlertModel) {
        alertsRef.document(alert.id).setData(alert.toFirestoreDict())
    }

    func resolveAlert(id: String) {
        alertsRef.document(id).updateData(["resolved": true])
    }

    // MARK: - User Operations

    func saveUser(_ user: UserModel, completion: ((Error?) -> Void)? = nil) {
        usersRef.document(user.id).setData(user.toFirestoreDict()) { err in
            completion?(err)
        }
    }

    func fetchUser(uid: String, completion: @escaping (UserModel?) -> Void) {
        usersRef.document(uid).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { completion(nil); return }
            completion(UserModel(from: data))
        }
    }

    // MARK: - Seeding Check

    func isBusesCollectionEmpty(completion: @escaping (Bool) -> Void) {
        busesRef.limit(to: 1).getDocuments { snap, _ in
            completion(snap?.documents.isEmpty ?? true)
        }
    }
}
