//
//  Navigator.swift
//  
//
//  Created by Shaban on 03/01/2022.
//

import SwiftUI

public class Navigator: ObservableObject {
    var lastNavigationType = NavigationDirection.push
    /// Customizable animation to apply in pop and push transitions
    private let easeAnimation: Animation
    @Published var sheetRoot: BackStackElement?
    @Published var currentView: BackStackElement?
    @Published var lastView: BackStackElement?
    @Published var presentSheet: Bool = false
    @Published var presentFullSheetView: Bool = false
    var sheetView: AnyView? = nil
    var showDefaultNavBar: Bool = true

    private var backStack = BackStack() {
        didSet {
            lastView = currentView
            currentView = backStack.peek()
        }
    }
    var isPresentingSheet: Bool {
        sheetView != nil
    }

    public init(easeAnimation: Animation, showDefaultNavBar: Bool = true) {
        self.easeAnimation = easeAnimation
        self.showDefaultNavBar = showDefaultNavBar
    }
}

extension Navigator {

    /// Navigates to a view.
    /// - Parameters:
    ///   - element: The destination view.
    ///   - identifier: The ID of the destination view (used to easily come back to it if needed).
    public func navigate<Element: View>(
            _ element: Element,
            type: NavigationType = .push(),
            delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.navigate(element, type: type)
        }
    }

    /// Navigates to a view.
    /// - Parameters:
    ///   - element: The destination view.
    ///   - identifier: The ID of the destination view (used to easily come back to it if needed).
    public func navigate<Element: View>(
            _ element: Element,
            type: NavigationType = .push(),
            showDefaultNavBar: Bool? = nil) {
        switch type {
        case let .push(id, addToBackStack):
            self.push(
                    element, withId: id,
                    addToBackStack: addToBackStack,
                    showDefaultNavBar: showDefaultNavBar)
        case .sheet:
            self.presentSheet(element, showDefaultNavBar: showDefaultNavBar ?? false)
        case .fullSheet:
            if #available(iOS 14.0, *) {
                self.presentFullSheet(element, showDefaultNavBar: showDefaultNavBar)
            } else {
                return
            }
        }
    }

    /// Navigates to a view.
    /// - Parameters:
    ///   - element: The destination view.
    ///   - identifier: The ID of the destination view (used to easily come back to it if needed).
    public func push<Element: View>(
            _ element: Element,
            withId identifier: String? = nil,
            delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.push(element, withId: identifier)
        }
    }

}

extension Navigator {

    /// Navigates to a view.
    /// - Parameters:
    ///   - element: The destination view.
    ///   - identifier: The ID of the destination view (used to easily come back to it if needed).
    public func push<Element: View>(
            _ element: Element,
            withId identifier: String? = nil,
            addToBackStack: Bool = true,
            showDefaultNavBar: Bool? = nil) {
        withAnimation(easeAnimation) {
            lastNavigationType = .push
            let id = identifier == nil ? UUID().uuidString : identifier!

            let view = addNavBar(element, showDefaultNavBar: showDefaultNavBar)
            let element = BackStackElement(
                    id: id,
                    wrappedElement: view,
                    type: isPresentingSheet ? .sheet : .screen,
                    addToBackStack: addToBackStack)
            backStack.push(element)
        }
    }

    private func addNavBar<Element: View>(_ element: Element, showDefaultNavBar: Bool?) -> AnyView {
        canShowDefaultNavBar(showDefaultNavBar) ?
                AnyView(element.navBar()) :
                AnyView(element)
    }

    private func canShowDefaultNavBar(_ canShowInSingleView: Bool?) -> Bool {
        guard let canShowInSingleView = canShowInSingleView else {
            return showDefaultNavBar
        }
        return canShowInSingleView
    }

}

extension Navigator {

    public func presentSheet<Content: View>(_ content: Content, showDefaultNavBar: Bool = false) {
        let view = addNavBar(content, showDefaultNavBar: showDefaultNavBar)
        createSheetView(view)
        presentSheet = true
    }

    @available(iOS 14.0, *)
    public func presentFullSheet<Content: View>(_ content: Content, showDefaultNavBar: Bool? = nil) {
        let view = addNavBar(content, showDefaultNavBar: showDefaultNavBar)
        createSheetView(view)
        presentFullSheetView = true
    }

    private func createSheetView<Content: View>(_ content: Content) {
        if let tmp = currentView {
            sheetRoot = BackStackElement(
                    id: tmp.id,
                    wrappedElement: tmp.wrappedElement,
                    type: tmp.type,
                    addToBackStack: tmp.addToBackStack)
        }

        // Pass self as a Navigator to allow dismissing from the sheet
        sheetView = AnyView(NavigatorView(navigator: self, showDefaultNavBar: showDefaultNavBar) {
            content
        })
        let element = BackStackElement(
                id: UUID().uuidString,
                wrappedElement: AnyView(content),
                type: .sheet,
                addToBackStack: true)
        backStack.push(element)
    }

}

extension Navigator {

    public func dismissSheet() {
        backStack.popSheet()
        presentSheet = false
        presentFullSheetView = false
        sheetView = nil
        sheetRoot = nil
    }

    // TODO: improve doc
    /// Pop back stack.
    /// - Parameter to: The destination type of the transition operation.
    public func dismiss(
            to destination: DismissDestination = .previous,
            delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.dismiss(to: destination)
        }
    }

    public func dismiss(to destination: DismissDestination = .previous) {
        lastNavigationType = isPresentingSheet ? .none : .pop

        if backStack.isSheetEmpty {
            dismissSheet()
            return
        }

        withAnimation(easeAnimation) {
            switch destination {
            case .root:
                backStack.popToRoot()
            case .view(let viewId):
                backStack.popToView(withId: viewId)
            case .previous:
                backStack.popToPrevious()
            case .dismissSheet:
                dismissSheet()
            }
        }
    }

}

extension Navigator {

    enum NavigationDirection {
        case push
        case pop
        case none
    }

}


