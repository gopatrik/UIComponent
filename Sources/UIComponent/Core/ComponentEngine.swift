//
//  File.swift
//  
//
//  Created by Luke Zhao on 8/27/20.
//

import UIKit

/// Main class that powers rendering components
///
/// This object manages a ``ComponentDisplayableView`` and handles rendering the component
/// to the view. See ``ComponentView`` for a sample implementation
public class ComponentEngine {
  /// view that is managed by this engine.
  weak var view: ComponentDisplayableView?
  
  /// component for rendering
  var component: Component? {
    didSet { setNeedsReload() }
  }
  
  /// default animator for the components rendered by this engine
  var animator: Animator = Animator() {
    didSet { setNeedsReload() }
  }
  
  /// Current renderer. This is nil before the layout is done. And it will cache the current Renderer once the layout is done.
  var renderer: Renderer?
  
  /// internal states
  var needsReload = true
  var needsRender = false
  var shouldUpdateViewOnNextRender = false
  var reloadCount = 0
  var isRendering = false
  var isReloading = false
  
  /// visible frame insets. this will be applied to the visibleFrame that is used to retrieve views for the view port.
  var visibleFrameInsets: UIEdgeInsets = .zero
  
  /// simple flag indicating whether or not this engine has rendered
  var hasReloaded: Bool { reloadCount > 0 }

  /// visible cells and view data for the views displayed on screen
  var visibleViews: [UIView] = []
  var visibleRenderable: [Renderable] = []

  /// last reload bounds
  var lastRenderBounds: CGRect = .zero
  
  /// contentOffset changes since the last reload
  var contentOffsetDelta: CGPoint = .zero
  
  /// Used to support zooming. setting a ``contentView`` will make the render
  /// all views inside the content view.
  var contentView: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      if let contentView = contentView {
        view?.addSubview(contentView)
      }
    }
  }
  
  /// contentView layout configurations
  var centerContentViewVertically = false
  var centerContentViewHorizontally = true
  
  /// internal helpers for updating the component view
  var contentSize: CGSize = .zero {
    didSet {
      (view as? UIScrollView)?.contentSize = contentSize
    }
  }
  var contentOffset: CGPoint {
    get { return view?.bounds.origin ?? .zero }
    set { view?.bounds.origin = newValue }
  }
  var contentInset: UIEdgeInsets {
    guard let view = view as? UIScrollView else { return .zero }
    return view.adjustedContentInset
  }
  var bounds: CGRect {
    guard let view = view else { return .zero }
    return view.bounds
  }
  var adjustedSize: CGSize {
    bounds.size.inset(by: contentInset)
  }
  var zoomScale: CGFloat {
    guard let view = view as? UIScrollView else { return 1 }
    return view.zoomScale
  }
  
  init(view: ComponentDisplayableView) {
    self.view = view
  }
  
  func layoutSubview() {
    if needsReload {
      reloadData()
    } else if bounds.size != lastRenderBounds.size {
      invalidateLayout()
    } else if bounds != lastRenderBounds || needsRender {
      render()
    }
    contentView?.frame = CGRect(origin: .zero, size: contentSize)
    ensureZoomViewIsCentered()
  }

  func ensureZoomViewIsCentered() {
    guard let contentView = contentView else { return }
    let boundsSize: CGRect
    boundsSize = bounds.inset(by: contentInset)
    var frameToCenter = contentView.frame

    if centerContentViewHorizontally, frameToCenter.size.width < boundsSize.width {
      frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) * 0.5
    } else {
      frameToCenter.origin.x = 0
    }

    if centerContentViewVertically, frameToCenter.size.height < boundsSize.height {
      frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) * 0.5
    } else {
      frameToCenter.origin.y = 0
    }

    contentView.frame = frameToCenter
  }

  func setNeedsReload() {
    needsReload = true
    view?.setNeedsLayout()
  }

  func setNeedsInvalidateLayout() {
    renderer = nil
    setNeedsRender()
  }

  func setNeedsRender() {
    needsRender = true
    view?.setNeedsLayout()
  }

  // re-layout, but not updating cells' contents
  func invalidateLayout() {
    guard !isRendering, !isReloading, hasReloaded else { return }
    renderer = nil
    render()
  }

  // reload all frames. will automatically diff insertion & deletion
  func reloadData(contentOffsetAdjustFn: (() -> CGPoint)? = nil) {
    guard !isReloading else { return }
    isReloading = true
    defer {
      reloadCount += 1
      needsReload = false
      isReloading = false
    }
    
    renderer = nil
    shouldUpdateViewOnNextRender = true
    render(contentOffsetAdjustFn: contentOffsetAdjustFn)
  }

  func render(contentOffsetAdjustFn: (() -> CGPoint)? = nil) {
    guard let componentView = view, !isRendering, let component = component else { return }
    isRendering = true
    defer {
      shouldUpdateViewOnNextRender = false
      needsRender = false
      isRendering = false
    }
    
    let renderer: Renderer
    if let currentRenderer = self.renderer {
      renderer = currentRenderer
    } else {
      renderer = component.layout(Constraint(maxSize: adjustedSize))
      contentSize = renderer.size * zoomScale
      self.renderer = renderer
    }
    
    let oldContentOffset = contentOffset
    if let offset = contentOffsetAdjustFn?() {
      contentOffset = offset
    }
    contentOffsetDelta = contentOffset - oldContentOffset

    animator.willUpdate(componentView: componentView)
    let visibleFrame = (contentView?.convert(bounds, from: view) ?? bounds).inset(by: visibleFrameInsets)
    
    var newVisibleRenderable = renderer.views(in: visibleFrame)
    if contentSize != renderer.size * zoomScale {
      // update contentSize if it is changed. Some renderers update
      // its size when views(in: visibleFrame) is called. e.g. InfiniteLayout
      contentSize = renderer.size * zoomScale
    }

    // construct private identifiers
    var newIdentifierSet = [String: Int]()
    for (index, viewData) in newVisibleRenderable.enumerated() {
      var count = 1
      let initialId = viewData.id ?? viewData.keyPath
      var finalId = initialId
      while newIdentifierSet[finalId] != nil {
        assertionFailure("There are two view with the same id/keyPath \"\(finalId)\". This could cause undefined behavior.")
        finalId = initialId + String(count)
        newVisibleRenderable[index].id = finalId
        count += 1
      }
      newIdentifierSet[finalId] = index
    }
    print(newIdentifierSet)

    var newViews = [UIView?](repeating: nil, count: newVisibleRenderable.count)

    // 1st pass, delete all removed cells and move existing cells
    for index in 0 ..< visibleViews.count {
      let identifier = visibleRenderable[index].id ?? visibleRenderable[index].keyPath
      let cell = visibleViews[index]
      if let index = newIdentifierSet[identifier] {
        newViews[index] = cell
      } else {
        (visibleRenderable[index].animator ?? animator)?.delete(componentView: componentView, view: cell)
      }
    }

    // 2nd pass, insert new views
    for (index, viewData) in newVisibleRenderable.enumerated() {
      let view: UIView
      let frame = viewData.frame
      if let existingView = newViews[index] {
        view = existingView
        if shouldUpdateViewOnNextRender {
          // view was on screen before reload, need to update the view.
          viewData.renderer._updateView(view)
          (viewData.animator ?? animator).shift(componentView: componentView, delta: contentOffsetDelta,
                                                view: view, frame: frame)
        }
      } else {
        view = viewData.renderer._makeView()
        viewData.renderer._updateView(view)
        UIView.performWithoutAnimation {
          view.bounds.size = frame.bounds.size
          view.center = frame.center
        }
        (viewData.animator ?? animator).insert(componentView: componentView, view: view, frame: frame)
        newViews[index] = view
      }
      (viewData.animator ?? animator).update(componentView: componentView, view: view, frame: frame)
      (contentView ?? componentView).insertSubview(view, at: index)
    }

    visibleRenderable = newVisibleRenderable
    visibleViews = newViews as! [UIView]
    lastRenderBounds = bounds
  }

  /// This is used to replace a cell's identifier with a new identifer
  /// Useful when a cell's identifier is going to change with the next
  /// reloadData, but you want to keep the same cell view.
  func replace(identifier: String, with newIdentifier: String) {
    for (i, viewData) in visibleRenderable.enumerated() where viewData.id == identifier {
      visibleRenderable[i].id = newIdentifier
      break
    }
  }
  
  /// This function assigns component with an already calculated renderer
  /// This is a performance hack that skips layout for the component if it has already
  /// been layed out.
  public func reloadWithExisting(component: Component, renderer: Renderer) {
    self.component = component
    self.renderer = renderer
    reloadCount += 1
    shouldUpdateViewOnNextRender = true
    needsReload = false
    needsRender = true
  }

  /// calculate the size for the current component
  func sizeThatFits(_ size: CGSize) -> CGSize {
    return component?.layout(Constraint(maxSize: size)).size ?? .zero
  }
}
