#if os(iOS)
import SwiftUI
import MapKit

struct WeatherMapRaster {
    static func image(forecast: WeatherMapForecast, layer: WeatherMapLayer, hour: Int) -> CGImage? {
        let side = 320
        var values = [Double?](repeating: nil, count: side * side)
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        func edgeOpacity(_ x: Double, _ y: Double) -> Double {
            let edge = min(1, min(x, 1 - x, y, 1 - y) * (layer == .precipitation ? 28 : 10))
            return layer == .precipitation ? edge : edge * edge * (3 - 2 * edge)
        }
        for row in 0..<side {
            if Task.isCancelled { return nil }
            for column in 0..<side {
                let x = Double(column) / Double(side - 1), y = Double(row) / Double(side - 1)
                guard let value = forecast.value(layer: layer, hour: hour, x: x, y: y) else { continue }
                values[row * side + column] = value
                let (red, green, blue, alpha) = layer.rgba(value)
                // Soften the sampled area's edge without suggesting coverage outside it.
                let edge = edgeOpacity(x, y)
                let a = alpha * edge
                let index = (row * side + column) * 4
                bytes[index] = UInt8(red * a * 255)
                bytes[index + 1] = UInt8(green * a * 255)
                bytes[index + 2] = UInt8(blue * a * 255)
                bytes[index + 3] = UInt8(a * 255)
            }
        }
        // Trace only actual value crossings. Flat fields and missing cells stay unmarked.
        if let interval = layer.contourInterval {
            for row in 0..<(side - 1) {
                if Task.isCancelled { return nil }
                for column in 0..<(side - 1) {
                    let cell = row * side + column
                    guard let value = values[cell], let right = values[cell + 1], let below = values[cell + side] else { continue }
                    let band = floor(value / interval)
                    guard band != floor(right / interval) || band != floor(below / interval) else { continue }
                    let x = Double(column) / Double(side - 1), y = Double(row) / Double(side - 1)
                    let edge = edgeOpacity(x, y)
                    let highlight = 0.48 * edge
                    let pixel = cell * 4
                    for channel in 0..<3 {
                        bytes[pixel + channel] = UInt8(min(255, Double(bytes[pixel + channel]) * (1 - highlight) + 255 * highlight))
                    }
                    bytes[pixel + 3] = UInt8(min(255, Double(bytes[pixel + 3]) * (1 - highlight) + 255 * highlight))
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

private final class ForecastMapOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let image: CGImage
    init(area: WeatherMapArea, image: CGImage) {
        self.image = image
        let north = MKMapPoint(CLLocationCoordinate2D(latitude: area.north, longitude: area.west))
        let south = MKMapPoint(CLLocationCoordinate2D(latitude: area.south, longitude: area.west))
        boundingMapRect = MKMapRect(x: north.x, y: north.y, width: (area.east - area.west) / 360 * MKMapSize.world.width, height: south.y - north.y)
        coordinate = CLLocationCoordinate2D(latitude: (area.north + area.south) / 2, longitude: WeatherMapArea.longitude((area.west + area.east) / 2))
        super.init()
    }
}

private final class ForecastMapRenderer: MKOverlayRenderer {
    let image: CGImage
    init(overlay: ForecastMapOverlay) { image = overlay.image; super.init(overlay: overlay) }
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let target = rect(for: overlay.boundingMapRect)
        context.saveGState()
        context.clip(to: rect(for: mapRect))
        context.interpolationQuality = .high
        context.translateBy(x: target.minX, y: target.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: target.size))
        context.restoreGState()
    }
}

struct WeatherMapCanvas: UIViewRepresentable {
    var place: WeatherPlace
    var selected: CLLocationCoordinate2D
    var pinText: String
    var layer: WeatherMapLayer
    var recenter: Int
    var satellite: Bool
    var raster: CGImage?
    var rasterID: UUID
    var area: WeatherMapArea
    var bottomInset: CGFloat
    var onRegion: (MKCoordinateRegion) -> Void
    var onSelect: (CLLocationCoordinate2D) -> Void

    private var cityRegion: MKCoordinateRegion {
        // Frame the local forecast prominently, while MapKit accounts for the floating controls.
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                           span: MKCoordinateSpan(latitudeDelta: 4.4, longitudeDelta: 0.1))
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = ForecastMapView()
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .light
        map.showsCompass = false
        map.showsScale = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .excludingAll
        map.register(ForecastPinView.self, forAnnotationViewWithReuseIdentifier: "forecast")
        // Leave room for the city readout, the raised annotation and the floating right toolbar.
        map.layoutMargins = UIEdgeInsets(top: 144, left: 16, bottom: bottomInset, right: 84)
        map.initialRegion = cityRegion
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        context.coordinator.map = map
        map.addAnnotation(context.coordinator.pin)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let margins = UIEdgeInsets(top: 144, left: 16, bottom: bottomInset, right: 84)
        if map.layoutMargins != margins { map.layoutMargins = margins }
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.satellite != satellite {
            coordinator.satellite = satellite
            if satellite { map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .flat) }
            else { let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted); configuration.pointOfInterestFilter = .excludingAll; map.preferredConfiguration = configuration }
        }
        if coordinator.recenter != recenter {
            coordinator.recenter = recenter
            map.setRegion(cityRegion, animated: true)
        }
        if coordinator.pin.coordinate.latitude != selected.latitude || coordinator.pin.coordinate.longitude != selected.longitude { coordinator.pin.coordinate = selected }
        if let view = map.view(for: coordinator.pin) as? ForecastPinView { view.configure(text: pinText, layer: layer) }
        if coordinator.rasterID != rasterID {
            coordinator.rasterID = rasterID
            map.removeOverlays(map.overlays)
            if let raster { map.addOverlay(ForecastMapOverlay(area: area, image: raster), level: .aboveRoads) }
        }
    }
    static func dismantleUIView(_ view: MKMapView, coordinator: Coordinator) { view.delegate = nil }

    @MainActor final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: WeatherMapCanvas
        weak var map: MKMapView?
        let pin = MKPointAnnotation()
        var recenter = 0
        var satellite: Bool?
        var rasterID: UUID?
        init(_ parent: WeatherMapCanvas) { self.parent = parent; super.init(); pin.coordinate = parent.selected }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let map, gesture.state == .ended else { return }
            parent.onSelect(map.convert(gesture.location(in: map), toCoordinateFrom: map))
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view { if current is MKAnnotationView || current is UIControl { return false }; view = current.superview }
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            DispatchQueue.main.async { [weak self] in self?.parent.onRegion(region) }
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let forecast = overlay as? ForecastMapOverlay { return ForecastMapRenderer(overlay: forecast) }
            return MKOverlayRenderer(overlay: overlay)
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            guard annotation === pin else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "forecast", for: annotation) as! ForecastPinView
            view.configure(text: parent.pinText, layer: parent.layer)
            return view
        }
    }
}

private final class ForecastMapView: MKMapView {
    var initialRegion: MKCoordinateRegion?
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, let region = initialRegion else { return }
        initialRegion = nil
        setRegion(region, animated: false)
    }
}

private final class ForecastPinView: MKAnnotationView {
    private let icon = UIImageView()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private let disc = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let tip = UIView()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 106, height: 58)
        centerOffset = CGPoint(x: 0, y: -28)
        tip.frame = CGRect(x: 48, y: 43, width: 10, height: 10)
        tip.transform = CGAffineTransform(rotationAngle: .pi / 4)
        addSubview(tip)
        disc.frame = CGRect(x: 0, y: 0, width: 106, height: 48)
        disc.layer.cornerRadius = 16
        disc.clipsToBounds = true
        disc.layer.borderWidth = 1
        disc.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        addSubview(disc)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.13
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)
        icon.frame = CGRect(x: 10, y: 14, width: 18, height: 20)
        icon.contentMode = .scaleAspectFit
        addSubview(icon)
        valueLabel.frame = CGRect(x: 35, y: 4, width: 65, height: 26)
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.65
        addSubview(valueLabel)
        unitLabel.frame = CGRect(x: 36, y: 29, width: 66, height: 13)
        unitLabel.font = .systemFont(ofSize: 10, weight: .medium)
        unitLabel.textColor = UIColor(WeatherPalette.secondary)
        addSubview(unitLabel)
        isAccessibilityElement = true
        displayPriority = .required
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(text: String, layer: WeatherMapLayer) {
        let accent = UIColor(Color(hex: layer.accent))
        valueLabel.text = text.replacingOccurrences(of: "°", with: "")
        valueLabel.textColor = accent
        unitLabel.text = layer.unit
        icon.image = UIImage(systemName: layer.symbol)
        icon.tintColor = accent
        disc.contentView.backgroundColor = accent.withAlphaComponent(0.07)
        tip.backgroundColor = .white.withAlphaComponent(0.92)
        accessibilityLabel = "所选位置，\(layer.title)，\(text) \(layer.unit)"
    }
}
#endif
