import SwiftUI

enum AppTab: Hashable {
    case passenger
    case driver
    case tracking
    case profile
}

struct MainTabView: View {
    let container: AppContainer
    @State private var selectedTab: AppTab = .passenger

    var body: some View {
        TabView(selection: $selectedTab) {
            PassengerHomeMapView(container: container, selectedTab: $selectedTab)
                .tabItem { Label("乘客", systemImage: "person") }
                .tag(AppTab.passenger)

            DriverHomeView(container: container)
                .tabItem { Label("司机", systemImage: "steeringwheel") }
                .tag(AppTab.driver)

            RideTrackingView(container: container)
                .tabItem { Label("行程", systemImage: "location") }
                .tag(AppTab.tracking)

            ProfileView(container: container)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}
