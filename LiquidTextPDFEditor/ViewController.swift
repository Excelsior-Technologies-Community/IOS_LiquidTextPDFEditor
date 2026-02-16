//
//  ViewController.swift
//  LiquidTextPDFEditor
//
//  Created by Noman belim on 12/02/26.
//
import UIKit
import PDFKit
import UniformTypeIdentifiers

// MARK: - PDF Edit Annotation Model
struct PDFTextEdit {
    let pageIndex: Int
    let originalText: String
    var newText: String
    let bounds: CGRect          // in PDF page coordinates
    var overlayView: UITextField?
}

// MARK: - Word Block Model
struct WordBlock: Equatable {
    let id: UUID
    var text: String
    var position: CGPoint
    var size: CGSize

    init(text: String, position: CGPoint) {
        self.id = UUID()
        self.text = text
        self.position = position
        self.size = CGSize(width: max(140, text.count * 10 + 40), height: 50)
    }

    static func == (lhs: WordBlock, rhs: WordBlock) -> Bool { lhs.id == rhs.id }
}

// MARK: - Word Block View
class WordBlockView: UIView {
    var block: WordBlock
    var onTap: ((WordBlockView) -> Void)?

    private let label = UILabel()

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

        // Left arrow indicator
        let arrowSize = CGSize(width: 14, height: 20)
        let arrowView = UIView(frame: CGRect(x: -14, y: (block.size.height - arrowSize.height) / 2,
                                             width: arrowSize.width, height: arrowSize.height))
        arrowView.backgroundColor = .clear
        let arrowLayer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: arrowSize.width, y: arrowSize.height / 2))
        path.addLine(to: CGPoint(x: 0, y: arrowSize.height))
        path.close()
        arrowLayer.path = path.cgPath
        arrowLayer.fillColor = UIColor(white: 0.75, alpha: 1.0).cgColor
        arrowView.layer.addSublayer(arrowLayer)
        addSubview(arrowView)

        label.text = block.text
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.textColor = .black
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    func setSelected(_ selected: Bool) {
        if selected {
            backgroundColor = UIColor(red: 0.53, green: 0.81, blue: 0.98, alpha: 1.0)
            layer.borderWidth = 2
            layer.borderColor = UIColor.systemBlue.cgColor
        } else {
            backgroundColor = .white
            layer.borderWidth = 0
        }
    }

    func updateText(_ text: String) {
        block.text = text
        label.text = text
        let newWidth = max(140, text.count * 10 + 40)
        frame.size.width = CGFloat(newWidth)
        block.size.width = CGFloat(newWidth)
    }

    @objc private func handleTap() { onTap?(self) }
}

// MARK: - Flow Connector
class FlowConnectorView: UIView {
    var fromBlock: WordBlockView
    var toBlock: WordBlockView
    private let shapeLayer = CAShapeLayer()

    init(from: WordBlockView, to: WordBlockView) {
        self.fromBlock = from
        self.toBlock = to
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(shapeLayer)
        shapeLayer.fillColor = UIColor(white: 0.82, alpha: 1.0).cgColor
        shapeLayer.strokeColor = UIColor.clear.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    func updatePath() {
        guard let superview = superview else { return }
        frame = superview.bounds
        let f = fromBlock.frame
        let t = toBlock.frame
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

// MARK: - Workspace Canvas
class WorkspaceCanvasView: UIView {
    var blockViews: [WordBlockView] = []
    var connectors: [FlowConnectorView] = []
    var onBlockTapped: ((WordBlockView) -> Void)?

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let spacing: CGFloat = 28
        let dotRadius: CGFloat = 1.5
        ctx.setFillColor(UIColor(white: 0.72, alpha: 0.6).cgColor)
        var x: CGFloat = spacing / 2
        while x < rect.width {
            var y: CGFloat = spacing / 2
            while y < rect.height {
                ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius,
                                           width: dotRadius * 2, height: dotRadius * 2))
                y += spacing
            }
            x += spacing
        }
    }

    @discardableResult
    func addBlock(_ block: WordBlock) -> WordBlockView {
        let bv = WordBlockView(block: block)
        bv.onTap = { [weak self] view in self?.onBlockTapped?(view) }
        bv.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        bv.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:))))
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
        connectors.append(c)
        insertSubview(c, at: 0)
        c.updatePath()
    }

    func updateAllConnectors() { connectors.forEach { $0.updatePath() } }

    private var dragOffset = CGPoint.zero

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let bv = g.view as? WordBlockView else { return }
        switch g.state {
        case .began:
            dragOffset = g.location(in: bv)
            bringSubviewToFront(bv)
            UIView.animate(withDuration: 0.12) {
                bv.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                bv.layer.shadowOpacity = 0.3
            }
        case .changed:
            let loc = g.location(in: self)
            var o = CGPoint(x: loc.x - dragOffset.x, y: loc.y - dragOffset.y)
            o.x = max(20, min(bounds.width - bv.bounds.width - 20, o.x))
            o.y = max(20, min(bounds.height - bv.bounds.height - 20, o.y))
            bv.frame.origin = o; bv.block.position = o
            updateAllConnectors()
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) {
                bv.transform = .identity; bv.layer.shadowOpacity = 0.18
            }
        default: break
        }
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let bv = g.view as? WordBlockView else { return }
        onBlockTapped?(bv)
    }
}

// MARK: - PDF Editing Overlay View
// Transparent overlay sitting on top of PDFView to place editable text fields over PDF text
class PDFEditOverlayView: UIView {
    var textFields: [UITextField] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func addEditField(frame: CGRect, text: String, font: UIFont, onCommit: @escaping (String) -> Void) -> UITextField {
        let tf = UITextField(frame: frame)
        tf.text = text
        tf.font = font
        tf.textColor = .black
        tf.backgroundColor = UIColor.yellow.withAlphaComponent(0.25)
        tf.layer.borderColor = UIColor.systemBlue.cgColor
        tf.layer.borderWidth = 1.5
        tf.layer.cornerRadius = 3
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.clearButtonMode = .whileEditing

        // Store commit handler
        let action = CommitAction(onCommit: onCommit)
        objc_setAssociatedObject(tf, &AssociatedKeys.commitAction, action, .OBJC_ASSOCIATION_RETAIN)
        tf.addTarget(self, action: #selector(textFieldDone(_:)), for: .editingDidEndOnExit)

        textFields.append(tf)
        addSubview(tf)
        tf.becomeFirstResponder()
        return tf
    }

    @objc private func textFieldDone(_ tf: UITextField) {
        if let action = objc_getAssociatedObject(tf, &AssociatedKeys.commitAction) as? CommitAction {
            action.onCommit(tf.text ?? "")
        }
        tf.resignFirstResponder()
    }

    func clearAll() {
        textFields.forEach { $0.removeFromSuperview() }
        textFields.removeAll()
    }
}

private enum AssociatedKeys { static var commitAction = "commitAction" }
private class CommitAction: NSObject {
    let onCommit: (String) -> Void
    init(onCommit: @escaping (String) -> Void) { self.onCommit = onCommit }
}

// MARK: - Main ViewController
class ViewController: UIViewController {

    @IBOutlet weak var pdfContainerView: UIView!
    @IBOutlet weak var editorContainerView: UIView!

    private var pdfVC: PDFViewContainer!
    private var workspaceVC: WorkspaceEmbedVC!

    // PDF Editing state
    private var isEditMode = false
    private var currentPDFURL: URL?
    private var pdfEdits: [PDFTextEdit] = []   // all pending edits
    private var editOverlay: PDFEditOverlayView!

    override func viewDidLoad() {
        super.viewDidLoad()
        embedChildVCs()
        setupEditOverlay()
    }

    // MARK: - Embed child VCs
    private func embedChildVCs() {
        pdfVC = PDFViewContainer()
        addChild(pdfVC)
        pdfVC.view.frame = pdfContainerView.bounds
        pdfVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pdfContainerView.addSubview(pdfVC.view)
        pdfVC.didMove(toParent: self)

        pdfVC.onTextSelected = { [weak self] text in self?.handleTextSelected(text) }
        pdfVC.onTextTappedForEdit = { [weak self] selection, page in
            self?.handlePDFTextTappedForEdit(selection: selection, page: page)
        }

        workspaceVC = WorkspaceEmbedVC()
        addChild(workspaceVC)
        workspaceVC.view.frame = editorContainerView.bounds
        workspaceVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        editorContainerView.addSubview(workspaceVC.view)
        workspaceVC.didMove(toParent: self)

        workspaceVC.onBlockAction = { [weak self] bv, action in
            self?.handleBlockAction(bv, action: action)
        }
    }

    // MARK: - Edit overlay on top of PDF
    private func setupEditOverlay() {
        editOverlay = PDFEditOverlayView()
        editOverlay.isUserInteractionEnabled = false  // disabled until edit mode on
        editOverlay.translatesAutoresizingMaskIntoConstraints = false
        pdfContainerView.addSubview(editOverlay)
        NSLayoutConstraint.activate([
            editOverlay.topAnchor.constraint(equalTo: pdfContainerView.topAnchor),
            editOverlay.bottomAnchor.constraint(equalTo: pdfContainerView.bottomAnchor),
            editOverlay.leadingAnchor.constraint(equalTo: pdfContainerView.leadingAnchor),
            editOverlay.trailingAnchor.constraint(equalTo: pdfContainerView.trailingAnchor)
        ])
    }

    // MARK: - Text selected in PDF (for workspace block)
    private func handleTextSelected(_ text: String) {
        guard !isEditMode else { return }   // In edit mode, tap = edit, not add to workspace
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let preview = trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
        let alert = UIAlertController(title: "Selected Text", message: "\"\(preview)\"",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "➕ Add to Workspace", style: .default) { [weak self] _ in
            self?.workspaceVC.addText(trimmed)
        })
        alert.addAction(UIAlertAction(title: "✏️ Edit in PDF", style: .default) { [weak self] _ in
            self?.enterEditModeForSelection()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = pdfContainerView
            pop.sourceRect = CGRect(x: pdfContainerView.bounds.midX,
                                    y: pdfContainerView.bounds.midY, width: 0, height: 0)
        }
        present(alert, animated: true)
    }

    // MARK: - PDF Tap-to-Edit
    private func handlePDFTextTappedForEdit(selection: PDFSelection, page: PDFPage) {
        guard isEditMode else { return }

        let selectedText = selection.string ?? ""
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Get bounds in PDF page space
        let pageBounds = selection.bounds(for: page)

        // Convert PDF page bounds → PDFView coordinates → pdfContainerView coordinates
        let pdfView = pdfVC.pdfView!
        guard let pageIndex = pdfView.document?.index(for: page) else { return }

        // Convert bounds from page to view
        let viewBounds = pdfView.convert(pageBounds, from: page)
        // Convert from pdfView to pdfContainerView
        let containerBounds = pdfView.convert(viewBounds, to: pdfContainerView)

        // Inflate slightly for easy editing
        let editFrame = containerBounds.insetBy(dx: -4, dy: -4)

        // Estimate font size from height of the selection
        let fontSize = max(10, min(24, containerBounds.height * 0.75))
        let font = UIFont.systemFont(ofSize: fontSize)

        // Remove any existing field at same location
        editOverlay.textFields.filter { $0.frame.intersects(editFrame) }.forEach {
            $0.removeFromSuperview()
        }
        editOverlay.textFields.removeAll { $0.frame.intersects(editFrame) }

        // Add editable text field
        _ = editOverlay.addEditField(frame: editFrame, text: selectedText, font: font) { [weak self] newText in
            guard let self = self else { return }
            guard newText != selectedText else { return }

            // Record edit
            let edit = PDFTextEdit(pageIndex: pageIndex,
                                   originalText: selectedText,
                                   newText: newText,
                                   bounds: pageBounds)
            self.pdfEdits.append(edit)

            // Apply edit visually to the PDF annotation
            self.applyEditToPage(page: page, edit: edit)

            self.showToast("Text updated in PDF ✓")
        }
    }

    // MARK: - Apply text edit to PDF page using annotation
    private func applyEditToPage(page: PDFPage, edit: PDFTextEdit) {
        guard let pdfView = pdfVC?.pdfView, pdfView.document != nil else { return }

        // Create a white rectangle annotation to cover original text
        let whiteOut = PDFAnnotation(bounds: edit.bounds, forType: .square, withProperties: nil)
        whiteOut.color = .white
        whiteOut.interiorColor = .white
        whiteOut.border = PDFBorder()
        page.addAnnotation(whiteOut)

        // Create free text annotation with new text
        let fontSize = max(8, min(20, edit.bounds.height * 0.72))
        let textAnnotation = PDFAnnotation(bounds: edit.bounds, forType: .freeText, withProperties: nil)
        textAnnotation.contents = edit.newText
        textAnnotation.font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        textAnnotation.fontColor = .black
        textAnnotation.color = .clear
        textAnnotation.interiorColor = .clear

        let border = PDFBorder()
        border.lineWidth = 0
        textAnnotation.border = border
        page.addAnnotation(textAnnotation)

        // Refresh the PDF view
        pdfView.setNeedsDisplay()
    }

    // MARK: - Enter edit mode for current PDF selection
    private func enterEditModeForSelection() {
        guard !isEditMode else { return }
        turnOnEditMode()

        // Try to show edit field for current selection immediately
        if let sel = pdfVC.pdfView.currentSelection,
           let page = sel.pages.first {
            handlePDFTextTappedForEdit(selection: sel, page: page)
        }
    }

    // MARK: - Toggle edit mode (called from storyboard button)
    @objc func toggleEditMode() {
        if isEditMode { turnOffEditMode() } else { turnOnEditMode() }
    }

    private func turnOnEditMode() {
        isEditMode = true
        editOverlay.isUserInteractionEnabled = true
        pdfVC.editModeEnabled = true

        // Visual indicator — yellow bar
        showToast("✏️ Edit Mode ON — tap any PDF text to edit")

        // Tint the PDF container
        UIView.animate(withDuration: 0.2) {
            self.pdfContainerView.layer.borderWidth = 2
            self.pdfContainerView.layer.borderColor = UIColor.systemOrange.cgColor
        }
    }

    private func turnOffEditMode() {
        isEditMode = false
        editOverlay.isUserInteractionEnabled = false
        pdfVC.editModeEnabled = false
        editOverlay.textFields.forEach { $0.resignFirstResponder() }
        editOverlay.clearAll()

        UIView.animate(withDuration: 0.2) {
            self.pdfContainerView.layer.borderWidth = 0
        }
        showToast("Edit Mode OFF")
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
            let alert = UIAlertController(title: bv.block.text, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "✏️ Edit Text", style: .default) { [weak self] _ in self?.editBlock(bv) })
            alert.addAction(UIAlertAction(title: "🔗 Connect to…", style: .default) { [weak self] _ in self?.startConnect(from: bv) })
            alert.addAction(UIAlertAction(title: "🗑️ Remove", style: .destructive) { [weak self] _ in
                self?.workspaceVC.canvas.removeBlock(bv)
                if self?.selectedBlock === bv { self?.selectedBlock = nil }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let pop = alert.popoverPresentationController { pop.sourceView = bv; pop.sourceRect = bv.bounds }
            present(alert, animated: true)
        }
    }

    // MARK: - Toolbar IBActions (connect these in Storyboard)
    @IBAction func openPDF(_ sender: Any) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func addSelected(_ sender: Any) {
        guard let text = pdfVC.pdfView.currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { showToast("Select text in the PDF first"); return }
        workspaceVC.addText(text)
    }

    @IBAction func editPDFMode(_ sender: Any) {
        toggleEditMode()
    }

    @IBAction func exportEditedPDF(_ sender: Any) {
        exportPDF()
    }

    @IBAction func linkSelected(_ sender: Any) {
        guard let bv = selectedBlock else { showToast("Tap a workspace block first"); return }
        startConnect(from: bv)
    }

    @IBAction func editSelected(_ sender: Any) {
        guard let bv = selectedBlock else { showToast("Tap a block to select it first"); return }
        editBlock(bv)
    }

    @IBAction func deleteSelected(_ sender: Any) {
        guard let bv = selectedBlock else { showToast("Tap a block to select it first"); return }
        workspaceVC.canvas.removeBlock(bv)
        selectedBlock = nil
    }

    // MARK: - Edit block text
    private func editBlock(_ bv: WordBlockView) {
        let alert = UIAlertController(title: "Edit Block Text", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = bv.block.text }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let t = alert.textFields?.first?.text, !t.isEmpty else { return }
            bv.updateText(t)
            self?.workspaceVC.canvas.updateAllConnectors()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Connect blocks
    private var connectSource: WordBlockView?
    private var connectTapRecognizer: UITapGestureRecognizer?

    private func startConnect(from bv: WordBlockView) {
        connectSource = bv
        showToast("Tap another block to connect")
        workspaceVC.canvas.blockViews.filter { $0 !== bv }.forEach {
            $0.layer.borderWidth = 2; $0.layer.borderColor = UIColor.systemGreen.cgColor
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(connectTargetTapped(_:)))
        tap.cancelsTouchesInView = false
        workspaceVC.canvas.addGestureRecognizer(tap)
        connectTapRecognizer = tap
    }

    @objc private func connectTargetTapped(_ g: UITapGestureRecognizer) {
        workspaceVC.canvas.blockViews.forEach { $0.layer.borderWidth = 0 }
        if let r = connectTapRecognizer { workspaceVC.canvas.removeGestureRecognizer(r) }
        connectTapRecognizer = nil
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

    // MARK: - Export edited PDF
    private func exportPDF() {
        guard let document = pdfVC.pdfView.document else {
            showToast("No PDF loaded"); return
        }

        // Commit any active text fields before export
        editOverlay.textFields.forEach { tf in
            if tf.isEditing {
                tf.sendActions(for: .editingDidEndOnExit)
            }
        }

        // Generate PDF data from the document (includes all annotations/edits)
        guard let data = document.dataRepresentation() else {
            showToast("Failed to generate PDF"); return
        }

        // Save to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditedDocument_\(Date().timeIntervalSince1970).pdf")

        do {
            try data.write(to: tempURL)

            // Share / Save
            let activity = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            activity.completionWithItemsHandler = { _, completed, _, _ in
                if completed { self.showToast("PDF saved successfully ✓") }
            }
            if let pop = activity.popoverPresentationController {
                pop.sourceView = view
                pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 50, width: 0, height: 0)
            }
            present(activity, animated: true)
        } catch {
            showToast("Export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Toast
    private func showToast(_ msg: String) {
        // Remove existing toasts
        view.subviews.filter { $0.tag == 8888 }.forEach { $0.removeFromSuperview() }

        let t = UILabel()
        t.tag = 8888
        t.text = "  \(msg)  "
        t.textColor = .white
        t.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        t.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        t.layer.cornerRadius = 14; t.clipsToBounds = true
        t.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(t)
        NSLayoutConstraint.activate([
            t.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            t.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
        UIView.animate(withDuration: 0.25, delay: 2.2) { t.alpha = 0 } completion: { _ in t.removeFromSuperview() }
    }
}

// MARK: - Document Picker Delegate
extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        // Copy to app's temp dir so we retain access for export
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: destURL)
        try? FileManager.default.copyItem(at: url, to: destURL)

        currentPDFURL = destURL
        pdfVC.loadPDF(url: destURL)
        pdfEdits.removeAll()
        editOverlay.clearAll()
        workspaceVC.clearAll()
        if isEditMode { turnOffEditMode() }
    }
}

// MARK: - PDF Container VC
class PDFViewContainer: UIViewController {
    var pdfView: PDFView!
    var onTextSelected: ((String) -> Void)?
    var onTextTappedForEdit: ((PDFSelection, PDFPage) -> Void)?

    var editModeEnabled = false {
        didSet {
            tapRecognizer?.isEnabled = editModeEnabled
        }
    }

    private var tapRecognizer: UITapGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.95, alpha: 1)

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

        // Selection observer
        NotificationCenter.default.addObserver(self, selector: #selector(selectionChanged),
                                               name: .PDFViewSelectionChanged, object: pdfView)

        // Tap recognizer for edit mode
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.isEnabled = false
        tap.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tap)
        tapRecognizer = tap
    }

    @objc private func selectionChanged() {
        guard let text = pdfView.currentSelection?.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onTextSelected?(text)
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard editModeEnabled else { return }
        let loc = g.location(in: pdfView)

        // Find the PDF page and character at tap location
        guard let page = pdfView.page(for: loc, nearest: true) else { return }
        let pagePoint = pdfView.convert(loc, to: page)

        // Select the word at that point
        if let sel = page.selectionForWord(at: pagePoint) {
            pdfView.setCurrentSelection(sel, animate: false)
            onTextTappedForEdit?(sel, page)
        }
    }

    func loadPDF(url: URL) {
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
    }
}

// MARK: - Workspace Embed VC
class WorkspaceEmbedVC: UIViewController {
    var canvas: WorkspaceCanvasView!
    var onBlockAction: ((WordBlockView, ViewController.BlockAction) -> Void)?

    private let scrollView = UIScrollView()
    private let hintLabel  = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1.0)
        setupScrollView()
        setupHint()
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
        canvas.frame = CGRect(x: 0, y: 0, width: 1000, height: 3000)
        canvas.onBlockTapped = { [weak self] bv in self?.onBlockAction?(bv, .tap) }
        scrollView.addSubview(canvas)
        scrollView.contentSize = canvas.frame.size
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width
        canvas.frame = CGRect(x: 0, y: 0, width: w, height: 3000)
        scrollView.contentSize = canvas.frame.size
        canvas.setNeedsDisplay()
    }

    private func setupHint() {
        hintLabel.text = "Select PDF text then tap ➕\nor tap ✏️ to edit PDF directly"
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
        let x: CGFloat = 30
        let y: CGFloat = 40 + CGFloat(count) * 80
        let block = WordBlock(text: text, position: CGPoint(x: x, y: y))
        let bv = canvas.addBlock(block)
        if count > 0, let prev = canvas.blockViews[safe: count - 1] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.canvas.connect(from: prev, to: bv)
            }
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: max(0, y - 60)), animated: true)
    }

    func clearAll() {
        canvas.blockViews.forEach { $0.removeFromSuperview() }
        canvas.blockViews.removeAll()
        canvas.connectors.forEach { $0.removeFromSuperview() }
        canvas.connectors.removeAll()
        hintLabel.isHidden = false
    }
}

// MARK: - Safe subscript
extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
