//
//  ArchiveView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/02/06.
//

import SwiftUI
import TTProgressHUD

struct ArchiveView: View {
    @EnvironmentObject var store: Store
    @State var selection: ArchiveRes? = nil
    
    @State var hudVisible = false
    @State var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )
    var loadingHUDConfig = TTProgressHUDConfig(
        type: .Loading,
        title: "サーバーと通信中",
        hapticsEnabled: false
    )
    
    let id: String
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var user: User? {
        store.appState.settings.user
    }
    var mangaDetail: MangaDetail? {
        cachedList.items?[id]?.detail
    }
    var archive: MangaArchive? {
        mangaDetail?.archive
    }
    var currentGP: String? {
        user?.currentGP
    }
    var currentCredits: String? {
        user?.currentCredits
    }
    var hathArchives: [MangaArchive.HathArchive] {
        archive?.hathArchives ?? []
    }
    let gridItems = [
        GridItem(.adaptive(minimum: 150, maximum: 200))
    ]
    
    // MARK: ArchiveView本体
    var body: some View {
        NavigationView {
            Group {
                if !hathArchives.isEmpty {
                    ZStack {
                        VStack {
                            LazyVGrid(columns: gridItems, spacing: 10) {
                                ForEach(hathArchives) { hathArchive in
                                    ArchiveGrid(
                                        selected: selection
                                            == hathArchive.resolution,
                                        archive: hathArchive
                                    )
                                    .onTapGesture(perform: {
                                        onArchiveGridTap(hathArchive)
                                    })
                                }
                            }
                            .padding(.top, 40)
                            
                            Spacer()
                            
                            if isSameAccount,
                               let gp = currentGP,
                               let credits = currentCredits
                            {
                                BalanceView(gp: gp, credits: credits)
                            }
                            DownloadButton(
                                isDisabled: selection == nil,
                                action: onDownloadButtonTap
                            )
                        }
                        .padding(.horizontal)
                        TTProgressHUD(
                            detailInfoBinding.downloadCommandSending,
                            config: loadingHUDConfig
                        )
                        TTProgressHUD($hudVisible, config: hudConfig)
                    }
                } else if detailInfo.mangaArchiveLoading {
                    LoadingView()
                } else {
                    NetworkErrorView(retryAction: fetchMangaArchive)
                }
            }
            .navigationBarTitle("アーカイブ")
            .onAppear(perform: onAppear)
            .onChange(
                of: detailInfo.downloadCommandSending,
                perform: onRespChange
            )
            .onChange(
                of: hudVisible,
                perform: onHUDVisibilityChange
            )
        }
    }
    
    func onAppear() {
        fetchMangaArchive()
    }
    func onArchiveGridTap(_ item: MangaArchive.HathArchive) {
        if item.fileSize != "N/A"
            && item.gpPrice != "N/A"
        {
            selection = item.resolution
        }
    }
    func onDownloadButtonTap() {
        if let res = selection?.param {
            store.dispatch(.sendDownloadCommand(id: id, resolution: res))
            impactFeedback(style: .soft)
        }
    }
    func onRespChange<E: Equatable>(_ value: E) {
        if let sending = value as? Bool,
           sending == false
        {
            var type: TTProgressHUDType = .Warning
            var title: String?
            var caption: String?
            
            if !detailInfo.downloadCommandFailed,
               let response = detailInfo.downloadCommandResponse
            {
                type = .Success
                title = "成功".lString()
                caption = processResponse(response).lString()
            } else if detailInfo.downloadCommandFailed {
                if let response = detailInfo.downloadCommandResponse {
                    type = .Error
                    title = "エラー".lString()
                    caption = response.lString()
                } else {
                    type = .Error
                    title = "エラー".lString()
                    caption = nil
                }
            }
            
            switch type {
            case .Success:
                notificFeedback(style: .success)
            case .Error:
                notificFeedback(style: .error)
            default:
                print(type)
            }
            
            hudConfig = TTProgressHUDConfig(
                type: type,
                title: title,
                caption: caption,
                shouldAutoHide: true,
                autoHideInterval: 2,
                hapticsEnabled: false
            )
            hudVisible.toggle()
        }
    }
    func onHUDVisibilityChange<E: Equatable>(_ value: E) {
        if let isVisible = value as? Bool,
           isVisible == false
        {
            store.dispatch(.resetDownloadCommandResponse)
        }
    }
    
    func processResponse(_ resp: String) -> String {
        if let rangeA = resp.range(of: "A "),
           let rangeB = resp.range(of: "resolution"),
           let rangeC = resp.range(of: "client"),
           let rangeD = resp.range(of: "Downloads")
        {
            let res = String(
                resp
                    .suffix(from: rangeA.upperBound)
                    .prefix(upTo: rangeB.lowerBound)
            )
            .capitalizingFirstLetter()
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            
            if ArchiveRes(rawValue: res) != nil {
                let clientName = String(
                    resp
                        .suffix(from: rangeC.upperBound)
                        .prefix(upTo: rangeD.lowerBound)
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                
                return res.lString() + " -> " + clientName
            } else {
                return resp
            }
        } else {
            return resp
        }
    }
    
    func fetchMangaArchive() {
        store.dispatch(.fetchMangaArchive(id: id))
        if currentGP == nil
            || currentCredits == nil
        {
            store.dispatch(.fetchMangaArchiveFunds(id: id))
        }
    }
}

// MARK: ArchiveGrid
private struct ArchiveGrid: View {
    var selected: Bool
    let archive: MangaArchive.HathArchive
    
    var disabled: Bool {
        archive.fileSize == "N/A"
            || archive.gpPrice == "N/A"
    }
    var disabledColor: Color {
        Color.gray.opacity(0.5)
    }
    var fileSizeColor: Color {
        if disabled {
            return disabledColor
        } else {
            return .gray
        }
    }
    var borderColor: Color {
        if disabled {
            return disabledColor
        } else {
            return selected
                ? .accentColor
                : .gray
        }
    }
    var environmentColor: Color? {
        disabled ? disabledColor : nil
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Text(archive.resolution.rawValue.lString())
                .fontWeight(.bold)
                .font(.title3)
            VStack {
                Text(archive.fileSize.lString())
                    .fontWeight(.medium)
                    .font(.caption)
                Text(archive.gpPrice.lString())
                    .foregroundColor(fileSizeColor)
                    .font(.caption2)
            }
            .lineLimit(1)
        }
        .foregroundColor(environmentColor)
        .frame(width: 150, height: 100)
        .contentShape(Rectangle())
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: BalanceView
private struct BalanceView: View {
    let gp: String
    let credits: String
    
    var body: some View {
        HStack(spacing: 15) {
            HStack(spacing: 3) {
                Image(systemName: "g.circle.fill")
                Text(gp)
            }
            HStack(spacing: 3) {
                Image(systemName: "c.circle.fill")
                Text(credits)
            }
        }
        .font(.headline)
        .padding()
    }
}

// MARK: DownloadButton
private struct DownloadButton: View {
    @State var isPressed = false
    
    var isDisabled: Bool
    var action: () -> ()
    
    var textColor: Color {
        if isDisabled {
            return Color.white.opacity(0.5)
        } else {
            return isPressed
                ? Color.white.opacity(0.5)
                : .white
        }
    }
    var backgroundColor: Color {
        if isDisabled {
            return Color.accentColor.opacity(0.5)
        } else {
            return isPressed
                ? Color.accentColor.opacity(0.5)
                : .accentColor
        }
    }
    var paddingInsets: EdgeInsets {
        isPad
            ? .init(
                top: 0,
                leading: 0,
                bottom: 30,
                trailing: 0
            )
            : .init(
                top: 0,
                leading: 10,
                bottom: 30,
                trailing: 10
            )
    }
    
    var body: some View {
        HStack {
            Spacer()
            Text("Hathクライアントにダウンロード")
                .fontWeight(.bold)
                .font(.headline)
                .foregroundColor(textColor)
            Spacer()
        }
        .frame(height: 50)
        .background(backgroundColor)
        .cornerRadius(30)
        .padding(paddingInsets)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: 50,
            pressing: onLongPressing,
            perform: {}
        )
    }
    
    func onTap() {
        if !isDisabled {
            action()
        }
    }
    func onLongPressing(_ isPressed: Bool) {
        self.isPressed = isPressed
    }
}
