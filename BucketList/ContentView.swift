//
//  Copyright © 2019 Peter Barclay. All rights reserved.
//

import LocalAuthentication
import MapKit
import SwiftUI

struct ContentView: View {
    private enum AlertType {
        case placeDetails
        case error
    }
    
    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var locations = [CodableMKPointAnnotation]()
    @State private var selectedPlace: MKPointAnnotation?
    @State private var showingPlaceDetails = false
    @State private var showingAlert = false
    @State private var activeAlertType: AlertType = .error
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingEditScreen = false
    @State private var isUnlocked = false

    var body: some View {
        let showingPlaceDetailsBinding = Binding(
            get: { self.showingPlaceDetails },
            set: { self.showPlaceDetailsAlert($0) }
        )
        return ZStack {
            if self.isUnlocked {
                PacesMapView(centerCoordinate: $centerCoordinate,
                             selectedPlace: $selectedPlace,
                             showingPlaceDetails: showingPlaceDetailsBinding,
                             locations: $locations,
                             showingEditScreen: $showingEditScreen)
            } else {
                Button("Unlock Places") {
                    self.authenticate()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(Color.white)
                .clipShape(Capsule())
            }
        }
        .onAppear(perform: loadData)
        .alert(isPresented: $showingAlert) {
            switch activeAlertType {
            case .placeDetails:
                return Alert(title: Text(alertTitle),
                             message: Text(alertMessage),
                             primaryButton: .default(Text("OK")),
                             secondaryButton: .default(Text("Edit")) {
                    self.showingEditScreen = true
                })
            case .error:
                return Alert(title: Text(alertTitle),
                             message: Text(alertMessage))
            }
        }
        .sheet(isPresented: $showingEditScreen, onDismiss: saveData) {
            if self.selectedPlace != nil {
                EditView(placemark: self.selectedPlace!)
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func loadData() {
        let filename = getDocumentsDirectory().appendingPathComponent("SavedPlaces")

        do {
            let data = try Data(contentsOf: filename)
            locations = try JSONDecoder().decode([CodableMKPointAnnotation].self, from: data)
        } catch {
            print("Unable to load saved data.")
        }
    }
    
    func saveData() {
        do {
            let filename = getDocumentsDirectory().appendingPathComponent("SavedPlaces")
            let data = try JSONEncoder().encode(self.locations)
            try data.write(to: filename,
                           options: [
                .atomicWrite,
                .completeFileProtection
            ])
        } catch {
            print("Unable to save data.")
        }
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                     error: &error) {
            let reason = "Please authenticate yourself to unlock your places."

            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, authenticationError in

                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else {
                        self.showError(title: "Error",
                                       message: "Authentication Failed, Please try again.")
                    }
                }
            }
        } else {
            showError(title: "Device Not Supported",
                      message: "Your Device does not support Biometrics Authentication.")
        }
    }
    
    private func showError(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.activeAlertType = .error
        self.showingAlert = true
    }
    
    private func showPlaceDetailsAlert(_ show: Bool) {
        self.activeAlertType = .placeDetails
        self.alertTitle = self.selectedPlace?.title ?? "Unknown"
        self.alertMessage = self.selectedPlace?.subtitle ?? "Missing place information."
        self.showingPlaceDetails = show
        self.showingAlert = show
    }
}

struct PacesMapView: View {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var selectedPlace: MKPointAnnotation?
    @Binding var showingPlaceDetails: Bool
    @Binding var locations: [CodableMKPointAnnotation]
    @Binding var showingEditScreen: Bool

    var body: some View {
        ZStack {
            MapView(centerCoordinate: $centerCoordinate,
                    selectedPlace: $selectedPlace,
                    showingPlaceDetails: $showingPlaceDetails,
                    annotations: locations)
            Circle()
                .fill(Color.blue)
                .opacity(0.3)
                .frame(width: 32, height: 32)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        let newLocation = CodableMKPointAnnotation()
                        newLocation.title = "Example location"
                        newLocation.coordinate = self.centerCoordinate
                        self.locations.append(newLocation)
                        self.selectedPlace = newLocation
                        self.showingEditScreen = true
                    }) {
                        Image(systemName: "plus")
                            .padding()
                            .background(Color.black.opacity(0.75))
                            .foregroundColor(.white)
                            .font(.title)
                            .clipShape(Circle())
                            .padding(.trailing)
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
