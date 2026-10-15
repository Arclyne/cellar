import Foundation

protocol DllOverrideApplying {
    func applyDllOverrides(_ loadOrdersByLibrary: [String: String], in bottle: Bottle) async throws
}

struct WineRegistryDllOverrideApplier: DllOverrideApplying {
    private static let dllOverridesRegistryKey = #"HKEY_CURRENT_USER\Software\Wine\DllOverrides"#

    let invocationFactory: WineInvocationFactory
    let executor: CheckedCommandExecutor

    func applyDllOverrides(_ loadOrdersByLibrary: [String: String], in bottle: Bottle) async throws {
        for (libraryName, loadOrder) in loadOrdersByLibrary.sorted(by: { $0.key < $1.key }) {
            let registryUpdate = try invocationFactory.wineInvocation(
                arguments: [
                    "reg", "add", Self.dllOverridesRegistryKey,
                    "/v", libraryName,
                    "/t", "REG_SZ",
                    "/d", loadOrder,
                    "/f"
                ],
                displayName: "Library override \(libraryName)",
                for: bottle
            )
            try await executor.execute(registryUpdate)
        }
    }
}
