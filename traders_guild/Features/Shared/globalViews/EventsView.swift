//
//  EventsView.swift
//  traders_guild
//
//  Created by Al Hennessey on 08/10/2025.
//

import SwiftUI


private let monthFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("MMM")
    return df
}()

private let dayFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("d")
    return df
}()

private let timeFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("h:mm a")
    return df
}()


// MARK: - Announcements List View
struct EventsListView: View {
    @Binding var bottomSheetContent: BottomSheetContent?
    let events: [GuildEvent]
    
    var body: some View {
        VStack(spacing: 10) {
            if events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "megaphone")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.whiteText.opacity(0.3))
                    Text("No events yet")
                        .font(.subheadline)
                        .foregroundColor(AppColors.whiteText.opacity(0.5))
                    Text("Check back later for guild updates")
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(events) { event in
                    EventRowView(
                        event: event,
                        onTap: {
                            bottomSheetContent = .event(event)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Events list that triggers a bottom sheet when an item is tapped.
struct EventRowView: View {
//    @Binding var bottomSheetContent: BottomSheetContent?
    let event: GuildEvent
    @State private var isPressed = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Date pill
                VStack(spacing: 4) {
                    Text(monthFormatter.string(from: event.eventDate))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text(dayFormatter.string(from: event.eventDate))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.whiteText)
                }
                .frame(width: 50)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)

                // Event content
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.whiteText)

                    Text(event.content)
                        .font(.caption)
                        .foregroundColor(AppColors.whiteText.opacity(0.6))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                        Text("\(timeFormatter.string(from: event.eventDate)) • \(event.noAttending) attending")
                    }
                    .font(.caption2)
                    .foregroundColor(AppColors.accentColor)
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.whiteText.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isPressed ? 0.1 : 0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppColors.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



/// Detail content for an event presented in a sheet.
struct EventDetailView: View {
//    let id: Int
    let event: GuildEvent

//    init(id: Int) {
//        let safeTimeOffset = abs(id % 168)
//        self.event = GuildEvent(
//            title: "Guild Tournament \(id)",
//            content: "Join us for an exciting guild tournament! Compete against other members, earn reputation points, and climb the leaderboard. Prizes for top performers!",
//            author: "Guild Admin",
//            authorRole: .admin,
//            postedAt: Date().addingTimeInterval(TimeInterval(-safeTimeOffset * 3600)),
//            isImportant: (id % 10) <= 3,
//            noAttending: 34
//        )
//        self.id = id
//    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(spacing: 4) {
                    Text(monthFormatter.string(from: event.eventDate))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.accentColor)
                    Text(dayFormatter.string(from: event.eventDate))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .frame(width: 80)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(timeFormatter.string(from: event.eventDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Label("\(event.noAttending) members attending", systemImage: "person.3.fill")
                    .foregroundColor(AppColors.accentColor)
                Label("Guild Hall", systemImage: "location.fill")
                    .foregroundColor(.secondary)
            }

            Text("Event Description")
                .font(.headline)
                .padding(.top, 8)

            Text(event.content)
                .font(.body)

            Button(action: {}) {
                Text("RSVP to Event")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
    }
}

