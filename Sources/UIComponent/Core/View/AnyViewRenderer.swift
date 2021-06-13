//
//  AnyViewRenderer.swift
//  
//
//  Created by Luke Zhao on 8/22/20.
//

import UIKit

public protocol AnyViewRenderer: Renderer {
  var id: String? { get }
  var keyPath: String { get }
  var animator: Animator? { get }
  func _makeView() -> UIView
  func _updateView(_ view: UIView)
}

public extension AnyViewRenderer {
  var id: String? { nil }
  var animator: Animator? { nil }
  var keyPath: String { "\(type(of: self))" }

  func views(in frame: CGRect) -> [Renderable] {
    let childFrame = CGRect(origin: .zero, size: size)
    if frame.intersects(childFrame) {
      return [Renderable(id: id,
                         keyPath: keyPath,
                         animator: animator,
                         renderer: self,
                         frame: childFrame)]
    }
    return []
  }
}
