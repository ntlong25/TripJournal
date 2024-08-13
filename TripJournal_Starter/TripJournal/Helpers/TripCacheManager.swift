//
//  TripCacheManager.swift
//  TripJournal
//
//  Created by Nguyen Thanh Long on 11/8/24.
//

import Foundation

class TripCacheManager {
    private let userDefaults = UserDefaults.standard
    private let tripsKey = "trips"
    
    func saveTrips(_ trips: [Trip]) {
        do {
            // Encode trips array into JSON data and save it to UserDefaults using tripsKey
            let data = try JSONEncoder().encode(trips)
            userDefaults.set(data, forKey: tripsKey)
        } catch {
            print("Failed to save trips to UserDefaults: \(error)")
        }
    }

    func loadTrips() -> [Trip] {
        // Retrieve data from UserDefaults using tripsKey; if no data is found, return an empty array
        guard let data = userDefaults.data(forKey: tripsKey) else {
            return []
        }

        do {
            // Retrieve data from UserDefaults using tripsKey; if no data is found, return an empty array
            return try JSONDecoder().decode([Trip].self, from: data)

        } catch {
            print("Failed to load trips from UserDefaults: \(error)")
            return []
        }
    }
}
