import SwiftUI

struct TripList: View {
    @Binding var addAction: () -> Void

    @State private var trips: [Trip] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var tripFormMode: TripForm.Mode?
    @State private var isLogoutConfirmationDialogPresented = false
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.journalService) private var journalService

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient.background
                .edgesIgnoringSafeArea(.all)
            NavigationStack {
                content
                    .navigationTitle("Trips")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(content: toolbar)
                    .onAppear {
                        addAction = { tripFormMode = .add }
                    }
                    .navigationDestination(for: Trip.self) { trip in
                        TripDetails(trip: trip, addAction: $addAction) {
                            Task {
                                await fetchTrips()
                            }
                        }
                    }
                    .sheet(item: $tripFormMode) { mode in
                        TripForm(mode: mode) {
                            Task {
                                await fetchTrips()
                            }
                        }
                    }
                    .confirmationDialog(
                        "Log out?",
                        isPresented: $isLogoutConfirmationDialogPresented,
                        titleVisibility: .visible,
                        actions: {
                            Button("Log out", role: .destructive) {
                                journalService.logOut()
                            }
                        },
                        message: {
                            Text("You will need to log in to access your account again.")
                        }
                    )
                    .loadingOverlay(isLoading)
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .background {
                    checkSession()
                }
            }
            .task {
                await fetchTrips()
            }
        }
    }

    // MARK: - Views

    @ToolbarContentBuilder
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Log out", systemImage: "power", role: .destructive) {
                isLogoutConfirmationDialogPresented = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error {
            errorView(for: error)
        } else if trips.isEmpty && !isLoading {
            emptyView
        } else {
            listView
        }
    }

    private func errorView(for error: Error) -> some View {
        ContentUnavailableView(
            label: {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
            },
            description: {
                Text(error.localizedDescription)
            },
            actions: {
                Button("Try Again") {
                    Task {
                        await fetchTrips()
                    }
                }
            }
        )
    }

    private var emptyView: some View {
        ContentUnavailableView(
            label: {
                Label("Nothing here yet!", systemImage: "face.dashed")
                    .labelStyle(.titleOnly)
            },
            description: {
                Text("Add a trip to start your trip journal.")
            }
        )
    }

    private var listView: some View {
        List {
            ForEach(trips) { trip in
                TripCell(
                    trip: trip,
                    edit: {
                        tripFormMode = .edit(trip)
                    },
                    delete: {
                        Task {
                            await deleteTrip(withId: trip.id)
                        }
                    }
                )
            }
        }
        .refreshable {
            await fetchTrips()
        }
    }
    
    private func checkSession() {
        journalService.checkIfTokenExpired()
    }

    // MARK: - Networking

    private func fetchTrips() async {
        if trips.isEmpty {
            isLoading = true
        }
        error = nil
        do {
            trips = try await journalService.getTrips()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func deleteTrip(withId id: Trip.ID) async {
        isLoading = true
        do {
            try await journalService.deleteTrip(withId: id)
            await fetchTrips()
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

#Preview {
    struct Preview: View {
        @State private var addAction: () -> Void = {  }
        
        var body: some View {
            TripList(addAction: $addAction)
        }
    }
    
    return Preview()
}
