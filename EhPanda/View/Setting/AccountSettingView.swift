//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

struct AccountSettingView: View {
    private let store: Store<AccountSettingState, AccountSettingAction>
    @ObservedObject private var viewStore: ViewStore<AccountSettingState, AccountSettingAction>
    @Binding private var galleryHost: GalleryHost
    @Binding private var showNewDawnGreeting: Bool
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    init(
        store: Store<AccountSettingState, AccountSettingAction>,
        galleryHost: Binding<GalleryHost>, showNewDawnGreeting: Binding<Bool>,
        bypassesSNIFiltering: Bool, blurRadius: Double
    ) {
        self.store = store
        viewStore = ViewStore(store)
        _galleryHost = galleryHost
        _showNewDawnGreeting = showNewDawnGreeting
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.blurRadius = blurRadius
    }

    // MARK: AccountSettingView
    var body: some View {
        Form {
            Section {
                Picker("Gallery", selection: $galleryHost) {
                    ForEach(GalleryHost.allCases) {
                        Text($0.rawValue.localized).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                AccountSection(
                    showNewDawnGreeting: $showNewDawnGreeting,
                    bypassesSNIFiltering: bypassesSNIFiltering,
                    loginAction: { viewStore.send(.setNavigation(.login)) },
                    logoutAction: { viewStore.send(.setNavigation(.logout)) },
                    configureAccountAction: { viewStore.send(.setNavigation(.ehSetting)) },
                    manageTagsAction: { viewStore.send(.setNavigation(.webView(Defaults.URL.myTags))) }
                )
            }
            CookieSection { (isPresented, config) in
                viewStore.send(.setHUDConfig(config))
                viewStore.send(.setNavigation(isPresented ? .hud : .none))
            }
            .id(viewStore.cookiesSectionIdentifier)
        }
        .progressHUD(
            config: viewStore.hudConfig,
            unwrapping: viewStore.binding(\.$route),
            case: /AccountSettingState.Route.hud
        )
        .confirmationDialog(
            message: "Are you sure to logout?",
            unwrapping: viewStore.binding(\.$route),
            case: /AccountSettingState.Route.logout
        ) {
            Button("Logout", role: .destructive) {
                viewStore.send(.onLogoutConfirmButtonTapped)
            }
        }
        .sheet(unwrapping: viewStore.binding(\.$route), case: /AccountSettingState.Route.webView) { route in
            WebView(url: route.wrappedValue)
                .blur(radius: blurRadius).allowsHitTesting(blurRadius < 1)
                .animation(.linear(duration: 0.1), value: blurRadius)
        }
        .background(navigationLinks)
        .navigationBarTitle("Account")
    }
}

// MARK: NavigationLinks
private extension AccountSettingView {
    @ViewBuilder var navigationLinks: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /AccountSettingState.Route.login) { _ in
            LoginView(
                store: store.scope(state: \.loginState, action: AccountSettingAction.login),
                bypassesSNIFiltering: bypassesSNIFiltering, blurRadius: blurRadius
            )
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /AccountSettingState.Route.ehSetting) { _ in
            EhSettingView(
                store: store.scope(state: \.ehSettingState, action: AccountSettingAction.ehSetting),
                bypassesSNIFiltering: bypassesSNIFiltering, blurRadius: blurRadius
            )
        }
    }
}

// MARK: AccountSection
private struct AccountSection: View {
    @Binding private var showNewDawnGreeting: Bool
    private let bypassesSNIFiltering: Bool
    private let loginAction: () -> Void
    private let logoutAction: () -> Void
    private let configureAccountAction: () -> Void
    private let manageTagsAction: () -> Void

    init(
        showNewDawnGreeting: Binding<Bool>, bypassesSNIFiltering: Bool,
        loginAction: @escaping () -> Void, logoutAction: @escaping () -> Void,
        configureAccountAction: @escaping () -> Void, manageTagsAction: @escaping () -> Void
    ) {
        _showNewDawnGreeting = showNewDawnGreeting
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.loginAction = loginAction
        self.logoutAction = logoutAction
        self.configureAccountAction = configureAccountAction
        self.manageTagsAction = manageTagsAction
    }

    var body: some View {
        if !CookiesUtil.didLogin {
            Button("Login", action: loginAction)
        } else {
            Button("Logout", role: .destructive, action: logoutAction)
            Group {
                Button("Account configuration", action: configureAccountAction).withArrow()
                if !bypassesSNIFiltering {
                    Button("Manage tags subscription", action: manageTagsAction).withArrow()
                }
                Toggle("Show new dawn greeting", isOn: $showNewDawnGreeting)
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: CookieSection
private struct CookieSection: View {
    private let ehURL = Defaults.URL.ehentai
    private let exURL = Defaults.URL.exhentai
    private let igneousKey = Defaults.Cookie.igneous
    private let memberIDKey = Defaults.Cookie.ipbMemberId
    private let passHashKey = Defaults.Cookie.ipbPassHash

    private let hudAction: (Bool, TTProgressHUDConfig) -> Void

    init(hudAction: @escaping (Bool, TTProgressHUDConfig) -> Void) {
        self.hudAction = hudAction
    }

    var body: some View {
        Section("E-Hentai") {
            CookieRow(key: memberIDKey, value: ehMemberID, submitAction: setEhCookieValue)
            CookieRow(key: passHashKey, value: ehPassHash, submitAction: setEhCookieValue)
            Button("Copy cookies", action: copyEhCookies).foregroundStyle(.tint).font(.subheadline)
        }
        Section("ExHentai") {
            CookieRow(key: igneousKey, value: igneous, submitAction: setExCookieValue)
            CookieRow(key: memberIDKey, value: exMemberID, submitAction: setExCookieValue)
            CookieRow(key: passHashKey, value: exPassHash, submitAction: setExCookieValue)
            Button("Copy cookies", action: copyExCookies).foregroundStyle(.tint).font(.subheadline)
        }
    }
}

private extension CookieSection {
    var igneous: CookieValue {
        CookiesUtil.get(for: exURL, key: igneousKey)
    }
    var ehMemberID: CookieValue {
        CookiesUtil.get(for: ehURL, key: memberIDKey)
    }
    var exMemberID: CookieValue {
        CookiesUtil.get(for: exURL, key: memberIDKey)
    }
    var ehPassHash: CookieValue {
        CookiesUtil.get(for: ehURL, key: passHashKey)
    }
    var exPassHash: CookieValue {
        CookiesUtil.get(for: exURL, key: passHashKey)
    }
    func setEhCookieValue(key: String, value: String) {
        setCookieValue(url: ehURL, key: key, value: value)
    }
    func setExCookieValue(key: String, value: String) {
        setCookieValue(url: exURL, key: key, value: value)
    }
    func setCookieValue(url: URL, key: String, value: String) {
        if CookiesUtil.checkExistence(for: url, key: key) {
            CookiesUtil.edit(for: url, key: key, value: value)
        } else {
            CookiesUtil.set(for: url, key: key, value: value)
        }
    }
    func copyEhCookies() {
        let cookies = "\(memberIDKey): \(ehMemberID.rawValue)"
            + "\n\(passHashKey): \(ehPassHash.rawValue)"
        PasteboardUtil.save(value: cookies)
        presentHUD()
    }
    func copyExCookies() {
        let cookies = "\(igneousKey): \(igneous.rawValue)"
            + "\n\(memberIDKey): \(exMemberID.rawValue)"
            + "\n\(passHashKey): \(exPassHash.rawValue)"
        PasteboardUtil.save(value: cookies)
        presentHUD()
    }
    func presentHUD() {
        let config = TTProgressHUDConfig(
            type: .success, title: "Success".localized,
            caption: "Copied to clipboard".localized,
            shouldAutoHide: true, autoHideInterval: 1
        )
        hudAction(true, config)
    }
}

// MARK: CookieRow
private struct CookieRow: View {
    @State private var content: String

    private let key: String
    private let value: String
    private let cookieValue: CookieValue
    private let submitAction: (String, String) -> Void
    private var notVerified: Bool {
        !cookieValue.localizedString.isEmpty && !cookieValue.rawValue.isEmpty
    }

    init(
        key: String, value: CookieValue,
        submitAction: @escaping (String, String) -> Void
    ) {
        _content = State(initialValue: value.rawValue)

        self.key = key
        self.value = value.localizedString.isEmpty
            ? value.rawValue : value.localizedString
        self.cookieValue = value
        self.submitAction = submitAction
    }

    var body: some View {
        HStack {
            Text(key)
            Spacer()
            ZStack {
                TextField(value, text: $content)
                    .submitLabel(.done)
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.none)
                    .onChange(of: content) {
                        submitAction(key, $0)
                    }
            }
            ZStack {
                Image(systemSymbol: .checkmarkCircle)
                    .foregroundStyle(.green).opacity(notVerified ? 0 : 1)
                Image(systemSymbol: .xmarkCircle)
                    .foregroundStyle(.red).opacity(notVerified ? 1 : 0)
            }
        }
    }
}

// MARK: Definition
struct CookieValue {
    let rawValue: String
    let localizedString: String
}

struct AccountSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountSettingView(
                store: .init(
                    initialState: .init(),
                    reducer: accountSettingReducer,
                    environment: AccountSettingEnvironment(
                        hapticClient: .live,
                        cookiesClient: .live,
                        uiApplicationClient: .live
                    )
                ),
                galleryHost: .constant(.ehentai),
                showNewDawnGreeting: .constant(false),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
