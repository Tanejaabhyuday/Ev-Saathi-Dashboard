import Foundation
import FirebaseAuth

// MARK: - SeedService
// Seeds demo data (buses, chargers) into Firestore and creates 3 demo admin accounts
// in Firebase Authentication. Call seed() once on first launch.

final class SeedService {

    static let shared = SeedService()
    private init() {}

    // MARK: - Demo Admin Credentials (shown on Login screen)

    static let demoAdmins: [(name: String, email: String, password: String, role: AdminRole)] = [
        ("Abhyuday Taneja",  "admin1@evosaathi.com", "Admin@1234", .superadmin),
        ("Priya Mehta",      "admin2@evosaathi.com", "Admin@1234", .admin),
        ("Ravi Shankar",     "admin3@evosaathi.com", "Admin@1234", .admin)
    ]

    // MARK: - Driver names (same as web app)

    private let driverNames = [
        "Rajesh Kumar", "Vikram Singh", "Amit Verma", "Suresh Yadav",
        "Dinesh Karthik", "Manoj Tiwari", "Rakesh Sharma", "Sunil Patel"
    ]

    // MARK: - Seed Entry Point

    /// Signs in (or creates) admin1 first so Firestore writes are authenticated,
    /// then seeds buses/chargers, then creates remaining admin accounts.
    func seedIfNeeded(completion: @escaping (String) -> Void) {
        FirestoreService.shared.isBusesCollectionEmpty { [weak self] isEmpty in
            guard let self = self else { return }
            if isEmpty {
                completion("Seeding demo data...")
                // Must be authenticated before writing to Firestore
                self.ensureAuthenticated { [weak self] in
                    guard let self = self else { return }
                    self.seedBusesAndChargers {
                        self.createDemoAdmins { result in
                            completion(result)
                        }
                    }
                }
            } else {
                completion("Data already seeded.")
            }
        }
    }

    /// Signs in as admin1 if not already authenticated.
    /// Falls back to creating the account (which auto signs-in) on first run.
    private func ensureAuthenticated(completion: @escaping () -> Void) {
        if Auth.auth().currentUser != nil {
            completion(); return
        }
        let first = SeedService.demoAdmins[0]
        Auth.auth().signIn(withEmail: first.email, password: first.password) { result, _ in
            if result?.user != nil {
                completion()
            } else {
                // First-ever run — createUser auto signs-in
                Auth.auth().createUser(withEmail: first.email, password: first.password) { _, _ in
                    completion()
                }
            }
        }
    }

    // MARK: - Private Seeding

    private func seedBusesAndChargers(completion: @escaping () -> Void) {
        let routes = RouteModel.allRoutes
        let busCount = 8
        var buses: [BusModel] = []

        for i in 0..<busCount {
            let route = routes[i % routes.count]
            let isCharging = (i == 2 || i == 4)
            let startPoint = route.points[0]

            let bus = BusModel(
                id: "DL-1PC-\(2000 + i)",
                routeId: route.id,
                status: isCharging ? .charging : .moving,
                latitude: startPoint.lat,
                longitude: startPoint.lng,
                soc: isCharging ? 25 : (50 + Double.random(in: 0...40)),
                temp: Double.random(in: 32...40),
                speed: isCharging ? 0 : Double.random(in: 20...50),
                driverName: driverNames[i % driverNames.count],
                distanceTraveled: Int.random(in: 10000...60000),
                soh: Int.random(in: 90...100),
                lastMaintenance: "2024-\(String(format: "%02d", (i % 3) + 10))-\(String(format: "%02d", 10 + i))",
                pathIndex: i * 150,
                targetIndex: 1 + (i % max(1, route.points.count - 1))
            )
            buses.append(bus)
        }

        let chargers: [ChargerModel] = [
            ChargerModel(id: "CH-1", name: "Nehru Place Hub",  locationName: "South Delhi",
                         isOccupied: true,  currentVehicle: "DL-1PC-2002", power: 150),
            ChargerModel(id: "CH-2", name: "Cyber City Depot", locationName: "Gurugram",
                         isOccupied: true,  currentVehicle: "DL-1PC-2004", power: 150),
            ChargerModel(id: "CH-3", name: "Noida Sec 18",     locationName: "Noida",
                         isOccupied: false, currentVehicle: nil,            power: 150),
            ChargerModel(id: "CH-4", name: "Dwarka Sec 21",    locationName: "West Delhi",
                         isOccupied: false, currentVehicle: nil,            power: 150)
        ]

        FirestoreService.shared.setBuses(buses) {
            FirestoreService.shared.setChargers(chargers) {
                completion()
            }
        }
    }

    private func createDemoAdmins(completion: @escaping (String) -> Void) {
        let group = DispatchGroup()
        var messages: [String] = []

        for admin in SeedService.demoAdmins {
            group.enter()
            // Try to create Firebase Auth account
            Auth.auth().createUser(withEmail: admin.email, password: admin.password) { result, error in
                if let uid = result?.user.uid {
                    let user = UserModel(id: uid, name: admin.name, email: admin.email, role: admin.role)
                    FirestoreService.shared.saveUser(user) { _ in
                        messages.append("✅ Created \(admin.name)")
                        group.leave()
                    }
                } else if let err = error as NSError?,
                          err.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    // Already exists — fetch UID and update Firestore profile
                    messages.append("ℹ️ \(admin.name) already exists")
                    group.leave()
                } else {
                    messages.append("⚠️ Could not create \(admin.name): \(error?.localizedDescription ?? "unknown")")
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(messages.joined(separator: "\n"))
        }
    }
}
