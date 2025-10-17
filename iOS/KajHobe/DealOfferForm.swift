import SwiftUI

struct DealOfferForm: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)
                
                Text("Deal Offers")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("Deal functionality coming soon")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .padding()
            }
            .navigationTitle("Make Offer")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

#Preview {
    DealOfferForm(isPresented: .constant(true))
} 