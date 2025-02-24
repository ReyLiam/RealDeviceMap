//
//  Pokemon.swift
//  RealDeviceMapLib
//
//  Created by Florian Kostenzer on 18.09.18.
//
//  swiftlint:disable:next superfluous_disable_command
//  swiftlint:disable file_length type_body_length function_body_length cyclomatic_complexity force_cast

import Foundation
import PerfectLib
import PerfectMySQL
import POGOProtos
import Regex
import S2Geometry

public class Pokemon: JSONConvertibleObject, WebHookEvent, Equatable, CustomStringConvertible {

    public var description: String {
        return pokemonId.description
    }

    public static var defaultTimeUnseen: UInt32 = 1200
    public static var defaultTimeReseen: UInt32 = 600
    public static var dittoPokemonId: UInt16 = 132
    public static var weatherBoostMinLevel: UInt8 = 6
    public static var weatherBoostMinIvStat: UInt8 = 4
    public static var pvpEnabled: Bool = true
    public static var weatherIVClearingEnabled = true
    public static var cellPokemonEnabled = true
    public static var saveSpawnpointLastSeen = false

    public static var cache: MemoryCache<Pokemon>?
    public static var diskEncounterCache: MemoryCache<DiskEncounterOutProto>?

    class ParsingError: Error {}

    public override func getJSONValues() -> [String: Any] {
        return [
            "id": id,
            "pokemon_id": pokemonId,
            "lat": lat,
            "lon": lon,
            "spawn_id": spawnId?.toHexString() as Any,
            "expire_timestamp": expireTimestamp as Any,
            "expire_timestamp_verified": expireTimestampVerified,
            "first_seen_timestamp": firstSeenTimestamp ?? 1,
            "atk_iv": atkIv as Any,
            "def_iv": defIv as Any,
            "sta_iv": staIv as Any,
            "move_1": move1 as Any,
            "move_2": move2 as Any,
            "gender": gender as Any,
            "form": form as Any,
            "cp": cp as Any,
            "level": level as Any,
            "base_weight": baseWeight as Any,
            "base_height": baseHeight as Any,
            "weight": weight as Any,
            "size": size as Any,
            "weather": weather as Any,
            "shiny": shiny as Any,
            // "username": username as Any,
            "pokestop_id": pokestopId as Any,
            "costume": costume as Any,
            "updated": updated ?? 1,
            "capture_1": capture1 as Any,
            "capture_2": capture2 as Any,
            "capture_3": capture3 as Any,
            "display_pokemon_id": displayPokemonId as Any,
            "pvp": pvp as Any,
            "is_event": isEvent,
            "seen_type": seenType.rawValue as Any
        ]
    }

    func getWebhookValues(type: String) -> [String: Any] {
        let message: [String: Any] = [
            "spawnpoint_id": spawnId?.toHexString() ?? "None",
            "pokestop_id": pokestopId ?? "None",
            "encounter_id": id,
            "pokemon_id": pokemonId,
            "latitude": lat,
            "longitude": lon,
            "disappear_time": expireTimestamp ?? 0,
            "disappear_time_verified": expireTimestampVerified,
            "first_seen": firstSeenTimestamp ?? 1,
            "last_modified_time": updated ?? 1,
            "gender": gender as Any,
            "cp": cp as Any,
            "form": form as Any,
            "costume": costume as Any,
            "individual_attack": atkIv as Any,
            "individual_defense": defIv as Any,
            "individual_stamina": staIv as Any,
            "pokemon_level": level as Any,
            "move_1": move1 as Any,
            "move_2": move2 as Any,
            "weight": weight as Any,
            "height": size as Any,
            "weather": weather as Any,
            "capture_1": capture1 ?? 0,
            "capture_2": capture2 ?? 0,
            "capture_3": capture3 ?? 0,
            "shiny": shiny as Any,
            "username": username as Any,
            "display_pokemon_id": displayPokemonId as Any,
            "pvp": pvp as Any,
            "is_event": isEvent,
            "seen_type": seenType.rawValue as Any
        ]
        return [
            "type": "pokemon",
            "message": message
        ]
    }

    public var hashValue: Int {
        return id.hashValue
    }

    var id: String
    var pokemonId: UInt16
    var lat: Double
    var lon: Double
    var spawnId: UInt64?
    var expireTimestamp: UInt32?
    var atkIv: UInt8?
    var defIv: UInt8?
    var staIv: UInt8?
    var move1: UInt16?
    var move2: UInt16?
    var gender: UInt8?
    var form: UInt16?
    var costume: UInt8?
    var cp: UInt16?
    var level: UInt8?
    var weight: Double?
    var size: Double?
    var weather: UInt8?
    var shiny: Bool?
    var username: String?
    var pokestopId: String?
    var firstSeenTimestamp: UInt32?
    var updated: UInt32?
    var changed: UInt32?
    var cellId: UInt64?
    var expireTimestampVerified: Bool
    var capture1: Double?
    var capture2: Double?
    var capture3: Double?
    var isDitto: Bool = false
    var displayPokemonId: UInt16?
    var pvp: [String: Any]?
    var baseHeight: Double?
    var baseWeight: Double?
    var isEvent: Bool
    var seenType: SeenType

    var hasChanges = false
    var hasIvChanges = false

    enum SeenType: String {
        case encounter = "encounter", wild = "wild", nearbyStop = "nearby_stop", nearbyCell = "nearby_cell",
             lureWild = "lure_wild", lureEncounter = "lure_encounter",
             UNSET = "unset" // MARK: only unset short after migration, because it can be null, can be removed later
    }

    init(id: String, pokemonId: UInt16, lat: Double, lon: Double, spawnId: UInt64?, expireTimestamp: UInt32?,
         atkIv: UInt8?, defIv: UInt8?, staIv: UInt8?, move1: UInt16?, move2: UInt16?, gender: UInt8?, form: UInt16?,
         cp: UInt16?, level: UInt8?, weight: Double?, costume: UInt8?, size: Double?,
         capture1: Double?, capture2: Double?, capture3: Double?, displayPokemonId: UInt16?,
         weather: UInt8?, shiny: Bool?, username: String?, pokestopId: String?, firstSeenTimestamp: UInt32?,
         updated: UInt32?, changed: UInt32?, cellId: UInt64?, expireTimestampVerified: Bool,
         pvp: [String: Any]?, isEvent: Bool, seenType: SeenType) {
        self.id = id
        self.pokemonId = pokemonId
        self.lat = lat
        self.lon = lon
        self.spawnId = spawnId
        self.expireTimestamp = expireTimestamp
        self.atkIv = atkIv
        self.defIv = defIv
        self.staIv = staIv
        self.move1 = move1
        self.move2 = move2
        self.gender = gender
        self.form = form
        self.cp = cp
        self.level = level
        self.weight = weight
        self.costume = costume
        self.size = size
        self.weather = weather
        self.shiny = shiny
        self.username = username
        self.pokestopId = pokestopId
        self.updated = updated
        self.firstSeenTimestamp = firstSeenTimestamp
        self.changed = changed
        self.cellId = cellId
        self.expireTimestampVerified = expireTimestampVerified
        self.capture1 = capture1
        self.capture2 = capture2
        self.capture3 = capture3
        self.displayPokemonId = displayPokemonId
        self.pvp = pvp
        self.isEvent = isEvent
        self.seenType = seenType
        let stats = PVPStatsManager.global.getStats(
            pokemon: HoloPokemonId(rawValue: Int(self.pokemonId)) ?? .missingno,
            form: PokemonDisplayProto.Form.init(rawValue: Int(self.form ?? 0)) ?? .unset
        )
        self.baseHeight = stats?.baseHeight
        self.baseWeight = stats?.baseWeight
    }

    init(mysql: MySQL?=nil, wildPokemon: WildPokemonProto, cellId: UInt64,
         timestampMs: UInt64, username: String?, isEvent: Bool) {

        self.isEvent = isEvent
        id = wildPokemon.encounterID.description
        pokemonId = wildPokemon.pokemon.pokemonID.rawValue.toUInt16()
        lat = wildPokemon.latitude
        lon = wildPokemon.longitude
        let spawnId = UInt64(wildPokemon.spawnPointID, radix: 16)
        gender = wildPokemon.pokemon.pokemonDisplay.gender.rawValue.toUInt8()
        form = wildPokemon.pokemon.pokemonDisplay.form.rawValue.toUInt16()
        if wildPokemon.pokemon.hasPokemonDisplay {
            costume = wildPokemon.pokemon.pokemonDisplay.costume.rawValue.toUInt8()
            weather = wildPokemon.pokemon.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
            // The wildPokemon and nearbyPokemon GMOs don't contain actual shininess.
            // shiny = wildPokemon.pokemon.pokemonDisplay.shiny
        }
        self.username = username

        if wildPokemon.timeTillHiddenMs <= 90000 && wildPokemon.timeTillHiddenMs > 0 {
            expireTimestamp = UInt32((timestampMs + UInt64(wildPokemon.timeTillHiddenMs)) / 1000)
            expireTimestampVerified = true
            let date = Date(timeIntervalSince1970: Double(self.expireTimestamp!))
            let components = Calendar.current.dateComponents([.second, .minute], from: date)
            let secondOfHour = (components.second ?? 0) + (components.minute ?? 0) * 60
            let spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon,
                                       updated: updated, lastSeen: updated, despawnSecond: UInt16(secondOfHour))
            try? spawnPoint.save(mysql: mysql, update: true)
        } else {
            expireTimestampVerified = false
        }

        if !expireTimestampVerified && spawnId != nil {
            let spawnpoint: SpawnPoint?
            do {
                spawnpoint = try SpawnPoint.getWithId(mysql: mysql, id: spawnId!)
            } catch {
                spawnpoint = nil
            }
            if let spawnpoint = spawnpoint, let despawnSecond = spawnpoint.despawnSecond {
                let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000)
                let components = Calendar.current.dateComponents([.second, .minute], from: date)
                let secondOfHour = (components.second ?? 0) + (components.minute ?? 0) * 60
                let depsawnOffset: Int
                if despawnSecond < secondOfHour {
                    depsawnOffset = 3600 + Int(despawnSecond) - secondOfHour
                } else {
                    depsawnOffset = Int(despawnSecond) - secondOfHour
                }
                self.expireTimestamp = UInt32(Int(date.timeIntervalSince1970) + depsawnOffset)
                self.expireTimestampVerified = true
                if Pokemon.saveSpawnpointLastSeen {
                    try? spawnpoint.setLastSeen(mysql: mysql)
                }
            } else if spawnpoint == nil {
                let spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon,
                                            updated: updated, lastSeen: updated, despawnSecond: nil)
                try? spawnPoint.save(mysql: mysql, update: true)
            }
        }

        self.spawnId = spawnId
        self.cellId = cellId
        self.seenType = SeenType.wild

    }

    init(mysql: MySQL?=nil, nearbyPokemon: NearbyPokemonProto, cellId: UInt64,
         username: String?, isEvent: Bool) throws {

        self.isEvent = isEvent
        let id = nearbyPokemon.encounterID.description
        let pokemonId = nearbyPokemon.pokedexNumber.toUInt16()
        let pokestopId = nearbyPokemon.fortID
        let gender = nearbyPokemon.pokemonDisplay.gender.rawValue.toUInt8()
        let form = nearbyPokemon.pokemonDisplay.form.rawValue.toUInt16()
        if nearbyPokemon.hasPokemonDisplay {
            costume = nearbyPokemon.pokemonDisplay.costume.rawValue.toUInt8()
            weather = nearbyPokemon.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
            // The wildPokemon and nearbyPokemon GMOs don't contain actual shininess.
            // shiny = wildPokemon.pokemonData.pokemonDisplay.shiny
        }
        self.username = username

        let lat: Double
        let lon: Double
        if pokestopId.isEmpty {
            if !Pokemon.cellPokemonEnabled { throw ParsingError() }
            let s2cell = S2Cell(cellId: S2CellId(uid: cellId))
            let nlat = s2cell.capBound.rectBound.center.lat.degrees
            let nlon = s2cell.capBound.rectBound.center.lng.degrees
            lat = nlat
            lon = nlon
            self.seenType = SeenType.nearbyCell
        } else {
            let pokestop = Pokestop.cache?.get(id: pokestopId)
            if pokestop != nil {
                lat = pokestop!.lat
                lon = pokestop!.lon
            } else {
                let sql = """
                    SELECT lat, lon
                    FROM pokestop
                    WHERE id = ?;
                """

                guard let mysql = mysql ?? DBController.global.mysql else {
                    Log.error(message: "[POKEMON] Failed to connect to database.")
                    throw DBController.DBError()
                }

                let mysqlStmt = MySQLStmt(mysql)
                _ = mysqlStmt.prepare(statement: sql)

                mysqlStmt.bindParam(pokestopId)

                guard mysqlStmt.execute() else {
                    Log.error(message: "[POKEMON] Failed to execute query 'init nearby_stop pokemon'. " +
                        "(\(mysqlStmt.errorMessage())")
                    throw DBController.DBError()
                }

                let results = mysqlStmt.results()

                if results.numRows == 0 {
                    throw ParsingError()
                }

                let result = results.next()
                lat = result![0] as! Double
                lon = result![1] as! Double
            }
            self.seenType = SeenType.nearbyStop
        }

        self.id = id
        self.lat = lat
        self.lon = lon
        self.pokemonId = pokemonId
        self.pokestopId = (pokestopId.isEmpty ? nil : pokestopId)
        self.gender = gender
        self.form = form

        self.cellId = cellId
        self.expireTimestampVerified = false

    }

    init(mysql: MySQL?=nil, mapPokemon: MapPokemonProto, cellId: UInt64, username: String?, isEvent: Bool) throws {
        self.isEvent = isEvent
        let encounterId: UInt64 = mapPokemon.encounterID
        // var displayId: Int64 = mapPokemon.pokemonDisplay.displayID
        self.id = encounterId.toString()
        self.pokemonId = mapPokemon.pokedexTypeID.toUInt16()

        let spawnpointId: String = mapPokemon.spawnpointID
        guard let pokestop = try? Pokestop.getWithId(mysql: mysql, id: spawnpointId) else {
            throw ParsingError()
        }
        self.pokestopId = pokestop.id
        self.lat = pokestop.lat
        self.lon = pokestop.lon

        self.gender = mapPokemon.pokemonDisplay.gender.rawValue.toUInt8()
        self.form = mapPokemon.pokemonDisplay.form.rawValue.toUInt16()
        if mapPokemon.hasPokemonDisplay {
            self.costume = mapPokemon.pokemonDisplay.costume.rawValue.toUInt8()
            self.weather = mapPokemon.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
            // The mapPokemon and nearbyPokemon GMOs don't contain actual shininess.
            // shiny = mapPokemon.pokemonDisplay.shiny
        }
        self.username = username

        if mapPokemon.expirationTimeMs > 0 {
            self.expireTimestamp = UInt32((0 + UInt64(mapPokemon.expirationTimeMs)) / 1000)
            self.expireTimestampVerified = true
        } else {
            self.expireTimestampVerified = false
        }

        self.seenType = .lureWild
        self.cellId = cellId
    }

    public func addEncounter(mysql: MySQL, encounterData: EncounterOutProto,
                             username: String?) {

        let pokemonId = UInt16(encounterData.pokemon.pokemon.pokemonID.rawValue)
        let cp = UInt16(encounterData.pokemon.pokemon.cp)
        let move1 = UInt16(encounterData.pokemon.pokemon.move1.rawValue)
        let move2 = UInt16(encounterData.pokemon.pokemon.move2.rawValue)
        let size = Double(encounterData.pokemon.pokemon.heightM)
        let weight = Double(encounterData.pokemon.pokemon.weightKg)
        let atkIv = UInt8(encounterData.pokemon.pokemon.individualAttack)
        let defIv = UInt8(encounterData.pokemon.pokemon.individualDefense)
        let staIv = UInt8(encounterData.pokemon.pokemon.individualStamina)
        let costume = UInt8(encounterData.pokemon.pokemon.pokemonDisplay.costume.rawValue)
        let form = UInt16(encounterData.pokemon.pokemon.pokemonDisplay.form.rawValue)
        let gender = UInt8(encounterData.pokemon.pokemon.pokemonDisplay.gender.rawValue)
        let weather = encounterData.pokemon.pokemon.pokemonDisplay.weatherBoostedCondition.rawValue.toUInt8()
        let lat = encounterData.pokemon.latitude
        let lon = encounterData.pokemon.longitude

        if pokemonId != self.pokemonId ||
           cp != self.cp ||
           move1 != self.move1 ||
           move2 != self.move2 ||
           size != self.size ||
           weight != self.weight ||
           atkIv != self.atkIv ||
           defIv != self.defIv ||
           staIv != self.staIv ||
           costume != self.costume ||
           form != self.form ||
           gender != self.gender ||
           weather != self.weather {
            self.hasChanges = true
            self.hasIvChanges = true
        }

        self.pokemonId = pokemonId
        self.cp = cp
        self.move1 = move1
        self.move2 = move2
        self.size = size
        self.weight = weight
        self.atkIv = atkIv
        self.defIv = defIv
        self.staIv = staIv
        self.costume = costume
        self.form = form
        self.gender = gender
        self.weather = weather
        self.lat = lat
        self.lon = lon

        self.shiny = encounterData.pokemon.pokemon.pokemonDisplay.shiny
        self.username = username

        if hasIvChanges {
            if encounterData.hasCaptureProbability {
                self.capture1 = Double(encounterData.captureProbability.captureProbability[0])
                self.capture2 = Double(encounterData.captureProbability.captureProbability[1])
                self.capture3 = Double(encounterData.captureProbability.captureProbability[2])
            }
            let cpMultiplier = encounterData.pokemon.pokemon.cpMultiplier
            let level: UInt8
            if cpMultiplier < 0.734 {
                level = UInt8(round(58.35178527 * cpMultiplier * cpMultiplier -
                                    2.838007664 * cpMultiplier + 0.8539209906))
            } else {
                level = UInt8(round(171.0112688 * cpMultiplier - 95.20425243))
            }
            self.level = level
            self.isDitto = Pokemon.isDittoDisguised(
                id: self.id,
                pokemonId: pokemonId,
                level: level,
                weather: weather,
                atkIv: atkIv,
                defIv: defIv,
                staIv: staIv
            )
            if self.isDitto {
                self.setDittoAttributes(displayPokemonId: pokemonId,
                    weather: weather, level: level)
            }
            setPVP()
        }

        let wildPokemon = encounterData.pokemon
        self.spawnId = UInt64(wildPokemon.spawnPointID, radix: 16)
        let timestampMs = Date().timeIntervalSince1970 * 1000
        if wildPokemon.timeTillHiddenMs <= 90000 && wildPokemon.timeTillHiddenMs > 0 {
            expireTimestamp = UInt32((timestampMs + Double(UInt64(wildPokemon.timeTillHiddenMs))) / 1000)
            expireTimestampVerified = true
            let date = Date(timeIntervalSince1970: Double(self.expireTimestamp!))
            let components = Calendar.current.dateComponents([.second, .minute], from: date)
            let secondOfHour = (components.second ?? 0) + (components.minute ?? 0) * 60
            let spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon,
                                       updated: updated, lastSeen: updated, despawnSecond: UInt16(secondOfHour))
            try? spawnPoint.save(mysql: mysql, update: true)
        } else {
            expireTimestampVerified = false
        }

        if !expireTimestampVerified && spawnId != nil {
            let spawnpoint: SpawnPoint?
            do {
                spawnpoint = try SpawnPoint.getWithId(mysql: mysql, id: spawnId!)
            } catch {
                spawnpoint = nil
            }
            if let spawnpoint = spawnpoint, let despawnSecond = spawnpoint.despawnSecond {
                let date = Date(timeIntervalSince1970: Double(timestampMs) / 1000)
                let components = Calendar.current.dateComponents([.second, .minute], from: date)
                let secondOfHour = (components.second ?? 0) + (components.minute ?? 0) * 60
                let despawnOffset: Int
                if despawnSecond < secondOfHour {
                    despawnOffset = 3600 + Int(despawnSecond) - secondOfHour
                } else {
                    despawnOffset = Int(despawnSecond) - secondOfHour
                }

                self.expireTimestamp = UInt32(Int(date.timeIntervalSince1970) + despawnOffset)
                self.expireTimestampVerified = true
                if Pokemon.saveSpawnpointLastSeen {
                    try? spawnpoint.setLastSeen(mysql: mysql)
                }
            } else if spawnpoint == nil {
                let spawnPoint = SpawnPoint(id: spawnId!, lat: lat, lon: lon,
                                            updated: updated, lastSeen: updated, despawnSecond: nil)
                try? spawnPoint.save(mysql: mysql, update: true)
            }
        }

        self.seenType = SeenType.encounter
        self.updated = UInt32(Date().timeIntervalSince1970)
        self.changed = self.updated
    }

    public func addDiskEncounter(mysql: MySQL, diskEncounterData: DiskEncounterOutProto,
                                 username: String?) {

        let pokemonId = UInt16(diskEncounterData.pokemon.pokemonID.rawValue)
        let cp = UInt16(diskEncounterData.pokemon.cp)
        let move1 = UInt16(diskEncounterData.pokemon.move1.rawValue)
        let move2 = UInt16(diskEncounterData.pokemon.move2.rawValue)
        let size = Double(diskEncounterData.pokemon.heightM)
        let weight = Double(diskEncounterData.pokemon.weightKg)
        let atkIv = UInt8(diskEncounterData.pokemon.individualAttack)
        let defIv = UInt8(diskEncounterData.pokemon.individualDefense)
        let staIv = UInt8(diskEncounterData.pokemon.individualStamina)
        let costume = UInt8(diskEncounterData.pokemon.pokemonDisplay.costume.rawValue)
        let form = UInt16(diskEncounterData.pokemon.pokemonDisplay.form.rawValue)
        let gender = UInt8(diskEncounterData.pokemon.pokemonDisplay.gender.rawValue)

        if pokemonId != self.pokemonId ||
               cp != self.cp ||
               move1 != self.move1 ||
               move2 != self.move2 ||
               size != self.size ||
               weight != self.weight ||
               atkIv != self.atkIv ||
               defIv != self.defIv ||
               staIv != self.staIv ||
               costume != self.costume ||
               form != self.form ||
               gender != self.gender {
            self.hasChanges = true
            self.hasIvChanges = true
        }

        self.pokemonId = pokemonId
        self.cp = cp
        self.move1 = move1
        self.move2 = move2
        self.size = size
        self.weight = weight
        self.atkIv = atkIv
        self.defIv = defIv
        self.staIv = staIv
        self.costume = costume
        self.form = form
        self.gender = gender

        self.shiny = diskEncounterData.pokemon.pokemonDisplay.shiny
        self.username = username

        if hasIvChanges {
            if diskEncounterData.hasCaptureProbability {
                self.capture1 = Double(diskEncounterData.captureProbability.captureProbability[0])
                self.capture2 = Double(diskEncounterData.captureProbability.captureProbability[1])
                self.capture3 = Double(diskEncounterData.captureProbability.captureProbability[2])
            }
            let cpMultiplier = diskEncounterData.pokemon.cpMultiplier
            let level: UInt8
            if cpMultiplier < 0.734 {
                level = UInt8(round(58.35178527 * cpMultiplier * cpMultiplier -
                    2.838007664 * cpMultiplier + 0.8539209906))
            } else {
                level = UInt8(round(171.0112688 * cpMultiplier - 95.20425243))
            }
            self.level = level
            self.isDitto = Pokemon.isDittoDisguised(
                id: self.id,
                pokemonId: pokemonId,
                level: level,
                weather: self.weather ?? 0,
                atkIv: atkIv,
                defIv: defIv,
                staIv: staIv
            )
            if self.isDitto {
                Log.debug(message: "[POKEMON] Pokemon \(id) Ditto found, disguised as \(self.pokemonId)")
                self.setDittoAttributes(displayPokemonId: pokemonId, weather: self.weather ?? 0, level: level)
            }
            setPVP()
        }

        self.seenType = SeenType.lureEncounter
        self.updated = UInt32(Date().timeIntervalSince1970)
        self.changed = self.updated
    }

    private func setPVP() {
        let form = PokemonDisplayProto.Form.init(rawValue: Int(self.form ?? 0)) ?? .unset
        let pokemonID = HoloPokemonId(rawValue: Int(self.pokemonId)) ?? .missingno
        let gender = PokemonDisplayProto.Gender.init(rawValue: Int(self.gender ?? 0)) ?? .unset
        if self.baseHeight == nil || self.baseWeight == nil {
            let stats = PVPStatsManager.global.getStats(
                pokemon: pokemonID,
                form: form == .unset ? nil : form
            )
            self.baseHeight = stats?.baseHeight
            self.baseWeight = stats?.baseWeight
        }
        if !Pokemon.pvpEnabled {
            return
        }
        if self.atkIv == nil || self.defIv == nil || self.staIv == nil {
            // e.g. if weather boosted ditto found
            // weather boosted ditto was removed atm, keep this as reminder
            return
        }
        let costume = PokemonDisplayProto.Costume(rawValue: Int(self.costume ?? 0)) ?? .unset

        self.pvp = PVPStatsManager.global.getPVPAllLeagues(
            pokemon: pokemonID,
            form: form == .unset ? nil : form,
            gender: gender == .unset ? nil : gender,
            costume: costume,
            iv: .init(attack: Int(self.atkIv!), defense: Int(self.defIv!), stamina: Int(self.staIv!)),
            level: Double(self.level!)
        )
    }

    public static func shouldUpdate(old: Pokemon, new: Pokemon) -> Bool {
        if old.hasChanges {
            old.hasChanges = false
            return true
        }
        return
            new.pokemonId != old.pokemonId ||
            new.spawnId != old.spawnId ||
            new.pokestopId != old.pokestopId ||
            new.weather != old.weather ||
            new.expireTimestampVerified != old.expireTimestampVerified ||
            new.atkIv != old.atkIv ||
            new.defIv != old.defIv ||
            new.staIv != old.staIv ||
            new.cp != old.cp ||
            new.level != old.level ||
            new.move1 != old.move1 ||
            new.move2 != old.move2 ||
            new.gender != old.gender ||
            new.form != old.form ||
            new.costume != old.costume ||
            abs(Int(new.expireTimestamp ?? 0) - Int(old.expireTimestamp ?? 0)) >= 60 ||
            fabs(new.lat - old.lat) >= 0.000001 ||
            fabs(new.lon - old.lon) >= 0.000001
    }

    public func save(mysql: MySQL?=nil, updateIV: Bool=false) throws {

        var updateIV = updateIV
        var bindFirstSeen: Bool
        var bindChangedTimestamp: Bool
        let setIVForWeather: Bool

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        updated = UInt32(Date().timeIntervalSince1970)

        let oldPokemon: Pokemon?
        do {
            oldPokemon = try Pokemon.getWithId(mysql: mysql, id: id, isEvent: isEvent)
        } catch {
            oldPokemon = nil
        }
        let mysqlStmt = MySQLStmt(mysql)

        if isEvent && atkIv == nil {
            do {
                if let oldPokemonNoneEvent = try Pokemon.getWithId(mysql: mysql, id: id, isEvent: false),
                   oldPokemonNoneEvent.atkIv != nil,
                   (weather?.zeroToNull() == nil && oldPokemonNoneEvent.weather?.zeroToNull() == nil) ||
                   (weather?.zeroToNull() != nil && oldPokemonNoneEvent.weather?.zeroToNull() != nil) {
                    self.atkIv = oldPokemonNoneEvent.atkIv
                    self.defIv = oldPokemonNoneEvent.defIv
                    self.staIv = oldPokemonNoneEvent.staIv
                    self.level = oldPokemonNoneEvent.level
                    self.cp = nil
                    self.weight = nil
                    self.size = nil
                    self.move1 = nil
                    self.move2 = nil
                    self.capture1 = nil
                    self.capture2 = nil
                    self.capture3 = nil
                    updateIV = true
                    setPVP()
                }
            } catch { /* ignore */ }
        }
        if isEvent && expireTimestampVerified == false {
            if let oldPokemonNoneEvent = try Pokemon.getWithId(mysql: mysql, id: id, isEvent: false),
                oldPokemonNoneEvent.expireTimestampVerified {
                self.expireTimestamp = oldPokemonNoneEvent.expireTimestamp
                self.expireTimestampVerified = oldPokemonNoneEvent.expireTimestampVerified
            }
        }

        let now = UInt32(Date().timeIntervalSince1970)
        if oldPokemon == nil {
            setIVForWeather = false
            bindFirstSeen = false
            bindChangedTimestamp = false

            if self.expireTimestamp == nil {
                self.expireTimestamp = UInt32(Date().timeIntervalSince1970) + Pokemon.defaultTimeUnseen
            }
            firstSeenTimestamp = updated

            let sql = """
                INSERT INTO pokemon (
                    id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2, cp,
                    level, weight, size, capture_1, capture_2, capture_3, shiny, display_pokemon_id,
                    pvp, username, gender, form, weather, costume, pokestop_id, updated, first_seen_timestamp, changed,
                    cell_id, expire_timestamp_verified, is_event, seen_type
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), ?, ?, ?, ?
                )
            """
            self.updated = now
            self.firstSeenTimestamp = now
            self.changed = now
            _ = mysqlStmt.prepare(statement: sql)
            mysqlStmt.bindParam(id)
        } else {
            bindFirstSeen = true

            self.firstSeenTimestamp = oldPokemon!.firstSeenTimestamp

            if self.expireTimestamp == nil {
                let now = Date()
                let oldExpireDate = Date(timeIntervalSince1970: Double(oldPokemon!.expireTimestamp ?? 0))
                if Int(oldExpireDate.timeIntervalSince(now)) < Int(Pokemon.defaultTimeReseen) {
                    self.expireTimestamp = UInt32(Date().timeIntervalSince1970) + Pokemon.defaultTimeReseen
                } else {
                    self.expireTimestamp = oldPokemon!.expireTimestamp
                }
            }
            if !expireTimestampVerified && oldPokemon!.expireTimestampVerified {
                self.expireTimestampVerified = oldPokemon!.expireTimestampVerified
                self.expireTimestamp = oldPokemon!.expireTimestamp
            }

            if oldPokemon!.pokemonId != self.pokemonId {
                if oldPokemon!.pokemonId != Pokemon.dittoPokemonId {
                    Log.debug(
                        message: "[POKEMON] Pokemon \(id) changed from \(oldPokemon!.pokemonId) to \(self.pokemonId)"
                    )
                } else if oldPokemon!.displayPokemonId ?? 0 != self.pokemonId {
                    Log.debug(
                        message: "[POKEMON] Pokemon \(id) Ditto disguised as \(oldPokemon!.displayPokemonId ?? 0) " +
                                 "now seen as \(self.pokemonId)"
                    )
                } else if oldPokemon!.displayPokemonId != nil && oldPokemon!.pokemonId != self.pokemonId {
                    Log.debug(message: "[POKEMON] Pokemon \(id) Ditto from \(oldPokemon!.pokemonId) to \(pokemonId)")
                }
            }

            if oldPokemon!.cellId != nil && self.cellId == nil {
                self.cellId = oldPokemon!.cellId
            }

            if oldPokemon!.spawnId != nil {
                self.spawnId = oldPokemon!.spawnId
                self.lat = oldPokemon!.lat
                self.lon = oldPokemon!.lon
            }

            if oldPokemon!.pokestopId != nil && self.pokestopId == nil {
                self.pokestopId = oldPokemon!.pokestopId
            }

            if oldPokemon!.pvp != nil && self.pvp == nil {
                self.pvp = oldPokemon!.pvp
            }

            let changedSQL: String
            if updateIV && oldPokemon!.atkIv == nil && self.atkIv != nil {
                bindChangedTimestamp = false
                self.changed = now
                changedSQL = "UNIX_TIMESTAMP()"
            } else {
                bindChangedTimestamp = true
                self.changed = oldPokemon!.changed
                changedSQL = "?"
            }

            let weatherChanged = (oldPokemon!.weather == nil || oldPokemon!.weather! == 0) && (self.weather ?? 0 > 0) ||
                                 (self.weather == nil || self.weather! == 0 ) && (oldPokemon!.weather ?? 0 > 0)

            if oldPokemon!.atkIv != nil && self.atkIv == nil && !weatherChanged {
                setIVForWeather = false
                self.atkIv = oldPokemon!.atkIv
                self.defIv = oldPokemon!.defIv
                self.staIv = oldPokemon!.staIv
                self.cp = oldPokemon!.cp
                self.weight = oldPokemon!.weight
                self.size = oldPokemon!.size
                self.move1 = oldPokemon!.move1
                self.move2 = oldPokemon!.move2
                self.level = oldPokemon!.level
                self.capture1 = oldPokemon!.capture1
                self.capture2 = oldPokemon!.capture2
                self.capture3 = oldPokemon!.capture3
                self.shiny = oldPokemon!.shiny
                self.seenType = oldPokemon!.seenType
                self.isDitto = Pokemon.isDittoDisguised(pokemon: oldPokemon!)
                if self.isDitto {
                    Log.debug(message: "[POKEMON] oldPokemon \(id) Ditto found, disguised as \(self.pokemonId)")
                    self.setDittoAttributes(displayPokemonId: self.pokemonId,
                        weather: oldPokemon!.weather ?? 0, level: oldPokemon!.level ?? 0)
                }
            } else if (self.atkIv != nil && oldPokemon?.atkIv == nil) ||
                      (self.cp != nil && oldPokemon?.cp == nil) ||
                      hasIvChanges {
                setIVForWeather = false
                updateIV = true
            } else if weatherChanged && oldPokemon!.atkIv != nil && Pokemon.weatherIVClearingEnabled {
                Log.debug(message: "[POKEMON] Pokemon \(id) changed Weatherboosted State. Clearing IVs.")
                setIVForWeather = true
                self.atkIv = nil
                self.defIv = nil
                self.staIv = nil
                self.cp = nil
                self.weight = nil
                self.size = nil
                self.move1 = nil
                self.move2 = nil
                self.level = nil
                self.capture1 = nil
                self.capture2 = nil
                self.capture3 = nil
                self.pvp = nil
                Log.debug(message: "[POKEMON] Weather-Boosted state changed. Clearing IVs")
            } else {
                setIVForWeather = false
            }

            guard Pokemon.shouldUpdate(old: oldPokemon!, new: self) else {
                return
            }

            let ivSQL: String
            if updateIV || setIVForWeather {
                ivSQL = "atk_iv = ?, def_iv = ?, sta_iv = ?, move_1 = ?, move_2 = ?, cp = ?, level = ?, " +
                        "weight = ?, size = ?, capture_1 = ?, capture_2 = ?, capture_3 = ?, " +
                        "shiny = ?, display_pokemon_id = ?, pvp = ?,"
            } else {
                ivSQL = ""
            }

            if oldPokemon!.pokemonId == Pokemon.dittoPokemonId && self.pokemonId != Pokemon.dittoPokemonId {
                Log.debug(
                    message: "[POKEMON] Pokemon \(id) Ditto changed from \(oldPokemon!.pokemonId) to \(self.pokemonId)"
                )
            }

            let sql = """
                UPDATE pokemon
                SET pokemon_id = ?, lat = ?, lon = ?, spawn_id = ?, expire_timestamp = ?, \(ivSQL) username = ?,
                    gender = ?, form = ?, weather = ?, costume = ?, pokestop_id = ?, updated = UNIX_TIMESTAMP(),
                    first_seen_timestamp = ?, changed = \(changedSQL), cell_id = ?, expire_timestamp_verified = ?,
                    is_event = ?, seen_type = ?
                WHERE id = ? AND is_event = ?
            """
            self.updated = now
            _ = mysqlStmt.prepare(statement: sql)
        }

        mysqlStmt.bindParam(pokemonId)
        mysqlStmt.bindParam(lat)
        mysqlStmt.bindParam(lon)
        mysqlStmt.bindParam(spawnId)
        mysqlStmt.bindParam(expireTimestamp)
        if updateIV || setIVForWeather || oldPokemon == nil {
            mysqlStmt.bindParam(atkIv)
            mysqlStmt.bindParam(defIv)
            mysqlStmt.bindParam(staIv)
            mysqlStmt.bindParam(move1)
            mysqlStmt.bindParam(move2)
            mysqlStmt.bindParam(cp)
            mysqlStmt.bindParam(level)
            mysqlStmt.bindParam(weight)
            mysqlStmt.bindParam(size)
            mysqlStmt.bindParam(capture1)
            mysqlStmt.bindParam(capture2)
            mysqlStmt.bindParam(capture3)
            mysqlStmt.bindParam(shiny)
            mysqlStmt.bindParam(displayPokemonId)
            mysqlStmt.bindParam(pvp?.jsonEncodeForceTry())
        }
        mysqlStmt.bindParam(username)
        mysqlStmt.bindParam(gender)
        mysqlStmt.bindParam(form)
        mysqlStmt.bindParam(weather)
        mysqlStmt.bindParam(costume)
        mysqlStmt.bindParam(pokestopId)
        if bindFirstSeen {
            mysqlStmt.bindParam(firstSeenTimestamp)
        }
        if bindChangedTimestamp {
            mysqlStmt.bindParam(changed)
        }
        mysqlStmt.bindParam(cellId)
        mysqlStmt.bindParam(expireTimestampVerified)
        mysqlStmt.bindParam(isEvent)
        mysqlStmt.bindParam(seenType.rawValue)

        if oldPokemon != nil {
            mysqlStmt.bindParam(id)
            mysqlStmt.bindParam(oldPokemon!.isEvent)
        }

        guard mysqlStmt.execute() else {
            if mysqlStmt.errorCode() == 1062 {
                Log.debug(message: "[POKEMON] Duplicated key. Skipping...")
            } else {
                Log.error(message: "[POKEMON] Failed to execute query '\(oldPokemon != nil ? "update" : "insert")' " +
                    "of \(seenType.rawValue) pokemon id '\(id)' - cell id '\(String(describing: cellId))'. " +
                    "(\(mysqlStmt.errorMessage()))")
            }
            throw DBController.DBError()
        }

        if setIVForWeather {
            WebHookController.global.addPokemonEvent(pokemon: self)
            InstanceController.global.gotPokemon(pokemon: self)
        } else if oldPokemon == nil {
            WebHookController.global.addPokemonEvent(pokemon: self)
            InstanceController.global.gotPokemon(pokemon: self)
            if self.atkIv != nil {
                InstanceController.global.gotIV(pokemon: self)
            }
        } else if updateIV && ((oldPokemon!.atkIv == nil && self.atkIv != nil) || oldPokemon?.hasIvChanges == true) {
            oldPokemon?.hasIvChanges = false
            WebHookController.global.addPokemonEvent(pokemon: self)
            InstanceController.global.gotIV(pokemon: self)
        }
        let uuid = self.isEvent ? "\(self.id)-1" : self.id
        Pokemon.cache?.set(id: uuid, value: self)
    }

    //  swiftlint:disable:next function_parameter_count
    public static func getAll(mysql: MySQL?=nil, minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                              showIV: Bool, updated: UInt32, pokemonFilterExclude: [Int]?=nil,
                              pokemonFilterIV: [String: String]?=nil, isEvent: Bool,
                              excludeCellPokemon: Bool=false) throws -> [Pokemon] {

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        var pokemonFilterExclude = pokemonFilterExclude ?? [Int]()

        if pokemonFilterIV != nil && !pokemonFilterIV!.isEmpty && showIV {
            for ivFilter in pokemonFilterIV! {
                guard let id = Int(ivFilter.key) else {
                    continue
                }
                if !pokemonFilterExclude.contains(id) {
                    pokemonFilterExclude.append(id)
                }
            }

        }

        let sqlExclude: String
        if pokemonFilterExclude.isEmpty {
            sqlExclude = ""
        } else {
            var sqlExcludeCreate = "pokemon_id NOT IN ("
            for _ in 1..<pokemonFilterExclude.count {
                sqlExcludeCreate += "?, "
            }
            sqlExcludeCreate += "?)"
            sqlExclude = sqlExcludeCreate
        }

        let sqlAdd: String
        if (pokemonFilterIV == nil || pokemonFilterIV!.isEmpty || !showIV) && pokemonFilterExclude.isEmpty {
            sqlAdd = ""
        } else if pokemonFilterIV == nil || pokemonFilterIV!.isEmpty || !showIV {
            sqlAdd = " AND \(sqlExclude)"
        } else {
            var orPart = ""
            var andPart = ""
            for filter in pokemonFilterIV! {
                guard let sql = sqlifyIvFilter(filter: filter.value), sql != "" else {
                    continue
                }
                if filter.key == "and" {
                    andPart += "\(sql)"
                } else if !pokemonFilterExclude.isEmpty {
                    if orPart == "" {
                        orPart += "("
                    } else {
                        orPart += " OR "
                    }
                    if filter.key == "or" {
                        orPart += "(\(sql))"
                    } else {
                        let id = Int(filter.key) ?? 0
                        orPart += "( pokemon_id = \(id) AND \(sql))"
                    }
                }
            }
            if sqlExclude != "" {
                if orPart == "" {
                    orPart += "("
                } else {
                    orPart += " OR "
                }
                orPart += "(\(sqlExclude))"
            }
            if orPart != "" {
                orPart += ")"
            }

            if orPart != "" && andPart != "" {
                sqlAdd = " AND (\(orPart) AND \(andPart))"
            } else if orPart != "" {
                sqlAdd = " AND (\(orPart))"
            } else if andPart != "" {
                sqlAdd = " AND (\(andPart))"
            } else if sqlExclude != "" {
                sqlAdd = " AND (\(sqlExclude))"
            } else {
                sqlAdd = ""
            }

        }

        let excludeCellPokemonSql: String
        if excludeCellPokemon {
            excludeCellPokemonSql = "AND (seen_type is null or seen_type != 'nearby_cell')"
        } else {
            excludeCellPokemonSql = ""
        }

        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2,
                   gender, form, cp, level, weather, costume, weight, size, capture_1, capture_2, capture_3,
                   display_pokemon_id, pokestop_id, updated, first_seen_timestamp, changed, cell_id,
                   expire_timestamp_verified, shiny, username, pvp, is_event, seen_type
            FROM pokemon
            WHERE expire_timestamp >= UNIX_TIMESTAMP() AND lat >= ? AND lat <= ? AND lon >= ? AND
                  lon <= ? AND updated > ? AND is_event = ? \(sqlAdd) \(excludeCellPokemonSql)
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(minLat)
        mysqlStmt.bindParam(maxLat)
        mysqlStmt.bindParam(minLon)
        mysqlStmt.bindParam(maxLon)
        mysqlStmt.bindParam(updated)
        mysqlStmt.bindParam(isEvent)
        for id in pokemonFilterExclude {
            mysqlStmt.bindParam(id)
        }

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query 'getAll'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()

        var pokemons = [Pokemon]()
        while let result = results.next() {

            let id = result[0] as! String
            let pokemonId = result[1] as! UInt16
            let lat = result[2] as! Double
            let lon = result[3] as! Double
            let spawnId = result[4] as? UInt64
            let expireTimestamp = result[5] as? UInt32

            let atkIv: UInt8?
            let defIv: UInt8?
            let staIv: UInt8?
            let move1: UInt16?
            let move2: UInt16?
            let cp: UInt16?
            let level: UInt8?
            let weight: Double?
            let size: Double?
            let capture1: Double?
            let capture2: Double?
            let capture3: Double?
            let displayPokemonId: UInt16?
            if showIV {
                atkIv = result[6] as? UInt8
                defIv = result[7] as? UInt8
                staIv = result[8] as? UInt8
                move1 = result[9] as? UInt16
                move2 = result[10] as? UInt16
                cp = result[13] as? UInt16
                level = result[14] as? UInt8
                weight = result[17] as? Double
                size = result[18] as? Double
                capture1 = result[19] as? Double
                capture2 = result[20] as? Double
                capture3 = result[21] as? Double
                displayPokemonId = result[22] as? UInt16
            } else {
                atkIv = nil
                defIv = nil
                staIv = nil
                move1 = nil
                move2 = nil
                cp = nil
                level = nil
                weight = nil
                size = nil
                capture1 = nil
                capture2 = nil
                capture3 = nil
                displayPokemonId = nil
            }

            let gender = result[11] as? UInt8
            let form = result[12] as? UInt16
            let weather = result[15] as? UInt8
            let costume = result[16] as? UInt8
            let pokestopId = result[23] as? String
            let updated = result[24] as! UInt32
            let firstSeenTimestamp = result[25] as! UInt32
            let changed = result[26] as! UInt32
            let cellId = result[27] as? UInt64
            let expireTimestampVerified = (result[28] as? UInt8)!.toBool()
            let shiny = (result[29] as? UInt8)?.toBool()
            let username = result[30] as? String
            let pvp = (result[31] as? String)?.jsonDecodeForceTry() as? [String: Any]
            let isEvent = (result[32] as? UInt8)!.toBool()
            let seenType = SeenType(rawValue: result[33] as? String ?? "unset")!

            pokemons.append(Pokemon(
                id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId, expireTimestamp: expireTimestamp,
                atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1, move2: move2, gender: gender, form: form,
                cp: cp, level: level, weight: weight, costume: costume, size: size, capture1: capture1,
                capture2: capture2, capture3: capture3, displayPokemonId: displayPokemonId,
                weather: weather, shiny: shiny, username: username, pokestopId: pokestopId,
                firstSeenTimestamp: firstSeenTimestamp, updated: updated, changed: changed, cellId: cellId,
                expireTimestampVerified: expireTimestampVerified, pvp: pvp, isEvent: isEvent, seenType: seenType
            ))
        }
        return pokemons

    }

    public static func getWithId(mysql: MySQL?=nil, id: String, isEvent: Bool) throws -> Pokemon? {
        let uuid = isEvent ? "\(id)-1" : id
        if let cached = cache?.get(id: uuid) {
            return cached
        }

        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT id, pokemon_id, lat, lon, spawn_id, expire_timestamp, atk_iv, def_iv, sta_iv, move_1, move_2,
                   gender, form, cp, level, weather, costume, weight, size, capture_1, capture_2, capture_3,
                   display_pokemon_id, pokestop_id, updated, first_seen_timestamp, changed, cell_id,
                   expire_timestamp_verified, shiny, username, pvp, is_event, seen_type
            FROM pokemon
            WHERE id = ? AND is_event = ?
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(id)
        mysqlStmt.bindParam(isEvent)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query 'getWithId'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }

        let result = results.next()!

        let id = result[0] as! String
        let pokemonId = result[1] as! UInt16
        let lat = result[2] as! Double
        let lon = result[3] as! Double
        let spawnId = result[4] as? UInt64
        let expireTimestamp = result[5] as? UInt32
        let atkIv = result[6] as? UInt8
        let defIv = result[7] as? UInt8
        let staIv = result[8] as? UInt8
        let move1 = result[9] as? UInt16
        let move2 = result[10] as? UInt16
        let gender = result[11] as? UInt8
        let form = result[12] as? UInt16
        let cp = result[13] as? UInt16
        let level = result[14] as? UInt8
        let weather = result[15] as? UInt8
        let costume = result[16] as? UInt8
        let weight = result[17] as? Double
        let size = result[18] as? Double
        let capture1 = result[19] as? Double
        let capture2 = result[20] as? Double
        let capture3 = result[21] as? Double
        let displayPokemonId = result[22] as? UInt16
        let pokestopId = result[23] as? String
        let updated = result[24] as! UInt32
        let firstSeenTimestamp = result[25] as! UInt32
        let changed = result[26] as! UInt32
        let cellId = result[27] as? UInt64
        let expireTimestampVerified = (result[28] as? UInt8)!.toBool()
        let shiny = (result[29] as? UInt8)?.toBool()
        let username = result[30] as? String
        let pvp = (result[31] as? String)?.jsonDecodeForceTry() as? [String: Any]
        let isEvent = (result[32] as? UInt8)!.toBool()
        let seenType = SeenType(rawValue: result[33] as? String ?? "unset")!

        let pokemon = Pokemon(
            id: id, pokemonId: pokemonId, lat: lat, lon: lon, spawnId: spawnId,
            expireTimestamp: expireTimestamp, atkIv: atkIv, defIv: defIv, staIv: staIv, move1: move1,
            move2: move2, gender: gender, form: form, cp: cp, level: level, weight: weight,
            costume: costume, size: size, capture1: capture1, capture2: capture2, capture3: capture3,
            displayPokemonId: displayPokemonId, weather: weather,
            shiny: shiny, username: username, pokestopId: pokestopId, firstSeenTimestamp: firstSeenTimestamp,
            updated: updated, changed: changed, cellId: cellId,
            expireTimestampVerified: expireTimestampVerified, pvp: pvp, isEvent: isEvent, seenType: seenType
        )
        let uuidNew = pokemon.isEvent ? "\(pokemon.id)-1" : pokemon.id
        cache?.set(id: uuidNew, value: pokemon)
        return pokemon
    }

    public static func == (lhs: Pokemon, rhs: Pokemon) -> Bool {
        return lhs.id == rhs.id
    }

    private func setDittoAttributes(displayPokemonId: UInt16, weather: UInt8, level: UInt8) {
        let moveTransformFast: UInt16 = 242
        let moveStruggle: UInt16 = 133
        self.displayPokemonId = displayPokemonId
        self.pokemonId = Pokemon.dittoPokemonId
        self.form = 0
        self.move1 = moveTransformFast
        self.move2 = moveStruggle
        self.gender = 3
        self.costume = 0
        self.size = nil
        self.weight = nil
        if weather == 0 && level > 30 {
            Log.debug(message: "[POKEMON] Pokemon \(id) weather boosted Ditto - reset IV is needed")
            // self.level = level - 5
            // self.atkIv = nil
            // self.defIv = nil
            // self.staIv = nil
            // self.cp = nil
            // self.capture1 = nil
            // self.capture2 = nil
            // self.capture3 = nil
            // self.weather = UInt8(POGOProtos.GameplayWeatherProto.WeatherCondition.partlyCloudy.rawValue)
        } else {
            // self.weather = UInt8(POGOProtos.GameplayWeatherProto.WeatherCondition.none.rawValue)
        }
    }

    private static func isDittoDisguised(pokemon: Pokemon) -> Bool {
        return isDittoDisguised(id: pokemon.id,
            pokemonId: pokemon.pokemonId,
            level: pokemon.level ?? 0,
            weather: pokemon.weather ?? 0,
            atkIv: pokemon.atkIv ?? 0,
            defIv: pokemon.defIv ?? 0,
            staIv: pokemon.staIv ?? 0
        )
    }

    //  swiftlint:disable:next function_parameter_count
    private static func isDittoDisguised(id: String, pokemonId: UInt16, level: UInt8, weather: UInt8,
                                         atkIv: UInt8, defIv: UInt8, staIv: UInt8) -> Bool {
        if pokemonId == Pokemon.dittoPokemonId {
            Log.debug(message: "[POKEMON] Pokemon \(id) was already detected as Ditto.")
            return true
        }
        let isUnderLevelBoosted = level > 0 && level < Pokemon.weatherBoostMinLevel
        let isUnderIvStatBoosted = level > 0 &&
            (atkIv < Pokemon.weatherBoostMinIvStat ||
             defIv < Pokemon.weatherBoostMinIvStat ||
             staIv < Pokemon.weatherBoostMinIvStat)
        let isWeatherBoosted = weather > 0
        let isOverLevel = level > 30

        if isWeatherBoosted {
            if isUnderLevelBoosted || isUnderIvStatBoosted {
                Log.debug(message: "[POKEMON] Pokemon \(id) Ditto found, disguised as \(pokemonId)")
                return true
            }
        } else {
            if isOverLevel {
                Log.debug(message: "[POKEMON] Pokemon \(id) weather boosted Ditto found, disguised as \(pokemonId)")
                return true
            }
        }
        return false
    }

    public static func truncate(mysql: MySQL?=nil) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
        TRUNCATE TABLE `pokemon`
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query 'truncate'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }

        cache?.clear()
    }

    private static func sqlifyIvFilter(filter: String) -> String? {

        let fullMatch = "^(?!&&|\\|\\|)((\\|\\||&&)?\\(?((A|D|S|L)?[0-9.]+(-(A|D|S|L)?[0-9.]+)?)\\)?)*$"

        if filter !~ fullMatch {
            return nil
        }

        let singleMatch = "(A|D|S|L)?[0-9.]+(-(A|D|S|L)?[0-9.]+)?"

        var sql = singleMatch.r?.replaceAll(in: filter) { match in
            if let firstGroup = match.group(at: 0) {

                var firstGroupNumbers = firstGroup.replacingOccurrences(of: "A", with: "")
                firstGroupNumbers = firstGroupNumbers.replacingOccurrences(of: "D", with: "")
                firstGroupNumbers = firstGroupNumbers.replacingOccurrences(of: "S", with: "")
                firstGroupNumbers = firstGroupNumbers.replacingOccurrences(of: "L", with: "")

                let column: String
                if firstGroup.contains(string: "A") {
                    column = "atk_iv"
                } else if firstGroup.contains(string: "D") {
                    column = "def_iv"
                } else if firstGroup.contains(string: "S") {
                    column = "sta_iv"
                } else if firstGroup.contains(string: "L") {
                    column = "level"
                } else {
                    column = "iv"
                }

                if firstGroupNumbers.contains(string: "-") { // min max
                    let split = firstGroupNumbers.components(separatedBy: "-")
                    guard split.count == 2, let number0 = Float(split[0]), let number1 = Float(split[1]) else {
                        return nil
                    }

                    let min: Float
                    let max: Float
                    if number0 < number1 {
                        min = number0
                        max = number1
                    } else {
                        max = number1
                        min = number0
                    }

                    return "\(column) >= \(min) AND \(column) <= \(max)"
                } else { // fixed
                    guard let number = Float(firstGroupNumbers) else {
                        return nil
                    }
                    return "\(column) = \(number)"
                }

            }
            return nil
        } ?? ""
        if sql == "" {
            return nil
        }

        sql = sql.replacingOccurrences(of: "&&", with: " AND ")
        sql = sql.replacingOccurrences(of: "||", with: " OR ")

        return sql

    }

    public static func getActiveCounts(mysql: MySQL?=nil) throws -> (total: Int64, iv: Int64) {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[POKEMON] Failed to connect to database.")
            throw DBController.DBError()
        }

        let sql = """
            SELECT COUNT(*) as countTotal, SUM(iv IS NOT NULL) as countIV
            FROM pokemon
            WHERE expire_timestamp >= UNIX_TIMESTAMP()
        """

        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)

        guard mysqlStmt.execute() else {
            Log.error(message: "[POKEMON] Failed to execute query 'activeCount'. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return  (total: 0, iv: 0)
        }

        let result = results.next()!

        let total = result[0] as! Int64
        let iv = Int64(result[1] as? String ?? "0") ?? 0
        return (total: total, iv: iv)
    }

}
