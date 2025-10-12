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
                    
                    let role = event.authorRole ?? .member
                    let authorName = event.authorName ?? "Unknown"
                    HStack(spacing: 4) {
                        Text("Hosted by")
                            .font(.caption2)
                            .foregroundColor(AppColors.whiteText.opacity(0.6))
                        Text(authorName)
                            .font(.caption2)
                            .foregroundColor(AppColors.whiteText)
                            .fontWeight(.medium)
                        Circle()
                            .fill(AppColors.whiteText.opacity(0.7))
                            .frame(width: 3, height: 3)
                            .padding(.top, 1)
                            .padding(.leading, 3)
                            .padding(.trailing, 3)
                        Text(role.rawValue)
                            .font(.caption2)
                            .foregroundColor(role.foregroundColor)
                            .fontWeight(role.fontWeight)
                        Spacer(minLength: 0)
                    }
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
                        RoundedRectangle(cornerRadius: 14) // Change this to is viewed by the user to show the vorder, indicating a new unseen event
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 16) {
                
                
                // start of content
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
                        
                        let role = event.authorRole ?? .member
                        let authorName = event.authorName ?? "Unknown"
                        HStack(spacing: 8) {
                            if role != .member {
                                Text(role.rawValue.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        role == .admin ? Color.red.opacity(0.8) : AppColors.accentColor.opacity(0.8)
                                    )
                                    .cornerRadius(4)
                            }
                            Text("Hosted by \(authorName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                
                
                Spacer(minLength: 0)
                
                Divider()
                    
                
                HStack(spacing: 8) {
                    DrawerActionButton(
                        imageName: "nosign",
                        backgroundColor: AppColors.bearCandleRed.opacity(0.3),
                        foregroundColor: AppColors.whiteText,
                        strokeColor: AppColors.bearCandleRed.opacity(0.6),
                        strokeWidth: 0.5,
                        action: { }
                    )
                    
                    Spacer()
                    
                    DrawerActionButton(
                        imageName: "person.fill.badge.plus",
                        backgroundColor: AppColors.whiteText.opacity(0.05),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: { }
                    )

                    DrawerActionButton(
                        title: "Chat",
                        imageName: "message.fill",
                        backgroundColor: AppColors.whiteText.opacity(0.05),
                        foregroundColor: AppColors.whiteText.opacity(0.8),
                        strokeColor: AppColors.whiteText.opacity(0.3),
                        strokeWidth: 0.5,
                        action: { }
                    )
                }
                
                .padding(.bottom, 20)
                
                
                // END OF CONTENT 
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 30)
            .padding(.horizontal)
            
            // Floating dismiss button overlaid on top
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.trailing, 16)
        }
    }
}

