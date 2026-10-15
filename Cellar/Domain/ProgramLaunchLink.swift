import Foundation

struct ProgramLaunchLink: Equatable {
    static let scheme = "cellar"
    private static let launchHost = "launch"
    private static let bottleQueryName = "bottle"
    private static let programQueryName = "program"

    let bottleID: Bottle.ID
    let programID: BottleProgram.ID

    init(bottleID: Bottle.ID, programID: BottleProgram.ID) {
        self.bottleID = bottleID
        self.programID = programID
    }

    init?(url: URL) {
        guard
            url.scheme?.lowercased() == Self.scheme,
            url.host?.lowercased() == Self.launchHost,
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            let bottleID = Self.uuid(named: Self.bottleQueryName, in: queryItems),
            let programID = Self.uuid(named: Self.programQueryName, in: queryItems)
        else {
            return nil
        }
        self.init(bottleID: bottleID, programID: programID)
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.launchHost
        components.queryItems = [
            URLQueryItem(name: Self.bottleQueryName, value: bottleID.uuidString),
            URLQueryItem(name: Self.programQueryName, value: programID.uuidString)
        ]
        return components.url
    }

    private static func uuid(named queryName: String, in queryItems: [URLQueryItem]) -> UUID? {
        queryItems
            .first { $0.name == queryName }?
            .value
            .flatMap(UUID.init(uuidString:))
    }
}
