import Foundation

/// Represents  the parameters to login the user
struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct RegisterRequest: Codable {
    let fullname: String
    let email: String
    let username: String
    let password: String
}

struct TripRequest: Codable {
    let name: String
    let startDate: String
    let endDate: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

struct EventRequest: Codable {
    let tripId: Trip.ID?
    let name: String
    let date: String
    let location: Location?
    let transitionFromPrevious: String?

    // Custom CodingKeys to map between JSON keys and struct properties
    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case name
        case date
        case location
        case transitionFromPrevious = "transition_from_previous"
    }
}

struct MediaRequest: Codable {
    let base64Data: String
    let eventId: Event.ID
    
    enum CodingKeys: String, CodingKey {
        case base64Data = "base64_data"
        case eventId = "event_id"
    }
}

/// An object that can be used to create a new trip.
struct TripCreate: Codable {
    let name: String
    let startDate: Date
    let endDate: Date
}

/// An object that can be used to update an existing trip.
struct TripUpdate: Codable {
    let name: String
    let startDate: Date
    let endDate: Date
}

/// An object that can be used to create a media.
struct MediaCreate: Codable {
    let eventId: Event.ID
    let base64Data: Data
}

/// An object that can be used to create a new event.
struct EventCreate: Codable {
    let tripId: Trip.ID
    let name: String
    let note: String?
    let date: Date
    let location: Location?
    let transitionFromPrevious: String?
}

/// An object that can be used to update an existing event.
struct EventUpdate: Codable {
    var name: String
    var note: String?
    var date: Date
    var location: Location?
    var transitionFromPrevious: String?
}
