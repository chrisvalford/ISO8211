//
//  ISO8211App.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import SwiftUI

@main
struct ISO8211App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
