import UIKit
import MapKit

// MARK: - BusAnnotationView
// Custom MKAnnotationView that renders a bus icon with status color.
// Used in both FleetMapView and SingleBusMapView.

final class BusAnnotationView: MKAnnotationView {

    static let reuseID = "BusAnnotationView"

    // MARK: - Subviews

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 18
        v.layer.shadowColor   = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.25
        v.layer.shadowRadius  = 6
        v.layer.shadowOffset  = CGSize(width: 0, height: 3)
        return v
    }()

    private let labelView: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 9, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        return l
    }()

    // MARK: - Init

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        frame = CGRect(x: 0, y: 0, width: 44, height: 52)
        centerOffset = CGPoint(x: 0, y: -26)
        canShowCallout = false

        containerView.frame = CGRect(x: 2, y: 2, width: 40, height: 40)
        addSubview(containerView)

        iconImageView.frame = CGRect(x: 8, y: 8, width: 24, height: 24)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        iconImageView.image = UIImage(systemName: "bus.fill", withConfiguration: config)
        containerView.addSubview(iconImageView)

        labelView.frame = CGRect(x: 0, y: 43, width: 44, height: 10)
        addSubview(labelView)
    }

    // MARK: - Configure

    func configure(with bus: BusModel) {
        let color: UIColor
        switch bus.status {
        case .moving:   color = UIColor(red: 0.23, green: 0.51, blue: 0.97, alpha: 1) // blue
        case .charging: color = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1) // green
        case .alert:    color = UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1) // red
        case .idle:     color = UIColor(red: 0.40, green: 0.45, blue: 0.55, alpha: 1) // slate
        }
        containerView.backgroundColor = color
        labelView.text = String(bus.id.suffix(4)) // e.g. "2003"
    }
}
