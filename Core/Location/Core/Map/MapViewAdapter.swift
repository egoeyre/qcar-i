import SwiftUI
import MapKit
import CoreLocation

struct MapViewAdapter: View {
    @Binding var region: MKCoordinateRegion
    var annotations: [MapAnnotationItem] = []

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: annotations) { item in
            MapMarker(coordinate: item.coordinate)
        }
        .ignoresSafeArea(edges: .top)
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
