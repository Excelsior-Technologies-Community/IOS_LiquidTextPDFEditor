import UIKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - Models

struct PDFTextEdit {
    let pageIndex: Int
    let originalText: String
    var newText: String
    let bounds: CGRect
}

class ViewController: UIViewController {

    // MARK: IBOutlets — must match storyboard
    @IBOutlet weak var pdfContainerView: UIView!
    @IBOutlet weak var editorContainerView: UIView!

    // Child VCs
    private var pdfVC: PDFViewContainer!
    private var workspaceVC: WorkspaceEmbedVC!
    private var searchResults: [PDFSelection] = []
    private var currentSearchIndex = 0
    // Edit mode
    private var isEditMode = false
    private var pdfEdits: [PDFTextEdit] = []
    private var editOverlay: PDFEditOverlayView!
    private var editTapCatcher: UIView!
    private var isImageSelectionMode = false
    private var selectionStartPoint: CGPoint?
    private let selectionLayer = CAShapeLayer()
    private var nextSearchButton: UIBarButtonItem!
    private var prevSearchButton: UIBarButtonItem!
    // Drag state
    private var dragGhost: UILabel?
    private var dragText: String?
    private var thumbnailView: PDFThumbnailView!
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPDFSide()
        setupWorkspaceSide()
        setupEditOverlay()
        setupDragGesture()
        prevSearchButton = UIBarButtonItem(
             image: UIImage(systemName: "chevron.up"),
             style: .plain,
             target: self,
             action: #selector(searchPrevious)
         )
         
         nextSearchButton = UIBarButtonItem(
             image: UIImage(systemName: "chevron.down"),
             style: .plain,
             target: self,
             action: #selector(searchNext)
         )
         
         // Initially hidden
         prevSearchButton.isEnabled = false
         nextSearchButton.isEnabled = false
        
       let longPress = UILongPressGestureRecognizer(target: self,
                                                     action: #selector(workspaceLongPressed(_:)))
        editorContainerView.addGestureRecognizer(longPress)
  
        let pan = UIPanGestureRecognizer(target: self,
                                            action: #selector(handlePDFSelection(_:)))
           pdfContainerView.addGestureRecognizer(pan)

           selectionLayer.strokeColor = UIColor.systemBlue.cgColor
           selectionLayer.lineWidth = 2
           selectionLayer.fillColor = UIColor.clear.cgColor
           pdfContainerView.layer.addSublayer(selectionLayer)
    }
    @IBOutlet weak var thumbnailContainerView: UIView!
    @IBAction func searchTextTapped(_ sender: Any) {
        showSearchAlert()
    }
    @IBAction func searchNext(_ sender: Any) {
        guard !searchResults.isEmpty else { return }
        
        currentSearchIndex += 1
        if currentSearchIndex >= searchResults.count {
            currentSearchIndex = 0
        }
        
        goToSearchResult(index: currentSearchIndex)
    }
    @IBAction func searchPrevious(_ sender: Any) {
        guard !searchResults.isEmpty else { return }
        
        currentSearchIndex -= 1
        if currentSearchIndex < 0 {
            currentSearchIndex = searchResults.count - 1
        }
        
        goToSearchResult(index: currentSearchIndex)
    }
    
    private func showSearchAlert() {
        
        let alert = UIAlertController(title: "Search PDF",
                                      message: "Enter keyword",
                                      preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "Enter text..."
        }
        
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            guard let self = self,
                  let keyword = alert.textFields?.first?.text,
                  !keyword.isEmpty else { return }
            
            self.searchInPDF(keyword)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func searchInPDF(_ keyword: String) {
        
        guard let pdfView = pdfVC.pdfView,
              let document = pdfView.document else { return }
        
        searchResults = document.findString(keyword,
                                            withOptions: .caseInsensitive)
        
        guard !searchResults.isEmpty else {
            showToast("No results found")
            hideSearchNavigationButtons()
            return
        }
        
        currentSearchIndex = 0
        highlightSearchResults()
        goToSearchResult(index: 0)
        
        showSearchNavigationButtons()
        showToast("Found \(searchResults.count) matches")
    }
    private func showSearchNavigationButtons() {
        prevSearchButton.isEnabled = true
        nextSearchButton.isEnabled = true
        
        navigationItem.rightBarButtonItems?.append(prevSearchButton)
        navigationItem.rightBarButtonItems?.append(nextSearchButton)
    }

    private func hideSearchNavigationButtons() {
        prevSearchButton.isEnabled = false
        nextSearchButton.isEnabled = false
        
        navigationItem.rightBarButtonItems =
            navigationItem.rightBarButtonItems?.filter {
                $0 !== prevSearchButton && $0 !== nextSearchButton
            }
    }
    
    private func highlightSearchResults() {
        
        guard let pdfView = pdfVC.pdfView else { return }
        
        pdfView.highlightedSelections = searchResults
    }
    private func goToSearchResult(index: Int) {
        
        guard index >= 0,
              index < searchResults.count,
              let pdfView = pdfVC.pdfView else { return }
        
        let selection = searchResults[index]
        
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.go(to: selection)
    }
    @IBAction func highlightSelectedText(_ sender: Any) {

        guard let pdfView = pdfVC.pdfView,
              let selection = pdfView.currentSelection,
              let page = selection.pages.first else {
            showToast("Select text first")
            return
        }

        addHighlight(to: selection, on: page)

        pdfView.clearSelection()
    }
    private func addHighlight(to selection: PDFSelection, on page: PDFPage) {

        let boundsArray = selection.selectionsByLine()

        for lineSelection in boundsArray {

            guard let lineBounds = lineSelection.bounds(for: page) as CGRect? else { continue }

            let highlight = PDFAnnotation(bounds: lineBounds,
                                          forType: .highlight,
                                          withProperties: nil)

            highlight.color = UIColor.yellow.withAlphaComponent(0.4)

            page.addAnnotation(highlight)
        }

        pdfVC.pdfView.setNeedsDisplay()
    }
    @IBAction func imageSelectTapped(_ sender: UIButton) { 
        isImageSelectionMode.toggle()
    }
    
//    @IBAction func imageSelectTapped(_ sender: UIBarButtonItem) {
//        isImageSelectionMode.toggle()
//    }
    @objc private func workspaceLongPressed(_ gesture: UILongPressGestureRecognizer) {
        
        if gesture.state != .began { return }
        
        let location = gesture.location(in: editorContainerView)
        
        showCustomTextInput(at: location)
    }
    
    @objc private func handlePDFSelection(_ gesture: UIPanGestureRecognizer) {

        guard isImageSelectionMode else { return }

        let location = gesture.location(in: pdfContainerView)

        switch gesture.state {

        case .began:
            selectionStartPoint = location

        case .changed:
            guard let start = selectionStartPoint else { return }

            let rect = CGRect(x: min(start.x, location.x),
                              y: min(start.y, location.y),
                              width: abs(start.x - location.x),
                              height: abs(start.y - location.y))

            selectionLayer.path = UIBezierPath(rect: rect).cgPath

        case .ended:
            guard let start = selectionStartPoint else { return }

            let rect = CGRect(x: min(start.x, location.x),
                              y: min(start.y, location.y),
                              width: abs(start.x - location.x),
                              height: abs(start.y - location.y))

            captureSelectedPDFArea(rect)

            selectionLayer.path = nil
            selectionStartPoint = nil
            isImageSelectionMode = false

        default:
            break
        }
    }
    
    
    private func captureSelectedPDFArea(_ rect: CGRect) {

        guard let pdfView = pdfVC.pdfView else { return }

        // Convert rect from pdfContainerView → pdfView
        let rectInPDFView = pdfContainerView.convert(rect, to: pdfView)

        // Snapshot ONLY visible content
        let renderer = UIGraphicsImageRenderer(bounds: rectInPDFView)

        let image = renderer.image { ctx in
            pdfView.drawHierarchy(in: pdfView.bounds, afterScreenUpdates: true)
        }

        workspaceVC.addImageBlock(image)
    }
    private func addImageBlockToWorkspace(_ image: UIImage) {
        workspaceVC.addImageBlock(image)
    }
    private func showCustomTextInput(at point: CGPoint) {
        
        let alert = UIAlertController(title: "Add Custom Text",
                                      message: "Enter your text",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Enter text..."
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { _ in
            
            guard let text = alert.textFields?.first?.text,
                  !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            
            self.createCustomBlock(text: text, at: point)
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func createCustomBlock(text: String, at point: CGPoint) {
        workspaceVC.addText(text)
    }
    private func addCustomTextToWorkspace(_ text: String) {
        
        let width: CGFloat = 180
        let height: CGFloat = 60
        
        let x = (editorContainerView.bounds.width - width) / 2
        let y = (editorContainerView.bounds.height - height) / 2
        
        let block = TextBlockView(frame: CGRect(x: x,
                                                y: y,
                                                width: width,
                                                height: height))
        
        block.textView.text = text
        
        editorContainerView.addSubview(block)
    }
    
     
    // MARK: - Setup PDF side

    private func setupPDFSide() {
        pdfVC = PDFViewContainer()
        addChild(pdfVC)
        pdfVC.view.translatesAutoresizingMaskIntoConstraints = false
        pdfContainerView.addSubview(pdfVC.view)
        NSLayoutConstraint.activate([
            pdfVC.view.topAnchor.constraint(equalTo: pdfContainerView.topAnchor),
            pdfVC.view.bottomAnchor.constraint(equalTo: pdfContainerView.bottomAnchor),
            pdfVC.view.leadingAnchor.constraint(equalTo: pdfContainerView.leadingAnchor),
            pdfVC.view.trailingAnchor.constraint(equalTo: pdfContainerView.trailingAnchor)
        ])
        pdfVC.didMove(toParent: self)
        pdfVC.onTextSelected = { [weak self] text in self?.handleTextSelected(text) }
        setupThumbnails()
    }

    // MARK: - Setup Workspace side

    private func setupWorkspaceSide() {
        workspaceVC = WorkspaceEmbedVC()
        addChild(workspaceVC)
        workspaceVC.view.translatesAutoresizingMaskIntoConstraints = false
        editorContainerView.addSubview(workspaceVC.view)
        NSLayoutConstraint.activate([
            workspaceVC.view.topAnchor.constraint(equalTo: editorContainerView.topAnchor),
            workspaceVC.view.bottomAnchor.constraint(equalTo: editorContainerView.bottomAnchor),
            workspaceVC.view.leadingAnchor.constraint(equalTo: editorContainerView.leadingAnchor),
            workspaceVC.view.trailingAnchor.constraint(equalTo: editorContainerView.trailingAnchor)
        ])
        workspaceVC.didMove(toParent: self)
        workspaceVC.onBlockAction = { [weak self] bv, action in
            self?.handleBlockAction(bv, action: action)
        }
    }

    // MARK: - Edit overlay setup
    private func setupThumbnails() {

        guard let pdfView = pdfVC.pdfView else { return }

        thumbnailView = PDFThumbnailView()
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.pdfView = pdfView
        thumbnailView.layoutMode = .vertical
        thumbnailView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        thumbnailView.thumbnailSize = CGSize(width: 80, height: 120)

        thumbnailContainerView.addSubview(thumbnailView)

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: thumbnailContainerView.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: thumbnailContainerView.bottomAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: thumbnailContainerView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: thumbnailContainerView.trailingAnchor)
        ])
    }
    private func setupEditOverlay() {
        // Yellow highlight overlay — non-interactive, just visual
        editOverlay = PDFEditOverlayView()
        editOverlay.translatesAutoresizingMaskIntoConstraints = false
        pdfContainerView.addSubview(editOverlay)

        // Tap catcher — active only in edit mode, sits on top of everything
        editTapCatcher = UIView()
        editTapCatcher.backgroundColor = .clear
        editTapCatcher.isUserInteractionEnabled = false
        editTapCatcher.translatesAutoresizingMaskIntoConstraints = false
        pdfContainerView.addSubview(editTapCatcher)

        for v in [editOverlay!, editTapCatcher!] as [UIView] {
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: pdfContainerView.topAnchor),
                v.bottomAnchor.constraint(equalTo: pdfContainerView.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: pdfContainerView.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: pdfContainerView.trailingAnchor)
            ])
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(editTapFired(_:)))
        editTapCatcher.addGestureRecognizer(tap)
    }

    // MARK: - Drag gesture setup
    // We use a custom UIView that overrides touch methods directly.
    // This bypasses all UIGestureRecognizer conflicts with PDFKit completely.
    private var dragInterceptView: DragInterceptView!

    private func setupDragGesture() {
        dragInterceptView = DragInterceptView()
        dragInterceptView.translatesAutoresizingMaskIntoConstraints = false
        dragInterceptView.backgroundColor = .clear
        // In normal mode this sits on top of pdfContainerView intercepting touches
        // In edit mode we hide it so editTapCatcher works instead
        pdfContainerView.addSubview(dragInterceptView)
        // Must be BELOW editTapCatcher — insert at index 1 (above pdfVC.view, below overlays)
        pdfContainerView.insertSubview(dragInterceptView, at: 1)
        NSLayoutConstraint.activate([
            dragInterceptView.topAnchor.constraint(equalTo: pdfContainerView.topAnchor),
            dragInterceptView.bottomAnchor.constraint(equalTo: pdfContainerView.bottomAnchor),
            dragInterceptView.leadingAnchor.constraint(equalTo: pdfContainerView.leadingAnchor),
            dragInterceptView.trailingAnchor.constraint(equalTo: pdfContainerView.trailingAnchor)
        ])
        dragInterceptView.onLongPress = { [weak self] loc in self?.dragBegan(at: loc) }
        dragInterceptView.onMove = { [weak self] loc in self?.dragMoved(to: loc) }
        dragInterceptView.onEnd = { [weak self] loc in self?.dragEnded(at: loc) }
        dragInterceptView.onCancel = { [weak self] in self?.dragCancelled() }
    }

    // MARK: - Drag callbacks (called by DragInterceptView touch overrides)

    func dragBegan(at locInPDFContainer: CGPoint) {
        guard !isEditMode else { return }
        let pdfView = pdfVC.pdfView!
        let locInPDFView = pdfContainerView.convert(locInPDFContainer, to: pdfView)
        guard let page = pdfView.page(for: locInPDFView, nearest: true) else { return }
        let pagePoint = pdfView.convert(locInPDFView, to: page)
        guard let selection = page.selectionForWord(at: pagePoint),
              let word = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !word.isEmpty else { return }

        pdfView.setCurrentSelection(selection, animate: false)
        dragText = word

        let locInWindow = pdfContainerView.convert(locInPDFContainer, to: nil)
        let ghost = UILabel()
        ghost.text = word
        ghost.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        ghost.textColor = .black
        ghost.backgroundColor = .white
        ghost.textAlignment = .center
        ghost.layer.cornerRadius = 10
        ghost.layer.shadowColor = UIColor.black.cgColor
        ghost.layer.shadowOpacity = 0.3
        ghost.layer.shadowRadius = 8
        ghost.layer.shadowOffset = CGSize(width: 0, height: 4)
        ghost.layer.masksToBounds = false
        let w = max(120, CGFloat(word.count) * 11 + 40)
        ghost.frame = CGRect(x: locInWindow.x - w/2, y: locInWindow.y - 34, width: w, height: 44)
        ghost.alpha = 0
        view.window?.addSubview(ghost)
        dragGhost = ghost
        UIView.animate(withDuration: 0.15) {
            ghost.alpha = 1
            ghost.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }
    }

    func dragMoved(to locInPDFContainer: CGPoint) {
        guard let ghost = dragGhost else { return }
        let locInWindow = pdfContainerView.convert(locInPDFContainer, to: nil)
        ghost.center = CGPoint(x: locInWindow.x, y: locInWindow.y - 34)
        let locInEditor = pdfContainerView.convert(locInPDFContainer, to: editorContainerView)
        let over = editorContainerView.bounds.contains(locInEditor)
        UIView.animate(withDuration: 0.1) {
            self.editorContainerView.backgroundColor = over
                ? UIColor(red: 0.8, green: 0.93, blue: 1.0, alpha: 1.0)
                : UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1.0)
            ghost.transform = over
                ? CGAffineTransform(scaleX: 0.85, y: 0.85)
                : CGAffineTransform(scaleX: 1.05, y: 1.05)
        }
    }

    func dragEnded(at locInPDFContainer: CGPoint) {
        let locInEditor = pdfContainerView.convert(locInPDFContainer, to: editorContainerView)
        let over = editorContainerView.bounds.contains(locInEditor)
        UIView.animate(withDuration: 0.2) {
            self.editorContainerView.backgroundColor = UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1.0)
        }
        if over, let text = dragText {
            workspaceVC.addText(text)
            UIView.animate(withDuration: 0.2, animations: {
                self.dragGhost?.alpha = 0
                self.dragGhost?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            }) { _ in self.dragGhost?.removeFromSuperview() }
        } else {
            UIView.animate(withDuration: 0.15) { self.dragGhost?.alpha = 0 } completion: { _ in
                self.dragGhost?.removeFromSuperview()
            }
        }
        dragGhost = nil; dragText = nil
    }

    func dragCancelled() {
        UIView.animate(withDuration: 0.15) { self.dragGhost?.alpha = 0 } completion: { _ in
            self.dragGhost?.removeFromSuperview()
        }
        dragGhost = nil; dragText = nil
        UIView.animate(withDuration: 0.2) {
            self.editorContainerView.backgroundColor = UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1.0)
        }
    }

    // MARK: - Edit mode tap handler

    @objc private func editTapFired(_ g: UITapGestureRecognizer) {
        guard isEditMode else { return }

        let locInContainer = g.location(in: pdfContainerView)
        let pdfView = pdfVC.pdfView!
        let locInPDFView = pdfContainerView.convert(locInContainer, to: pdfView)

        guard let page = pdfView.page(for: locInPDFView, nearest: true) else { return }
        let pagePoint = pdfView.convert(locInPDFView, to: page)
        guard let selection = page.selectionForWord(at: pagePoint),
              let word = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !word.isEmpty else { return }

        pdfView.setCurrentSelection(selection, animate: true)

        let pageBounds = selection.bounds(for: page)
        let viewBounds = pdfView.convert(pageBounds, from: page)
        let containerBounds = pdfView.convert(viewBounds, to: pdfContainerView)
        editOverlay.showHighlight(at: containerBounds.insetBy(dx: -4, dy: -3))

        let pageIndex = pdfView.document?.index(for: page) ?? 0

        let alert = UIAlertController(title: "Edit Text",
                                      message: "Original: \(word)",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = word
            tf.font = UIFont.systemFont(ofSize: 16)
            tf.clearButtonMode = .always
            tf.autocorrectionType = .no
            DispatchQueue.main.async { tf.selectAll(nil) }
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newText = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newText.isEmpty, newText != word else {
                self?.editOverlay.clearAll()
                return
            }
            self.editOverlay.clearAll()
            let edit = PDFTextEdit(pageIndex: pageIndex, originalText: word,
                                   newText: newText, bounds: pageBounds)
            self.pdfEdits.append(edit)
            self.applyEdit(page: page, edit: edit)
            self.showToast("Updated: \(word) → \(newText)")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.editOverlay.clearAll()
        })
        present(alert, animated: true)
    }

    // MARK: - Apply PDF edit

    private func applyEdit(page: PDFPage, edit: PDFTextEdit) {
        // Remove old annotations at this location
        page.annotations.filter { $0.bounds.intersects(edit.bounds) }
            .forEach { page.removeAnnotation($0) }

        // White cover over original text
        let cover = PDFAnnotation(bounds: edit.bounds, forType: .square, withProperties: nil)
        cover.color = .clear
        cover.interiorColor = .white
        let nb = PDFBorder(); nb.lineWidth = 0; cover.border = nb
        page.addAnnotation(cover)

        // New text on top
        let textBounds = edit.bounds.insetBy(dx: -2, dy: -1)
        let ta = PDFAnnotation(bounds: textBounds, forType: .freeText, withProperties: nil)
        ta.contents = edit.newText
        ta.font = UIFont.systemFont(ofSize: max(8, edit.bounds.height * 0.75))
        ta.fontColor = .black
        ta.color = .clear
        ta.interiorColor = .clear
        let tb = PDFBorder(); tb.lineWidth = 0; ta.border = tb
        page.addAnnotation(ta)

        pdfVC.pdfView.layoutDocumentView()
        pdfVC.pdfView.setNeedsDisplay()
    }

    // MARK: - Toggle Edit Mode

    @IBAction func editPDFMode(_ sender: Any) {
        isEditMode ? turnOffEditMode() : turnOnEditMode()
    }

    private func turnOnEditMode() {
        isEditMode = true
        pdfVC.pdfView.isUserInteractionEnabled = false
        editTapCatcher.isUserInteractionEnabled = true
        dragInterceptView.isUserInteractionEnabled = false  // disable drag in edit mode
        showToast("✏️ Edit Mode ON — tap any word")
        UIView.animate(withDuration: 0.2) {
            self.pdfContainerView.layer.borderWidth = 2
            self.pdfContainerView.layer.borderColor = UIColor.systemOrange.cgColor
            self.pdfContainerView.layer.cornerRadius = 4
        }
    }

    private func turnOffEditMode() {
        isEditMode = false
        pdfVC.pdfView.isUserInteractionEnabled = true
        editTapCatcher.isUserInteractionEnabled = false
        dragInterceptView.isUserInteractionEnabled = true   // re-enable drag
        editOverlay.clearAll()
        UIView.animate(withDuration: 0.2) {
            self.pdfContainerView.layer.borderWidth = 0
            self.pdfContainerView.layer.cornerRadius = 0
        }
        showToast("Edit Mode OFF")
    }

    // MARK: - Text selection handler (normal mode)

    private func handleTextSelected(_ text: String) {
        guard !isEditMode else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let preview = trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
        let alert = UIAlertController(title: "Selected Text",
                                      message: "\"\(preview)\"",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "➕ Add to Workspace", style: .default) { [weak self] _ in
            self?.workspaceVC.addText(trimmed)
        })
        alert.addAction(UIAlertAction(title: "✏️ Edit in PDF", style: .default) { [weak self] _ in
            self?.turnOnEditMode()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = pdfContainerView
            pop.sourceRect = CGRect(x: pdfContainerView.bounds.midX,
                                    y: pdfContainerView.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    // MARK: - Block actions

    enum BlockAction { case tap, longPress }
    private var selectedBlock: WordBlockView?

    private func handleBlockAction(_ bv: WordBlockView, action: BlockAction) {
        switch action {
        case .tap:
            selectedBlock?.setSelected(false)
            if selectedBlock === bv { selectedBlock = nil } else { selectedBlock = bv; bv.setSelected(true) }
        case .longPress:
            let a = UIAlertController(title: bv.block.text, message: nil, preferredStyle: .actionSheet)
            a.addAction(UIAlertAction(title: "✏️ Edit Text", style: .default) { [weak self] _ in self?.editBlock(bv) })
            a.addAction(UIAlertAction(title: "🔗 Connect to…", style: .default) { [weak self] _ in self?.startConnect(from: bv) })
            a.addAction(UIAlertAction(title: "🗑️ Remove", style: .destructive) { [weak self] _ in
                self?.workspaceVC.canvas.removeBlock(bv)
                if self?.selectedBlock === bv { self?.selectedBlock = nil }
            })
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let pop = a.popoverPresentationController { pop.sourceView = bv; pop.sourceRect = bv.bounds }
            present(a, animated: true)
        }
    }

    // MARK: - IBActions (connect in Storyboard)

    @IBAction func openPDF(_ sender: Any) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func addSelected(_ sender: Any) {
        guard let text = pdfVC.pdfView.currentSelection?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            showToast("Select text in PDF first"); return
        }
        workspaceVC.addText(text)
    }

    @IBAction func exportEditedPDF(_ sender: Any) {
        guard let document = pdfVC.pdfView.document,
              let data = document.dataRepresentation() else {
            showToast("No PDF to export"); return
        }
        editOverlay.clearAll()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Edited_\(Int(Date().timeIntervalSince1970)).pdf")
        try? data.write(to: url)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 50, width: 0, height: 0)
        }
        present(vc, animated: true)
    }

    @IBAction func linkSelected(_ sender: Any) {
        guard let bv = selectedBlock else { showToast("Tap a block first"); return }
        startConnect(from: bv)
    }

    @IBAction func editSelected(_ sender: Any) {
        guard let bv = selectedBlock else { showToast("Tap a block first"); return }
        editBlock(bv)
    }

    @IBAction func deleteSelected(_ sender: Any) {
        guard let bv = selectedBlock else { showToast("Tap a block first"); return }
        workspaceVC.canvas.removeBlock(bv)
        selectedBlock = nil
    }

    // MARK: - Block editing

    private func editBlock(_ bv: WordBlockView) {
        let a = UIAlertController(title: "Edit Block", message: nil, preferredStyle: .alert)
        a.addTextField { $0.text = bv.block.text }
        a.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let t = a.textFields?.first?.text, !t.isEmpty else { return }
            bv.updateText(t); self?.workspaceVC.canvas.updateAllConnectors()
        })
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(a, animated: true)
    }

    private var connectSource: WordBlockView?
    private var connectTapGR: UITapGestureRecognizer?

    private func startConnect(from bv: WordBlockView) {
        connectSource = bv
        showToast("Tap another block to connect")
        workspaceVC.canvas.blockViews.filter { $0 !== bv }.forEach {
            $0.layer.borderWidth = 2; $0.layer.borderColor = UIColor.systemGreen.cgColor
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(connectTapped(_:)))
        tap.cancelsTouchesInView = false
        workspaceVC.canvas.addGestureRecognizer(tap)
        connectTapGR = tap
    }

    @objc private func connectTapped(_ g: UITapGestureRecognizer) {
        workspaceVC.canvas.blockViews.forEach { $0.layer.borderWidth = 0 }
        if let r = connectTapGR { workspaceVC.canvas.removeGestureRecognizer(r) }
        connectTapGR = nil
        let loc = g.location(in: workspaceVC.canvas)
        for bv in workspaceVC.canvas.blockViews {
            if bv.frame.contains(loc), let src = connectSource, bv !== src {
                workspaceVC.canvas.connect(from: src, to: bv)
                showToast("Connected!")
                break
            }
        }
        connectSource = nil
    }

    // MARK: - Toast

    private func showAddTextAlert() {
        
        let alert = UIAlertController(title: "Add New Text",
                                      message: "Enter your custom text",
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Enter text here..."
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { _ in
            guard let text = alert.textFields?.first?.text,
                  !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            
            self.createNewTextBlock(with: text)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(addAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    private func createNewTextBlock(with text: String) {
        
        let width: CGFloat = 180
        let height: CGFloat = 60
        
        let startX = (editorContainerView.bounds.width - width) / 2
        let startY = (editorContainerView.bounds.height - height) / 2
        
        let block = TextBlockView(frame: CGRect(x: startX,
                                                y: startY,
                                                width: width,
                                                height: height))
        
        block.textView.text = text
        
        // Important: allow drag inside editor container
        editorContainerView.addSubview(block)
    }
    private func showToast(_ msg: String) {
        view.subviews.filter { $0.tag == 7777 }.forEach { $0.removeFromSuperview() }
        let t = UILabel()
        t.tag = 7777
        t.text = "  \(msg)  "
        t.textColor = .white
        t.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        t.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        t.layer.cornerRadius = 14; t.clipsToBounds = true
        t.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(t)
        NSLayoutConstraint.activate([
            t.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            t.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        UIView.animate(withDuration: 0.25, delay: 2.5) { t.alpha = 0 } completion: { _ in t.removeFromSuperview() }
    }
}
struct WordBlock: Equatable {
    let id: UUID
    var text: String
    var position: CGPoint
    var size: CGSize
    var image: UIImage? = nil
    init(text: String? = nil, image: UIImage? = nil, position: CGPoint) {
        self.id = UUID()
        self.text = text ?? ""
        self.image = image
        self.position = position
        self.size = image != nil
            ? CGSize(width: 160, height: 120)
            : CGSize(width: max(140, (text ?? "").count * 10 + 40), height: 50)
    }
    static func == (lhs: WordBlock, rhs: WordBlock) -> Bool { lhs.id == rhs.id }
}

// MARK: - WordBlockView

class WordBlockView: UIView {
    var block: WordBlock
    var onTap: ((WordBlockView) -> Void)?
    private let label = UILabel()
    private let imageView = UIImageView()
    init(block: WordBlock) {
        self.block = block
        super.init(frame: CGRect(origin: block.position, size: block.size))
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = .white
        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        if let img = block.image {
            imageView.image = img
            imageView.contentMode = .scaleAspectFit
            imageView.frame = bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(imageView)
        } else {
            label.text = block.text
        }
        // Arrow
        let av = UIView(frame: CGRect(x: -14, y: 15, width: 14, height: 20))
        av.backgroundColor = .clear
        let al = CAShapeLayer()
        let p = UIBezierPath()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: 14, y: 10))
        p.addLine(to: CGPoint(x: 0, y: 20))
        p.close()
        al.path = p.cgPath
        al.fillColor = UIColor(white: 0.75, alpha: 1).cgColor
        av.layer.addSublayer(al)
        addSubview(av)

        label.text = block.text
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .black
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    func setSelected(_ on: Bool) {
        backgroundColor = on ? UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1) : .white
        layer.borderWidth = on ? 2 : 0
        layer.borderColor = UIColor.systemBlue.cgColor
    }

    func updateText(_ t: String) {
        block.text = t; label.text = t
        frame.size.width = CGFloat(max(140, t.count * 10 + 40))
        block.size.width = frame.size.width
    }

    @objc private func tapped() { onTap?(self) }
}

// MARK: - FlowConnectorView

class FlowConnectorView: UIView {
    var fromBlock: WordBlockView
    var toBlock: WordBlockView
    private let shapeLayer = CAShapeLayer()

    init(from: WordBlockView, to: WordBlockView) {
        self.fromBlock = from; self.toBlock = to
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = UIColor(white: 0.82, alpha: 1).cgColor
        shapeLayer.strokeColor = UIColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    func updatePath() {
        guard let sv = superview else { return }
        frame = sv.bounds
        let f = fromBlock.frame, t = toBlock.frame
        let midY = f.maxY + (t.minY - f.maxY) / 2
        let path = UIBezierPath()
        path.move(to: CGPoint(x: f.minX, y: f.maxY))
        path.addCurve(to: CGPoint(x: t.minX, y: t.minY),
                      controlPoint1: CGPoint(x: f.minX - 20, y: midY),
                      controlPoint2: CGPoint(x: t.minX - 20, y: midY))
        path.addLine(to: CGPoint(x: t.maxX, y: t.minY))
        path.addCurve(to: CGPoint(x: f.maxX, y: f.maxY),
                      controlPoint1: CGPoint(x: t.maxX + 20, y: midY),
                      controlPoint2: CGPoint(x: f.maxX + 20, y: midY))
        path.close()
        shapeLayer.path = path.cgPath
    }
}

// MARK: - WorkspaceCanvasView

class WorkspaceCanvasView: UIView {
    var blockViews: [WordBlockView] = []
    var connectors: [FlowConnectorView] = []
    var onBlockTapped: ((WordBlockView) -> Void)?
    private var dragOffset = CGPoint.zero

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let sp: CGFloat = 28, r: CGFloat = 1.5
        ctx.setFillColor(UIColor(white: 0.72, alpha: 0.6).cgColor)
        var x: CGFloat = sp / 2
        while x < rect.width {
            var y: CGFloat = sp / 2
            while y < rect.height {
                ctx.fillEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
                y += sp
            }
            x += sp
        }
    }

    @discardableResult
    func addBlock(_ block: WordBlock) -> WordBlockView {
        let bv = WordBlockView(block: block)
        bv.onTap = { [weak self] v in self?.onBlockTapped?(v) }
        bv.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
        bv.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(lp(_:))))
        blockViews.append(bv)
        addSubview(bv)
        bv.alpha = 0
        bv.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5) {
            bv.alpha = 1; bv.transform = .identity
        }
        return bv
    }

    func removeBlock(_ bv: WordBlockView) {
        connectors.filter { $0.fromBlock === bv || $0.toBlock === bv }.forEach { $0.removeFromSuperview() }
        connectors.removeAll { $0.fromBlock === bv || $0.toBlock === bv }
        blockViews.removeAll { $0 === bv }
        UIView.animate(withDuration: 0.2, animations: {
            bv.alpha = 0; bv.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }) { _ in bv.removeFromSuperview() }
    }

    func connect(from: WordBlockView, to: WordBlockView) {
        guard !connectors.contains(where: { $0.fromBlock === from && $0.toBlock === to }) else { return }
        let c = FlowConnectorView(from: from, to: to)
        connectors.append(c); insertSubview(c, at: 0); c.updatePath()
    }

    func updateAllConnectors() { connectors.forEach { $0.updatePath() } }

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        guard let bv = g.view as? WordBlockView else { return }
        switch g.state {
        case .began:
            dragOffset = g.location(in: bv)
            bringSubviewToFront(bv)
            UIView.animate(withDuration: 0.1) { bv.transform = CGAffineTransform(scaleX: 1.06, y: 1.06) }
        case .changed:
            let loc = g.location(in: self)
            bv.frame.origin = CGPoint(
                x: max(20, min(bounds.width - bv.bounds.width - 20, loc.x - dragOffset.x)),
                y: max(20, min(bounds.height - bv.bounds.height - 20, loc.y - dragOffset.y))
            )
            bv.block.position = bv.frame.origin
            updateAllConnectors()
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) { bv.transform = .identity }
        default: break
        }
    }

    @objc private func lp(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let bv = g.view as? WordBlockView else { return }
        onBlockTapped?(bv)
    }
}

// MARK: - PDFEditOverlayView

class PDFEditOverlayView: UIView {
    private var highlights: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func showHighlight(at frame: CGRect) {
        highlights.forEach { $0.removeFromSuperview() }
        highlights.removeAll()
        let box = UIView(frame: frame)
        box.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.45)
        box.layer.borderColor = UIColor.systemOrange.cgColor
        box.layer.borderWidth = 1.5
        box.layer.cornerRadius = 3
        box.isUserInteractionEnabled = false
        highlights.append(box)
        addSubview(box)
    }

    func clearAll() {
        highlights.forEach { $0.removeFromSuperview() }
        highlights.removeAll()
    }
}

// MARK: - Main ViewController


// MARK: - Document Picker

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        pdfVC.loadPDF(url: dest)
        pdfEdits.removeAll()
        editOverlay.clearAll()
        workspaceVC.clearAll()
        if isEditMode { turnOffEditMode() }
    }
}

// MARK: - PDFViewContainer

class PDFViewContainer: UIViewController {
    var pdfView: PDFView!
    var onTextSelected: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(white: 0.92, alpha: 1)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(selectionChanged),
                                               name: .PDFViewSelectionChanged, object: pdfView)
    }

    @objc private func selectionChanged() {
        guard let text = pdfView.currentSelection?.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onTextSelected?(text)
    }

    func loadPDF(url: URL) {
        if let doc = PDFDocument(url: url) { pdfView.document = doc }
    }
}

// MARK: - WorkspaceEmbedVC

class WorkspaceEmbedVC: UIViewController {
    var canvas: WorkspaceCanvasView!
    var onBlockAction: ((WordBlockView, ViewController.BlockAction) -> Void)?
    private let scrollView = UIScrollView()
    private let hintLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1.0)
        setupScrollView()
        setupHint()
    }
    func addImageBlock(_ image: UIImage) {
        hintLabel.isHidden = true
        
        let imageBlock = ImageBlockView(image: image)
        canvas.addSubview(imageBlock)
    }
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        canvas = WorkspaceCanvasView()
        canvas.backgroundColor = .clear
        canvas.frame = CGRect(x: 0, y: 0, width: 600, height: 3000)
        canvas.onBlockTapped = { [weak self] bv in self?.onBlockAction?(bv, .tap) }
        scrollView.addSubview(canvas)
        scrollView.contentSize = canvas.frame.size
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvas.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 3000)
        scrollView.contentSize = canvas.frame.size
        canvas.setNeedsDisplay()
    }

    private func setupHint() {
        hintLabel.text = "Long-press any word in PDF\nand drag it here"
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        hintLabel.textColor = UIColor(white: 0.55, alpha: 1)
        hintLabel.font = UIFont.systemFont(ofSize: 14)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func addText(_ text: String) {
        hintLabel.isHidden = true
        let count = canvas.blockViews.count
        let block = WordBlock(text: text, position: CGPoint(x: 30, y: 40 + CGFloat(count) * 80))
        let bv = canvas.addBlock(block)
        if count > 0, let prev = canvas.blockViews[safe: count - 1] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.canvas.connect(from: prev, to: bv)
            }
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: max(0, CGFloat(count) * 80 - 60)), animated: true)
    }

    func clearAll() {
        canvas.blockViews.forEach { $0.removeFromSuperview() }
        canvas.blockViews.removeAll()
        canvas.connectors.forEach { $0.removeFromSuperview() }
        canvas.connectors.removeAll()
        hintLabel.isHidden = false
    }
}



extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

 
class DragInterceptView: UIView {
    var onLongPress: ((CGPoint) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onEnd: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    private var touchStart: CGPoint?
    private var holdTimer: Timer?
    private var isDragging = false
    private let holdDuration: TimeInterval = 0.3

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        // CRITICAL: pass non-drag taps through to PDFView below
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    // Forward hits through when not dragging so PDF scrolling still works
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only intercept if we're actively dragging
        if isDragging { return self }
        // Otherwise let touches fall through to PDFView
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        touchStart = loc
        isDragging = false

        // Start hold timer
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { [weak self] _ in
            guard let self = self, let start = self.touchStart else { return }
            self.isDragging = true
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.onLongPress?(start)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        // Cancel hold if moved too much before timer fires
        if !isDragging {
            if let start = touchStart {
                let dx = loc.x - start.x, dy = loc.y - start.y
                if sqrt(dx*dx + dy*dy) > 8 {
                    holdTimer?.invalidate(); holdTimer = nil
                    touchStart = nil
                }
            }
            return
        }
        onMove?(loc)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        holdTimer?.invalidate(); holdTimer = nil
        guard let touch = touches.first else { isDragging = false; touchStart = nil; return }
        let loc = touch.location(in: self)
        if isDragging {
            onEnd?(loc)
        }
        isDragging = false
        touchStart = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        holdTimer?.invalidate(); holdTimer = nil
        if isDragging { onCancel?() }
        isDragging = false
        touchStart = nil
    }
}
