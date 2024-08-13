//
//  NetworkMonitor.swift
//  TripJournal
//
//  Created by Nguyen Thanh Long on 11/8/24.
//

import Combine
import Network

class NetworkMonitor: ObservableObject {
    // Initialize NWPathMonitor instance to monitor network changes
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = true
    @Published var usingCellular: Bool = false

    private var previousIsConnected: Bool = true

    init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let newIsConnected = path.status == .satisfied
                // Update isConnected and previousIsConnected with newIsConnected value only if there is an actual change in the network status
                if newIsConnected != self.previousIsConnected {
                    self.isConnected = newIsConnected
                    self.previousIsConnected = newIsConnected
                }
                
                self.usingCellular = path.isExpensive
            }
        }
        monitor.start(queue: queue)
    }
}
