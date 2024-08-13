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

enum MIMEType: String {
    case JSON = "application/json"
    case form = "application/x-www-form-urlencoded"
}

enum HTTPHeaders: String {
    case accept
    case contentType = "Content-Type"
    case authorization = "Authorization"
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
            return "Your session has expired. Please log in again."
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
    
    func register(username: String, password: String) async throws -> Token {
        let request = try createRegisterRequest(username: username, password: password)
        
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
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        let tripData: [String: Any] = [
            "name": trip.name,
            "start_date": dateFormatter.string(from: trip.startDate),
            "end_date": dateFormatter.string(from: trip.endDate),
        ]
        
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: tripData)
        return try await performNetworkRequest(requestURL, responseType: Trip.self)
        
    }

    func getTrips() async throws -> [Trip] {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        // 3.a Check network connection status using networkMonitor; if offline, load trips from cache
        if !networkMonitor.isConnected {
            return tripCacheManager.loadTrips()
        }
        
        var request = URLRequest(url: EndPoints.trips.url)
        request.httpMethod = HTTPMethods.GET.rawValue
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        
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
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        
        let trip = try await performNetworkRequest(requestURL, responseType: Trip.self)
        
        return trip
    }

    func updateTrip(withId id: Trip.ID, and trip: TripUpdate) async throws -> Trip {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.handleTrip("\(id)").url)
        requestURL.httpMethod = HTTPMethods.PUT.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withInternetDateTime
        
        var tripUpdate: [String: Any] = [
            "name": trip.name,
            "start_date": dateFormatter.string(from: trip.startDate),
            "end_date": dateFormatter.string(from: trip.endDate),
        ]
        
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: tripUpdate)
        return try await performNetworkRequest(requestURL, responseType: Trip.self)
    }

    func deleteTrip(withId id: Trip.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleTrip("\(id)").url)
        request.httpMethod = HTTPMethods.DELETE.rawValue
        request.addValue("*/*", forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        
        try await performVoidNetworkRequest(request)
    }

    func createEvent(with event: EventCreate) async throws -> Event {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.events.url)
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withInternetDateTime
        
        let eventData: [String: Any] = [
            "trip_id": event.tripId,
            "name": event.name,
            "date": dateFormatter.string(from: event.date),
            "location": [
                "latitude": event.location?.latitude ?? 0,
                "longitude": event.location?.longitude ?? 0,
                "address": event.location?.address ?? ""
            ],
            "transition_from_previous": event.transitionFromPrevious ?? ""
        ]
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: eventData)
        
        return try await performNetworkRequest(requestURL, responseType: Event.self)
    }

    func updateEvent(withId id: Event.ID, and event: EventUpdate) async throws -> Event {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleEvent("\(id)").url)
        
        request.httpMethod = HTTPMethods.PUT.rawValue
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = .withInternetDateTime
        
        let eventData: [String: Any] = [
            "name": event.name,
            "date": dateFormatter.string(from: event.date),
            "location": [
                "latitude": event.location?.latitude ?? 0,
                "longitude": event.location?.longitude ?? 0,
                "address": event.location?.address ?? ""
            ],
            "transition_from_previous": event.transitionFromPrevious ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: eventData)
        
        return try await performNetworkRequest(request, responseType: Event.self)
    }

    func deleteEvent(withId id: Event.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleEvent("\(id)").url)
        
        request.httpMethod = HTTPMethods.DELETE.rawValue
        request.addValue("*/*", forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        
        try await performVoidNetworkRequest(request)
    }

    func createMedia(with media: MediaCreate) async throws -> Media {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var requestURL = URLRequest(url: EndPoints.media.url)
        
        requestURL.httpMethod = HTTPMethods.POST.rawValue
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        requestURL.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        requestURL.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)
        
        let mediaData: [String: Any] = [
            "base64_data": media.base64Data.base64EncodedString(),
            "event_id": media.eventId
        ]
        requestURL.httpBody = try JSONSerialization.data(withJSONObject: mediaData)
        
        return try await performNetworkRequest(requestURL, responseType: Media.self)
    }

    func deleteMedia(withId id: Media.ID) async throws {
        guard let token = token else {
            throw NetworkError.invalidValue
        }
        
        var request = URLRequest(url: EndPoints.handleMedia("\(id)").url)
        
        request.httpMethod = HTTPMethods.DELETE.rawValue
        request.addValue("*/*", forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue("Bearer \(token.accessToken)", forHTTPHeaderField: HTTPHeaders.authorization.rawValue)
        
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
    
    private func createRegisterRequest(username: String, password: String) throws -> URLRequest {
        var request = URLRequest(url: EndPoints.register.url)
        request.httpMethod = HTTPMethods.POST.rawValue
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

        let registerRequest = LoginRequest(username: username, password: password)
        request.httpBody = try JSONEncoder().encode(registerRequest)

        return request
    }

    private func createLoginRequest(username: String, password: String) throws -> URLRequest {
        var request = URLRequest(url: EndPoints.login.url)
        request.httpMethod = HTTPMethods.POST.rawValue
        request.addValue(MIMEType.JSON.rawValue, forHTTPHeaderField: HTTPHeaders.accept.rawValue)
        request.addValue(MIMEType.form.rawValue, forHTTPHeaderField: HTTPHeaders.contentType.rawValue)

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
