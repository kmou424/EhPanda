//
//  LogsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct LogsState: Equatable {
    enum Route: Equatable {
        case log(Log)
    }

    @BindableState var route: Route?
    var logs = [Log]()
}

enum LogsAction: BindableAction {
    case binding(BindingAction<LogsState>)
    case setNavigation(LogsState.Route?)
    case navigateToFileApp

    case fetchLogs
    case fetchLogsDone(Result<[Log], AppError>)
    case deleteLog(String)
    case deleteLogDone(Result<String, AppError>)
}

struct LogsEnvironment {
    let fileClient: FileClient
    let uiApplicationClient: UIApplicationClient
}

let logsReducer = Reducer<LogsState, LogsAction, LogsEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .navigateToFileApp:
        return environment.uiApplicationClient.openFileApp().fireAndForget()

    case .fetchLogs:
        return environment.fileClient.fetchLogs().map(LogsAction.fetchLogsDone)

    case .fetchLogsDone(let result):
        if case .success(let logs) = result {
            state.logs = logs
        }
        return .none

    case .deleteLog(let fileName):
        return environment.fileClient.deleteLog(fileName).map(LogsAction.deleteLogDone)

    case .deleteLogDone(let result):
        if case .success(let fileName) = result {
            state.logs = state.logs.filter({ $0.fileName != fileName })
        }
        return .none
    }
}
.binding()
