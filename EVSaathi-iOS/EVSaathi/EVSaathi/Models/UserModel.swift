import Foundation

// MARK: - AdminRole

enum AdminRole: String, Codable, CaseIterable {
    case superadmin = "superadmin"
    case admin      = "admin"

    var displayName: String {
        switch self {
        case .superadmin: return "Super Admin"
        case .admin:      return "Fleet Manager"
        }
    }
}

// MARK: - UserModel

struct UserModel: Identifiable, Codable, Hashable {
    var id: String          // Firebase Auth UID
    var name: String
    var email: String
    var role: AdminRole
    var createdAt: Date

    /// Two-letter initials for avatar placeholder
    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last  = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    func toFirestoreDict() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "email": email,
            "role": role.rawValue,
            "createdAt": createdAt
        ]
    }

    init?(from dict: [String: Any]) {
        guard
            let id = dict["id"] as? String,
            let name = dict["name"] as? String,
            let email = dict["email"] as? String,
            let roleRaw = dict["role"] as? String,
            let role = AdminRole(rawValue: roleRaw)
        else { return nil }

        self.id = id; self.name = name; self.email = email; self.role = role
        self.createdAt = dict["createdAt"] as? Date ?? Date()
    }

    init(id: String, name: String, email: String, role: AdminRole, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.email = email
        self.role = role; self.createdAt = createdAt
    }
}
