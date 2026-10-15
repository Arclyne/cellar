import Foundation

protocol BottleStoring {
    func loadBottles() throws -> [Bottle]
    func save(_ bottle: Bottle) throws
    func remove(_ bottle: Bottle) throws
}
