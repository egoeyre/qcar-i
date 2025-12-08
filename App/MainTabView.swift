import SwiftUI

enum AppTab: Hashable {
    case passenger
    case driver
    case tracking
    case profile
}

struct MainTabView: View {
    let container: AppContainer
    @EnvironmentObject private var session: SessionStore

    @State private var selectedTab: AppTab = .tracking

    var body: some View {
        TabView(selection: $selectedTab) {

            if session.role == .passenger {
                PassengerHomeMapView(container: container, selectedTab: $selectedTab)
                    .tabItem { Label("乘客", systemImage: "person") }
                    .tag(AppTab.passenger)
            }

            if session.role == .driver {
                DriverHomeView(container: container)
                    .tabItem { Label("司机", systemImage: "steeringwheel") }
                    .tag(AppTab.driver)
            }

            RideTrackingView(container: container)
                .tabItem { Label("行程", systemImage: "location") }
                .tag(AppTab.tracking)

            ProfileView(container: container)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .onAppear {
            // 默认落在当前角色的主入口
            if session.role == .passenger {
                selectedTab = .passenger
            } else {
                selectedTab = .driver
            }
        }
        .onChange(of: session.role) { newRole in
            // 角色切换后，避免选中一个已被隐藏的 tab
            selectedTab = (newRole == .passenger) ? .passenger : .driver
        }
    }
}
