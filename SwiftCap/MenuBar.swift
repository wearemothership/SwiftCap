//
//  MenuBar.swift
//  SwiftCap
//
//  Created by apple on 2024/4/14.
//

import SwiftUI
import Foundation

struct MenuBar: View {
    @State var recordingStatus: Bool!
    @State var recordingLength = "00:00"

    var body: some View {
        ZStack {
            if recordingStatus {
                Rectangle()
                    .cornerRadius(3)
                    .opacity(0.1)
            }
            HStack(spacing: 2.5) {
                if recordingStatus {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                    Text(recordingLength)
                        .offset(y: -0.5)
                } else {
                    Image("menuBarIcon")
                }
            }
        }
    }
}

#Preview {
    MenuBar()
}
