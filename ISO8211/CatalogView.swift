//
//  CatalogView.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import SwiftUI

struct CatalogView: View {
    @StateObject var provider = CatalogProvider()
    @State private var filePath = "/Users/christopheralford/Downloads/ENC_ROOT/CATALOG.031"
    
    @State private var message = ""

    var body: some View {
        Text("ISO8211 Catalog Reader")
            .onAppear {
                provider.open(filePath: filePath)
            }
    }
}

#Preview {
    CatalogView()
}
