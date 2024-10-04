//
//  JournalService+Live.swift
//  TripJournal
//
//  Created by Nguyen Thanh Long on 7/8/24.
//

import Foundation
import Combine

enum HTTPMethods: String {
    case POST, GET, PUT, DELETE
}

enum NetworkError: Error {
    case badUrl
    case badResponse
    case failedToDecodeResponse
    case invalidValue
}

enum SessionError: Error {
    case expired
}

extension SessionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .expired:
            return String("Your session has expired. Please log in again.")
        }
    }
}

class JournalServiceLive: JournalService {
    
    enum EndPoints {
        static let base = "http://localhost:8000/"
        
        case register
        case login
        case trips
        case handleTrip(String)
        case events
        case handleEvent(String)
        case media
        case handleMedia(String)

        private var stringValue: String {
            switch self {
            case .register:
                return EndPoints.base + "register"
            case .login:
                return EndPoints.base + "token"
            case .trips:
                return EndPoints.base + "trips"
            case .handleTrip(let tripId):
                return EndPoints.base + "trips/\(tripId)"
            case .events:
                return EndPoints.base + "events"
            case .handleEvent(let eventId):
                return EndPoints.base + "events/\(eventId)"
            case .media:
                return EndPoints.base + "media"
            case .handleMedia(let mediaId):
                return EndPoints.base + "media/\(mediaId)"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
    }
    
    private let urlSession: URLSession
    
    private let tripCacheManager = TripCacheManager()
    @Published private var networkMonitor = NetworkMonitor()
    
    var tokenExpired: Bool = false
    
    @Published private var token: Token? {
        didSet {
            if let token = token {
                try? KeychainHelper.shared.saveToken(token)
            } else {
                try? KeychainHelper.shared.deleteToken()
            }
        }
    }
    
    var isAuthenticated: AnyPublisher<Bool, Never> {
        $token
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.urlSession = URLSession(configuration: configuration)
        
        if let savedToken = try? KeychainHelper.shared.getToken() {
            if !isTokenExpired(savedToken) {
                self.token = savedToken
            } else {
                self.tokenExpired = true
                self.token = nil
            }
        } else {
            self.token = nil
        }
    }
    
    func register(fullname: String, email: String, username: String, password: String) async throws -> Token {
        let request = try createRegisterRequest(fullname: fullname, email: email, username: username, password: password)
        
        return try await performNetworkRequest(request, responseType: Token.self)
    }
    
    func logIn(username: String, password: String) async throws -> Token {
        let request = try createLoginRequest(username: username, password: password)
        
        return try await performNetworkRequest(request, responseType: Token.self)
    }
    
    func logOut() {
        token = nil
    }

    func createTrip(with trip: TripCreate) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.trips.url)
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue("application/json", forHTTPHeaderField: "accept")
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        let tripData = TripRequest(name: trip.name,
                                   startDate: dateFormatter.string(from: trip.startDate),
                                   endDate: dateFormatter.string(from: trip.endDate))
        
        requestURL.httpBody = try JSONEncoder().encode(tripData)
        return try await performNetworkRequest(requestURL, responseType: Trip.self)
        
    }

    func getTrips() async throws -> [Trip] {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        // Check network connection status using networkMonitor; if offline, load trips from cache
        if !networkMonitor.isConnected {
            return tripCacheManager.loadTrips()
        }
        
        var request = URLRequest(url: EndPoints.trips.url)
        request.httpMethod = HTTPMethods.GET.rawValue
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let trips = try await performNetworkRequest(request, responseType: [Trip].self)
            
            tripCacheManager.saveTrips(trips)
            
            return trips
        } catch {
            return tripCacheManager.loadTrips()
        }
        
    }

    func getTrip(withId id: Trip.ID) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.handleTrip("\(id)").url)
        requestURL.httpMethod = HTTPMethods.GET.rawValue
        requestURL.addValue("application/json", forHTTPHeaderField: "accept")
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        let trip = try await performNetworkRequest(requestURL, responseType: Trip.self)
        
        return trip
    }

    func updateTrip(withId id: Trip.ID, and trip: TripUpdate) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.handleTrip("\(id)").url)
        requestURL.httpMethod = HTTPMethods.PUT.rawValue
        requestURL.addValue("application/json", forHTTPHeaderField: "accept")
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withInternetDateTime
        
        let tripData = TripRequest(name: trip.name,
                                   startDate: dateFormatter.string(from: trip.startDate),
                                   endDate: dateFormatter.string(from: trip.endDate))
        
        requestURL.httpBody = try JSONEncoder().encode(tripData)
        
        return try await performNetworkRequest(requestURL, responseType: Trip.self)
    }

    func deleteTrip(withId id: Trip.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleTrip("\(id)").url)
        request.httpMethod = HTTPMethods.DELETE.rawValue
        request.addValue("*/*", forHTTPHeaderField: "accept")
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        try await performVoidNetworkRequest(request)
    }

    func createEvent(with event: EventCreate) async throws -> Event {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.events.url)
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue("application/json", forHTTPHeaderField: "accept")
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withInternetDateTime
        
        let eventData = EventRequest(tripId: event.tripId,
                                     name: event.name,
                                     date: dateFormatter.string(from: event.date),
                                     location: Location(latitude: event.location?.latitude ?? 0,
                                                        longitude: event.location?.longitude ?? 0,
                                                        address: event.location?.address ?? ""),
                                     transitionFromPrevious: event.transitionFromPrevious ?? "")
        
        requestURL.httpBody = try JSONEncoder().encode(eventData)
        
        return try await performNetworkRequest(requestURL, responseType: Event.self)
    }

    func updateEvent(withId id: Event.ID, and event: EventUpdate) async throws -> Event {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleEvent("\(id)").url)
        
        request.httpMethod = HTTPMethods.PUT.rawValue
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withInternetDateTime
        
        let eventData = EventRequest(tripId: nil,
                                     name: event.name,
                                     date: dateFormatter.string(from: event.date),
                                     location: Location(latitude: event.location?.latitude ?? 0,
                                                        longitude: event.location?.longitude ?? 0,
                                                        address: event.location?.address ?? ""),
                                     transitionFromPrevious: event.transitionFromPrevious ?? "")
        
        request.httpBody = try JSONEncoder().encode(eventData)
        
        return try await performNetworkRequest(request, responseType: Event.self)
    }

    func deleteEvent(withId id: Event.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleEvent("\(id)").url)
        
        request.httpMethod = HTTPMethods.DELETE.rawValue
        request.addValue("*/*", forHTTPHeaderField: "accept")
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        try await performVoidNetworkRequest(request)
    }

    func createMedia(with media: MediaCreate) async throws -> Media {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.media.url)
        
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue("application/json", forHTTPHeaderField: "accept")
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        requestURL.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let mediaData = MediaRequest(base64Data: media.base64Data.base64EncodedString(), eventId: media.eventId)
        requestURL.httpBody = try JSONEncoder().encode(mediaData)
        
        return try await performNetworkRequest(requestURL, responseType: Media.self)
    }

    func deleteMedia(withId id: Media.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleMedia("\(id)").url)
        
        request.httpMethod = HTTPMethods.DELETE.rawValue
        request.addValue("*/*", forHTTPHeaderField: "accept")
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        
        try await performVoidNetworkRequest(request)
    }
}

extension JournalServiceLive {
    
    func checkIfTokenExpired() {
        if let currentToken = token,
           isTokenExpired(currentToken) {
            tokenExpired = true
            self.token = nil
        }
    }
    
    private func isTokenExpired(_ token: Token) -> Bool {
        guard let expirationDate = token.expirationDate else {
            return false
        }
        return expirationDate <= Date()
    }
    
    private func createRegisterRequest(fullname: String, email: String, username: String, password: String) throws -> URLRequest {
        var request = URLRequest(url: EndPoints.register.url)
        request.httpMethod = HTTPMethods.POST.rawValue
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let registerRequest = RegisterRequest(fullname: fullname, email: email, username: username, password: password)
        request.httpBody = try JSONEncoder().encode(registerRequest)

        return request
    }

    private func createLoginRequest(username: String, password: String) throws -> URLRequest {
        var request = URLRequest(url: EndPoints.login.url)
        request.httpMethod = HTTPMethods.POST.rawValue
        request.addValue("application/json", forHTTPHeaderField: "accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let loginData = "grant_type=&username=\(username)&password=\(password)"
        request.httpBody = loginData.data(using: .utf8)

        return request
    }

    private func performNetworkRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkError.badResponse
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let object = try decoder.decode(T.self, from: data)
            if var token = object as? Token {
                token.expirationDate = Token.defaultExpirationDate()
                self.token = token
            }
            return object
        } catch {
            throw NetworkError.failedToDecodeResponse
        }
    }

    private func performVoidNetworkRequest(_ request: URLRequest) async throws {
        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            throw NetworkError.badResponse
        }
    }
}
