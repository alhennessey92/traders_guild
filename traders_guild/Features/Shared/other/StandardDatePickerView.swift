//
//  StandardDatePickerView.swift
//  traders_guild
//
//  Created by Al Hennessey on 22/09/2025.
//
import SwiftUI


struct StandardDatePickerView: View {
    let title: String
    @Binding var date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label above
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.greyText)
                .padding(.horizontal)
            
            // Custom "textfield-style" background
            HStack {
                // Display selected date as text
                Text(date, style: .date)
                    .foregroundColor(AppColors.whiteText)
                Spacer()
                
                // Calendar icon
                Image(systemName: "calendar")
                    .foregroundColor(AppColors.whiteText)
            }
            .padding(.horizontal, 12)
            .frame(height: 50) // same as textfields
            .background(AppColors.unhighlightedTextBoxBackground)
            .opacity(0.6)
            .cornerRadius(10)
            .padding(.horizontal)
            .onTapGesture {
                // Show the native date picker when tapped
                showDatePicker.toggle()
            }
        }
        .sheet(isPresented: $showDatePicker) {
        
            ZStack{
                Color(AppColors.whiteText)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .foregroundColor(AppColors.whiteText)
                    .colorScheme(.dark)
                    
                    
                    
                    StandardButton(
                        title: "Reset",
                        backgroundColor: AppColors.whiteText,
                        foregroundColor: AppColors.gradientBackgroundDark
                    ){
                        showDatePicker = false
                    }
                    
                    .padding()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 40)
                        .fill(AppColors.unhighlightedTextBoxBackground)
                )
                .padding()
            }
            .padding(.horizontal, 16)
            .presentationCornerRadius(30)
            
            
            
            
        }
        
    }
    
    @State private var showDatePicker = false
}

#Preview {
    StandardDatePickerView(title: "Date of Birth", date: .constant(Date()))
}
