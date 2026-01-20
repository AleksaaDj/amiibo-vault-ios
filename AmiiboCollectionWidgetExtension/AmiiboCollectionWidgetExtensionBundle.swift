//
//  AmiiboCollectionWidgetExtensionBundle.swift
//  AmiiboCollectionWidgetExtension
//
//  Created by Aleksa Djordjevic on 4. 11. 2025..
//

import WidgetKit
import SwiftUI

@main
struct AmiiboCollectionWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        AmiiboCollectionWidgetExtension()
        AmiiboCollectionWidgetExtensionControl()
        AmiiboCollectionWidgetExtensionLiveActivity()
    }
}
