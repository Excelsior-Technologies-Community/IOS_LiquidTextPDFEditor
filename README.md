# 📘 LiquidTextPDFEditor

> A powerful iOS PDF Editor built with **UIKit + PDFKit**, inspired by LiquidText-style interaction.

[![Platform](https://img.shields.io/badge/Platform-iOS%2015%2B-blue?logo=apple)](https://developer.apple.com/ios/)
[![Language](https://img.shields.io/badge/Language-Swift-orange?logo=swift)](https://swift.org/)
[![Framework](https://img.shields.io/badge/Framework-UIKit%20%7C%20PDFKit-purple)](https://developer.apple.com/documentation/pdfkit)

---

## ✨ Features

| Feature | Status |
|---|---|
| View PDF | ✅ |
| Edit Text | ✅ |
| Highlight Text | ✅ |
| Search Text | ✅ |
| Crop to Image | ✅ |
| Drag Word to Workspace | ✅ |
| Custom Flow Blocks | ✅ |
| Connect Blocks | ✅ |
| Page Thumbnails | ✅ |

---

## 🏗️ Architecture

The app is divided into three main panels:

```
┌─────────────────┬───────────────────┬────────────────────────┐
│  Page Thumbnails│    PDF Viewer     │   Workspace (Flow Area) │
│     (Left)      │    (Center)       │        (Right)          │
└─────────────────┴───────────────────┴────────────────────────┘
```

---

## 🧩 Core Components

### 1. PDF Section (Center)
Handled by `PDFViewContainer` / `PDFView (PDFKit)`

- Display and navigate PDFs
- Select, edit, and highlight text
- Search text across pages
- Crop selected regions to image

### 2. Page Thumbnails (Left)
Handled by `PDFThumbnailView`

- Displays all pages vertically
- Tap to navigate to any page
- Stays in sync with the main `PDFView`

### 3. Workspace Flow Section (Right)
Handled by `WorkspaceEmbedVC`, `WorkspaceCanvasView`, `WordBlock`, `WordBlockView`, `FlowConnectorView`

- Displays extracted text words and cropped images as draggable blocks
- Supports drag & drop repositioning
- Supports connecting blocks with visual arrows
- Editable block text
- Visual flow creation

---

## 🔄 Application Flows

### 🧠 Flow 1 — Drag Word from PDF → Workspace

```
1. User long-presses a word in the PDF
2. DragInterceptView detects the touch
3. Word is extracted using:
        page.selectionForWord(at:)
4. A ghost label appears and follows the drag
5. User drags to the workspace panel
6. On drop:
        workspaceVC.addText(text)
7. WorkspaceCanvasView.addBlock() creates a new WordBlockView
8. Block auto-connects to the previous block
```

---

### ✂️ Flow 2 — Crop Selected PDF Area → Image Block

```
1. User taps the Crop button
2. isImageSelectionMode = true
3. User drags a rectangle over the PDF
4. handlePDFSelection() tracks the selection rect
5. On release:
        captureSelectedPDFArea(rect)
6. PDFView snapshot is rendered and cropped
7. Image is passed to:
        workspaceVC.addImageBlock(image)
8. Image becomes a draggable flow block
```

---

### 🔗 Flow 3 — Connect Blocks

```
1. User long-presses a block and chooses "Connect"
2. Taps another block to connect to
3. canvas.connect(from:to:) creates a FlowConnectorView
4. Connector dynamically redraws via:
        updateAllConnectors()
```

---

### 🟡 Flow 4 — Highlight Text

```
1. User selects text in the PDF
2. Taps Highlight
3. A PDF annotation is created:
        PDFAnnotation(forType: .highlight)
4. Annotation is added to the page
5. Highlight is persisted inside the PDF
```

---

### 🔍 Flow 5 — Search Text

```
1. User taps Search and enters a keyword
2. Search runs via:
        document.findString(keyword, withOptions:)
3. Results stored in:
        searchResults: [PDFSelection]
4. Highlighted via:
        pdfView.highlightedSelections
5. Navigate results with Next / Previous buttons
```

---

## 🧱 Data Models

### `WordBlock`

```swift
struct WordBlock {
    let id: UUID
    var text: String
    var image: UIImage?
    var position: CGPoint
    var size: CGSize
}
```

Used for both text blocks and image blocks, keeping the flow engine unified.

---

## 🎨 Workspace Rendering

### `WorkspaceCanvasView`
- Stores all `blockViews` and `connectors`
- Handles drag gestures
- Draws the dotted background grid
- Manages block connections

### `WordBlockView`
- Displays text or image content
- Handles tap selection and drag movement
- Dynamically resizes width
- Consistent visual styling

---

## 🛠️ Key Techniques

- **PDFKit** — `PDFAnnotation`, `PDFThumbnailView`, `PDFSelection`
- **Custom drag interception** — `DragInterceptView` for precise word extraction
- **Dynamic Bézier connectors** — `FlowConnectorView` using `UIBezierPath`
- **Layer rendering** — `CALayer` snapshots for PDF region cropping
- **Conflict-free gestures** — No gesture conflicts with native PDFKit recognizers

---

## 📦 Requirements

- iOS 15+
- Swift 5+
- UIKit
- PDFKit (no third-party dependencies)

---

## 🚀 Future Improvements

- [ ] Collapsible thumbnail sidebar
- [ ] Export workspace as PDF
- [ ] Multi-select blocks
- [ ] Block resizing handles
- [ ] Dark mode support
- [ ] Persistent workspace storage (Core Data / CloudKit)
- [ ] iPad multi-window support

---

## 🏁 Summary

**LiquidTextPDFEditor** is a hybrid PDF viewer + visual knowledge workspace tool. It lets users extract information from PDFs and structure it into connected thought flows — combining the power of PDFKit with a fully custom interactive canvas.

---
 
