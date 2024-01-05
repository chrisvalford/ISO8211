//
//  CatalogView.swift
//  ISO8211
//
//  Created by Christopher Alford on 26/12/23.
//

import SwiftUI


struct CatalogView: View {
    @StateObject var provider = CatalogProvider()
    @State private var filePath = "/Users/christopheralford/Downloads/ENC_ROOT/US1AK90M/US1AK90M.001"

    @State private var message = ""
    @State var showFileChooser = false

    var body: some View {
        VStack {
            Text("ISO8211 Catalog Reader")
                .font(.largeTitle)
                .padding()
            Text(filePath)
                .font(.footnote)
            Text("\(provider.fileSize)")
                .font(.footnote)
            Button {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK {
                    self.filePath = panel.url?.path() ?? "..."
                }
            } label: {
                Text("Select File")
                    .frame(width: 100)
            }
            .buttonStyle(.borderedProminent)
            .padding(.vertical)
            Button {
                provider.open(filePath: filePath)
            } label: {
                Text("Process")
                    .frame(width: 100)
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    CatalogView()
}
