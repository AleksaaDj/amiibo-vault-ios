//
//  AmiiboCollectionWidgetExtensionLiveActivity.swift
//  AmiiboCollectionWidgetExtension
//
//  Created by Aleksa Djordjevic on 4. 11. 2025..
//

import ActivityKit
import WidgetKit
import SwiftUI

struct AmiiboCollectionWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct AmiiboCollectionWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AmiiboCollectionWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension AmiiboCollectionWidgetExtensionAttributes {
    fileprivate static var preview: AmiiboCollectionWidgetExtensionAttributes {
        AmiiboCollectionWidgetExtensionAttributes(name: "World")
    }
}

extension AmiiboCollectionWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: AmiiboCollectionWidgetExtensionAttributes.ContentState {
        AmiiboCollectionWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: AmiiboCollectionWidgetExtensionAttributes.ContentState {
         AmiiboCollectionWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: AmiiboCollectionWidgetExtensionAttributes.preview) {
   AmiiboCollectionWidgetExtensionLiveActivity()
} contentStates: {
    AmiiboCollectionWidgetExtensionAttributes.ContentState.smiley
    AmiiboCollectionWidgetExtensionAttributes.ContentState.starEyes
}
