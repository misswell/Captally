import SwiftUI
import CoreData

struct BookHeaderView: View {
    @EnvironmentObject var bookVM: BookViewModel

    var body: some View {
        if let book = bookVM.currentBook {
            HStack(spacing: 12) {
                Image(systemName: book.icon)
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(book.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
