import SwiftUI
import Combine

struct ImageViewer: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    
    public init(viewModel: ImageViewerViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        viewModel.onClose = onClose
    }
    
    public var body: some View {
        ZStack {
            Color.black
                .opacity(viewModel.bgOpacity)
                .ignoresSafeArea()
            
            TabView(selection: $viewModel.selectedImage) {
                ForEach(viewModel.images, id: \.self) { model in
                    ZStack {
                        if let image = model.image {
                            ZoomableView(zoomScale: $viewModel.zoomScale, defaultZoom: $viewModel.defaultZoom) {
                                image
                            }
                        } else {
                            Text("Loading")
                        }
                    }
                    .tag(model)
                    .onAppear {
                        viewModel.imageOnAppear(model)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .offset(y: viewModel.offset.height)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                viewModel.closeDidTap()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                    .padding(.top, safeAreaInsets.top)
                    .padding(16)
            }
        }
        .gesture(
            DragGesture()
                .onChanged(viewModel.onChange(value:))
                .onEnded(viewModel.onEnd(value:))
        )
        .onAppear(perform: viewModel.onAppear)
        .ignoresSafeArea(.all)
    }
    
    private var safeAreaInsets: UIEdgeInsets {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets ?? .zero
    }
}

// MARK: - image viewer
private struct ZoomableView<Content: View>: View {
    let content: Content
    @Binding var zoomScale: CGFloat
    @Binding var defaultZoom: CGFloat
    private let updateView = PassthroughSubject<Void, Never>()
    
    init(zoomScale: Binding<CGFloat>, defaultZoom: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._zoomScale = zoomScale
        self._defaultZoom = defaultZoom
        self.content = content()
    }

    var body: some View {
        ZoomableViewRepresentable(zoomScale: $zoomScale, defaultZoom: $defaultZoom, updateView: updateView) {
            content
                .onAppear {
                    updateView.send()
                }
        }
    }
}

private struct ZoomableViewRepresentable<Content: View>: UIViewControllerRepresentable {
    @Binding private var zoomScale: CGFloat
    @Binding private var defaultZoom: CGFloat
    private let updateView: PassthroughSubject<Void, Never>
    private let content: Content
    
    init(
        zoomScale: Binding<CGFloat>,
        defaultZoom: Binding<CGFloat>,
        updateView: PassthroughSubject<Void, Never>,
        @ViewBuilder content: () -> Content
    ) {
        self._zoomScale = zoomScale
        self._defaultZoom = defaultZoom
        self.updateView = updateView
        self.content = content()
    }

    func makeUIViewController(context: Context) -> ViewController {
        ViewController(coordinator: context.coordinator, zoomScale: $zoomScale, defaultZoom: $defaultZoom, updateView: updateView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    func updateUIViewController(_ viewController: ViewController, context: Context) { }

    class ViewController: UIViewController, UIScrollViewDelegate {
        private let coordinator: Coordinator
        private let zoomScale: Binding<CGFloat>
        private let defaultZoom: Binding<CGFloat>
        private let updateView: PassthroughSubject<Void, Never>
        private var cancellables = Set<AnyCancellable>()
        private let scrollView = CenterScrollView()
        private let maxZoomScale: CGFloat = 5
        private var hostedView: UIView { coordinator.hostingController.view }
        private var contentSizeConstraints: [NSLayoutConstraint] = [] {
            willSet { NSLayoutConstraint.deactivate(contentSizeConstraints) }
            didSet { NSLayoutConstraint.activate(contentSizeConstraints) }
        }
        
        init(
            coordinator: Coordinator,
            zoomScale: Binding<CGFloat>,
            defaultZoom: Binding<CGFloat>,
            updateView: PassthroughSubject<Void, Never>
        ) {
            self.coordinator = coordinator
            self.zoomScale = zoomScale
            self.defaultZoom = defaultZoom
            self.updateView = updateView
            super.init(nibName: nil, bundle: nil)
            view = scrollView
            
            scrollView.delegate = self
            scrollView.maximumZoomScale = maxZoomScale
            scrollView.minimumZoomScale = 1
            scrollView.clipsToBounds = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            ])
            
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(sender:)))
            doubleTapGesture.numberOfTapsRequired = 2
            scrollView.addGestureRecognizer(doubleTapGesture)
            
            updateView
                .sink { [weak self] in
                    self?.updateContentView()
                }
                .store(in: &cancellables)
        }
        
        required init?(coder: NSCoder) {
            fatalError()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostedView
        }
        
        override func updateViewConstraints() {
            super.updateViewConstraints()
            let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
            contentSizeConstraints = [
                hostedView.widthAnchor.constraint(equalToConstant: hostedContentSize.width),
                hostedView.heightAnchor.constraint(equalToConstant: hostedContentSize.height),
            ]
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
            scrollView.minimumZoomScale = min(scrollView.bounds.width / hostedContentSize.width, scrollView.bounds.height / hostedContentSize.height)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            self.scrollView.centerView()
            zoomScale.wrappedValue = scrollView.zoomScale
        }
        
        @objc
        private func handleDoubleTap(sender: UITapGestureRecognizer) {
            let scalePoint = sender.location(in: hostedView)
            let zoomScale = scrollView.zoomScale == scrollView.minimumZoomScale ? maxZoomScale : scrollView.minimumZoomScale
            let width = scrollView.bounds.size.width / zoomScale
            let height = scrollView.bounds.size.height / zoomScale
            let rect = CGRect(x: scalePoint.x - (width * 0.5), y: scalePoint.y - (height * 0.5), width: width, height: height)
            scrollView.zoom(to: rect, animated: true)
        }
        
        private func updateContentView() {
            scrollView.zoom(to: hostedView.bounds, animated: false)
            defaultZoom.wrappedValue = scrollView.zoomScale
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
    }
}

private class CenterScrollView: UIScrollView {
    func centerView() {
        subviews[0].frame.origin.x = max(0, bounds.width - subviews[0].frame.width) / 2
        subviews[0].frame.origin.y = max(0, bounds.height - subviews[0].frame.height) / 2
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        centerView()
    }
}
