//
//  ContentView.swift
//  test-remoteide
//
//  Created by Challa Somesh on 30/03/26.
//

import SwiftUI

struct ContentView: View {
    @State private var labState = LiquidGlassLabState()

    var body: some View {
        LiquidGlassPlaygroundView(state: labState)
    }
}

#Preview {
    ContentView()
}
