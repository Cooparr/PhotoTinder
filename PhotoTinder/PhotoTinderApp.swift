//
//  PhotoTinderApp.swift
//  PhotoTinder
//
//  Created by Alexander Cooper on 19/08/2026.
//

import SwiftData
import SwiftUI

@main
struct PhotoTinderApp: App {
    @State private var photoLibrary = PhotoLibraryService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(photoLibrary)
        }
        .modelContainer(for: AssetDecision.self)
    }
}
