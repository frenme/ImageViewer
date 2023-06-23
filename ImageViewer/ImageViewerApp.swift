import SwiftUI

@main
struct ImageViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isShow: Bool = false
    
    var body: some View {
        ZStack {
            if isShow {
                ImageViewer(viewModel: .init(urlImages: ["url1", "url2", "url3"])) {
                    isShow = false
                }
            } else {
                Button {
                    withAnimation {
                        isShow.toggle()
                    }
                } label: {
                    Text("tap me")
                }
            }
        }
    }
}
