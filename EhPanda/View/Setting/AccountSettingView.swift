//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import ComposableArchitecture

struct AccountSettingView: View {
    private let store: Store<AccountSettingState, AccountSettingAction>
    @ObservedObject private var viewStore: ViewStore<AccountSettingState, AccountSettingAction>
    @Binding private var galleryHost: GalleryHost
    @Binding private var showsNewDawnGreeting: Bool
    private let bypassesSNIFiltering: Bool
    private let blurRadius: Double

    init(
        store: Store<AccountSettingState, AccountSettingAction>,
        galleryHost: Binding<GalleryHost>, showsNewDawnGreeting: Binding<Bool>,
        bypassesSNIFiltering: Bool, blurRadius: Double
    ) {
        self.store = store
        viewStore = ViewStore(store)
        _galleryHost = galleryHost
        _showsNewDawnGreeting = showsNewDawnGreeting
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.blurRadius = blurRadius
    }

    // MARK: AccountSettingView
    var body: some View {
        Form {
            Section {
                Picker("", selection: $galleryHost) {
                    ForEach(GalleryHost.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                AccountSection(
                    route: viewStore.binding(\.$route),
                    showsNewDawnGreeting: $showsNewDawnGreeting,
                    bypassesSNIFiltering: bypassesSNIFiltering,
                    loginAction: { viewStore.send(.setNavigation(.login)) },
                    logoutAction: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            viewStore.send(.onLogoutConfirmButtonTapped)
                        }
                    },
                    logoutDialogAction: { viewStore.send(.setNavigation(.logout)) },
                    configureAccountAction: { viewStore.send(.setNavigation(.ehSetting)) },
                    manageTagsAction: { viewStore.send(.setNavigation(.webView(Defaults.URL.myTags))) }
                )
            }
            CookieSection(
                ehCookiesState: viewStore.binding(\.$ehCookiesState),
                exCookiesState: viewStore.binding(\.$exCookiesState),
                copyAction: { viewStore.send(.copyCookies($0)) }
            )
        }
        .progressHUD(
            config: viewStore.hudConfig,
            unwrapping: viewStore.binding(\.$route),
            case: /AccountSettingState.Route.hud
        )
        .sheet(unwrapping: viewStore.binding(\.$route), case: /AccountSettingState.Route.webView) { route in
            WebView(url: route.wrappedValue)
                .autoBlur(radius: blurRadius)
        }
        .onAppear { viewStore.send(.loadCookies) }
        .background(navigationLinks)
        .navigationTitle(R.string.localizable.accountSettingViewTitleAccount())
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
    @Binding private var route: AccountSettingState.Route?
    @Binding private var showsNewDawnGreeting: Bool
    private let bypassesSNIFiltering: Bool
    private let loginAction: () -> Void
    private let logoutAction: () -> Void
    private let logoutDialogAction: () -> Void
    private let configureAccountAction: () -> Void
    private let manageTagsAction: () -> Void

    init(
        route: Binding<AccountSettingState.Route?>,
        showsNewDawnGreeting: Binding<Bool>, bypassesSNIFiltering: Bool,
        loginAction: @escaping () -> Void, logoutAction: @escaping () -> Void,
        logoutDialogAction: @escaping () -> Void,
        configureAccountAction: @escaping () -> Void,
        manageTagsAction: @escaping () -> Void
    ) {
        _route = route
        _showsNewDawnGreeting = showsNewDawnGreeting
        self.bypassesSNIFiltering = bypassesSNIFiltering
        self.loginAction = loginAction
        self.logoutAction = logoutAction
        self.logoutDialogAction = logoutDialogAction
        self.configureAccountAction = configureAccountAction
        self.manageTagsAction = manageTagsAction
    }

    var body: some View {
        if !CookiesUtil.didLogin {
            Button(R.string.localizable.accountSettingViewButtonLogin(), action: loginAction)
        } else {
            Button(
                R.string.localizable.confirmationDialogButtonLogout(),
                role: .destructive, action: logoutDialogAction
            )
            .confirmationDialog(
                message: R.string.localizable.confirmationDialogTitleLogout(),
                unwrapping: $route, case: /AccountSettingState.Route.logout
            ) {
                Button(
                    R.string.localizable.confirmationDialogButtonLogout(),
                    role: .destructive, action: logoutAction
                )
            }
            Group {
                Button(
                    R.string.localizable.accountSettingViewButtonAccountConfiguration(),
                    action: configureAccountAction
                )
                .withArrow()
                if !bypassesSNIFiltering {
                    Button(
                        R.string.localizable.accountSettingViewButtonTagsManagement(),
                        action: manageTagsAction
                    )
                    .withArrow()
                }
                Toggle(R.string.localizable.accountSettingViewTitleShowsNewDawnGreeting(), isOn: $showsNewDawnGreeting)
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: CookieSection
private struct CookieSection: View {
    @Binding private var ehCookiesState: CookiesState
    @Binding private var exCookiesState: CookiesState
    private let copyAction: (GalleryHost) -> Void

    init(
        ehCookiesState: Binding<CookiesState>,
        exCookiesState: Binding<CookiesState>,
        copyAction: @escaping (GalleryHost) -> Void
    ) {
        _ehCookiesState = ehCookiesState
        _exCookiesState = exCookiesState
        self.copyAction = copyAction
    }

    var body: some View {
        Section(GalleryHost.ehentai.rawValue) {
            CookieRow(cookieState: $ehCookiesState.memberID)
            CookieRow(cookieState: $ehCookiesState.passHash)
            Button(R.string.localizable.accountSettingViewButtonCopyCookies()) {
                copyAction(.ehentai)
            }
            .foregroundStyle(.tint).font(.subheadline)
        }
        Section(GalleryHost.exhentai.rawValue) {
            CookieRow(cookieState: $exCookiesState.igneous)
            CookieRow(cookieState: $exCookiesState.memberID)
            CookieRow(cookieState: $exCookiesState.passHash)
            Button(R.string.localizable.accountSettingViewButtonCopyCookies()) {
                copyAction(.exhentai)
            }
            .foregroundStyle(.tint).font(.subheadline)
        }
    }
}

// MARK: CookieRow
private struct CookieRow: View {
    @Binding private var cookieState: CookieState

    init(cookieState: Binding<CookieState>) {
        _cookieState = cookieState
    }

    var body: some View {
        HStack {
            Text(cookieState.key)
            Spacer()
            TextField(cookieState.value.placeholder, text: $cookieState.editingText)
                .submitLabel(.done).disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.none)
            Image(systemSymbol: cookieState.value.isInvalid ? .xmarkCircle : .checkmarkCircle)
                .foregroundStyle(cookieState.value.isInvalid ? .red : .green)
        }
    }
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
                        clipboardClient: .live,
                        uiApplicationClient: .live
                    )
                ),
                galleryHost: .constant(.ehentai),
                showsNewDawnGreeting: .constant(false),
                bypassesSNIFiltering: false,
                blurRadius: 0
            )
        }
    }
}
