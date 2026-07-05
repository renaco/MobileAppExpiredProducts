//
//  MobileAppExpiredProductsApp.swift
//  MobileAppExpiredProducts
//
//  Created by Renan Romero Ruiz on 4/07/26.
//

import SwiftUI

@main
struct MobileAppExpiredProductsApp: App {
    @State private var scannedProductStore = ScannedProductStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(scannedProductStore)
        }
    }
}
