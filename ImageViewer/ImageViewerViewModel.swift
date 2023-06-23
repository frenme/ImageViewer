import Combine
import SwiftUI

public final class ImageViewerViewModel: ObservableObject {
    @Published var selectedImage: ImageViewerModel = .init(urlImage: nil)
    @Published var zoomScale: CGFloat = 1
    @Published var defaultZoom: CGFloat = 1
    @Published private(set) var images: [ImageViewerModel] = []
    @Published private(set) var bgOpacity: Double = 1
    @Published private(set) var offset: CGSize = .zero
    
    private var cancellables = Set<AnyCancellable>()

    var onClose: (() -> Void)? = nil
    
    var selectedImageIndex: Int {
        (images.firstIndex(of: selectedImage) ?? .zero) + 1
    }
    
    public init(urlImages: [String]) {
        urlImages.forEach {
            images.append(.init(urlImage: $0))
        }
    }
    
    func onAppear() {
        bgOpacity = 1
        offset = .zero
        
        if let model = images.first {
            fetchImage(model)
        }
    }
    
    func imageOnAppear(_ model: ImageViewerModel) {
        fetchImage(model)
    }
    
    func onChange(value: DragGesture.Value) {
        guard defaultZoom == zoomScale else { return }
            
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            offset = value.translation
            
            let progress = offset.height / (UIScreen.main.bounds.height / 2)
            bgOpacity = Double(1 - (progress < .zero ? -progress : progress))
        }
    }
    
    func onEnd(value: DragGesture.Value) {
        let translation = value.translation.height
        
        DispatchQueue.main.async { [weak self] in
            withAnimation {
                if abs(translation) < 200 {
                    self?.bgOpacity = 1
                    self?.offset = .zero
                } else {
                    self?.onClose?()
                }
            }
        }
    }
    
    func closeDidTap() {
        withAnimation {
            onClose?()
        }
    }
    
    private func fetchImage(_ model: ImageViewerModel) {
        guard let url = model.urlImage else { return }
        
        // send request for images...
        images[0].image = Image("image1")
        images[1].image = Image("image2")
    }
}

struct ImageViewerModel: Hashable {
    let id: UUID = .init()
    let urlImage: String?
    var image: Image? = nil
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ImageViewerModel, rhs: ImageViewerModel) -> Bool {
        lhs.id == rhs.id
    }
}
