#if os(iOS)
import SwiftUI
import MapKit

struct WeatherMapRaster {
    static func image(forecast: WeatherMapForecast, layer: WeatherMapLayer, hour: Int) -> CGImage? {
        let side = 224
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for row in 0..<side {
            if Task.isCancelled { return nil }
            for column in 0..<side {
                let x = Double(column) / Double(side - 1), y = Double(row) / Double(side - 1)
                guard let value = forecast.value(layer: layer, hour: hour, x: x, y: y) else { continue }
                let (red, green, blue, alpha) = layer.rgba(value)
                // Soften the sampled area's edge without suggesting coverage outside it.
                let edge = min(1, min(x, 1 - x, y, 1 - y) * 28)
                let a = alpha * edge
                let index = (row * side + column) * 4
                bytes[index] = UInt8(red * a * 255)
                bytes[index + 1] = UInt8(green * a * 255)
                bytes[index + 2] = UInt8(blue * a * 255)
                bytes[index + 3] = UInt8(a * 255)
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
    var onRegion: (MKCoordinateRegion) -> Void
    var onSelect: (CLLocationCoordinate2D) -> Void

    private var cityRegion: MKCoordinateRegion {
        // Let MapKit expand longitude to the actual portrait aspect ratio.
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                           span: MKCoordinateSpan(latitudeDelta: 7.6, longitudeDelta: 0.1))
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
        map.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 76)
        map.initialRegion = cityRegion
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        context.coordinator.map = map
        map.addAnnotation(context.coordinator.pin)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
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
        if let view = map.view(for: coordinator.pin) as? ForecastPinView { view.configure(text: pinText, symbol: layer.symbol) }
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
            view.configure(text: parent.pinText, symbol: parent.layer.symbol)
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
    private let valueLabel = UILabel()
    private let icon = UIImageView()
    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 66, height: 74)
        centerOffset = CGPoint(x: 0, y: -35)
        let tip = UIView(frame: CGRect(x: 26, y: 56, width: 14, height: 14))
        tip.backgroundColor = UIColor(WeatherPalette.ink); tip.transform = CGAffineTransform(rotationAngle: .pi / 4); addSubview(tip)
        let disc = UIView(frame: CGRect(x: 1, y: 0, width: 64, height: 64))
        disc.backgroundColor = UIColor(WeatherPalette.ink); disc.layer.cornerRadius = 32
        disc.layer.borderColor = UIColor.white.cgColor; disc.layer.borderWidth = 3
        disc.layer.shadowColor = UIColor.black.cgColor; disc.layer.shadowOpacity = 0.16; disc.layer.shadowRadius = 8; disc.layer.shadowOffset = CGSize(width: 0, height: 3)
        addSubview(disc)
        icon.frame = CGRect(x: 23, y: 10, width: 20, height: 17); icon.contentMode = .scaleAspectFit; icon.tintColor = UIColor(WeatherPalette.lime); addSubview(icon)
        valueLabel.frame = CGRect(x: 3, y: 28, width: 60, height: 25); valueLabel.font = .systemFont(ofSize: 18, weight: .semibold); valueLabel.adjustsFontSizeToFitWidth = true; valueLabel.minimumScaleFactor = 0.6; valueLabel.textAlignment = .center; valueLabel.textColor = .white; addSubview(valueLabel)
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(text: String, symbol: String) { valueLabel.text = text; icon.image = UIImage(systemName: symbol); accessibilityLabel = "所选位置，\(text)" }
}
#endif
