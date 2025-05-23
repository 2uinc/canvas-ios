//
// This file is part of Canvas.
// Copyright (C) 2024-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import UIKit
import Combine

public class CoreSplitViewController: UISplitViewController {

    private var subscriptions = Set<AnyCancellable>()

    /// Introduced to get around the issue where SplitViewController
    /// report collapse then expansion when app is put to background.
    /// This property is used to cache secondary controller to be returned
    /// on expansion state configuration (secondary separation delegate's method)
    private var preBackgroundedSecondaryController: UIViewController?

    public override init(nibName: String? = nil, bundle: Bundle? = nil) {
        super.init(nibName: nibName, bundle: bundle)
        delegate = self
        setupBackgroundStateObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredDisplayMode = .oneBesideSecondary
        registerForTraitChanges()
    }

    private func setupBackgroundStateObservers() {
        NotificationCenter
            .default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .mapToVoid()
            .sink { [weak self] in
                self?.saveCurrentSecondaryController()
            }
            .store(in: &subscriptions)

        NotificationCenter
            .default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .mapToVoid()
            .sink { [weak self] in
                self?.removePreBackgroundedSecondaryController()
            }
            .store(in: &subscriptions)
    }

    private func saveCurrentSecondaryController() {
        preBackgroundedSecondaryController = viewControllers.last
    }

    private func removePreBackgroundedSecondaryController() {
        preBackgroundedSecondaryController = nil
    }

    public override var prefersStatusBarHidden: Bool {
        return masterNavigationController?.prefersStatusBarHidden ?? false
    }

    public override func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        super.showDetailViewController(vc, sender: sender)
        self.masterNavigationController?.syncStyles()
    }

    public override func show(_ vc: UIViewController, sender: Any?) {
        super.show(vc, sender: sender)
        self.masterNavigationController?.syncStyles()
    }

    private func updateTitleViews() {
        // Recreating the titleView seems to be the most reliable way to get it to draw
        // correctly when the traitCollection changes on iPad
        if let titleView = masterTopViewController?.navigationItem.titleView as? TitleSubtitleView {
            masterTopViewController?.navigationItem.titleView = titleView.recreate()
        }
        if let titleView = detailTopViewController?.navigationItem.titleView as? TitleSubtitleView {
            detailTopViewController?.navigationItem.titleView = titleView.recreate()
        }
    }

    public func prettyDisplayModeButtonItem(_ displayMode: DisplayMode) -> UIBarButtonItem {
        let defaultButton = self.displayModeButtonItem
        let collapse = displayMode == .oneOverSecondary || displayMode == .secondaryOnly
        let icon: UIImage = collapse ? .exitFullScreenLine : .fullScreenLine
        let prettyButton = UIBarButtonItem(image: icon, style: .plain, target: defaultButton.target, action: defaultButton.action)
        prettyButton.accessibilityLabel = collapse ?
            String(localized: "Collapse detail view", bundle: .core) :
            String(localized: "Expand detail view", bundle: .core)
        return prettyButton
    }

    private func registerForTraitChanges() {
        let traits: [UITrait] = [UITraitVerticalSizeClass.self, UITraitHorizontalSizeClass.self, UITraitLayoutDirection.self]
        registerForTraitChanges(traits) { (self: CoreSplitViewController, _) in
            self.updateTitleViews()
        }
    }
}

extension CoreSplitViewController: UISplitViewControllerDelegate {
    public func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
        if svc.viewControllers.count == 2 {
            let top = (svc.viewControllers.last as? UINavigationController)?.topViewController
            top?.navigationItem.leftItemsSupplementBackButton = true
            if top?.isKind(of: EmptyViewController.self) == false {
                top?.navigationItem.leftBarButtonItem = prettyDisplayModeButtonItem(displayMode)
                NotificationCenter.default.post(name: NSNotification.Name.SplitViewControllerWillChangeDisplayModeNotification, object: self)
            }
        }
    }

    public func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {

        guard preBackgroundedSecondaryController == nil else { return false }

        if let nav = secondaryViewController as? UINavigationController {
            // swiftlint:disable:next unused_optional_binding
            if let _ = nav.topViewController as? EmptyViewController {
                return true
            } else {
                // Remove the display mode button item
                for vc in nav.viewControllers {
                    vc.navigationItem.leftBarButtonItem = nil
                }
            }
        }

        return false
    }

    public func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {

        // Return cached secondary controller when called on background
        if let secondaryView = preBackgroundedSecondaryController { return secondaryView }

        // Setup default detail view provided by the master view controller
        if let nav = primaryViewController as? UINavigationController,
           nav.viewControllers.count > 1,
           let defaultViewProvider = nav.viewControllers.last as? DefaultViewProvider,
           let defaultRoute = defaultViewProvider.defaultViewRoute,
           let defaultViewController = AppEnvironment.shared.router.match(defaultRoute.url, userInfo: defaultRoute.userInfo) {
            let detailNavController = CoreNavigationController(rootViewController: defaultViewController)
            detailNavController.syncStyles(from: nav, to: detailNavController)

            if let routeTemplate = AppEnvironment.shared.router.template(for: defaultRoute.url) {
                RemoteLogger.shared.logBreadcrumb(route: routeTemplate, viewController: defaultViewController)
            }

            return detailNavController
        }

        // Default behaviour of putting the current top viewcontroller into a nav controller and moving it to the detail view
        if let nav = primaryViewController as? UINavigationController, nav.viewControllers.count >= 2 {
            var newDeets = nav.viewControllers[nav.viewControllers.count - 1]
            nav.popViewController(animated: true)

            if !(newDeets is UINavigationController) {
                newDeets = CoreNavigationController(rootViewController: newDeets)
            }

            let viewControllers = (newDeets as? UINavigationController)?.viewControllers ?? [newDeets]
            for vc in viewControllers {
                vc.navigationItem.leftItemsSupplementBackButton = true
                vc.navigationItem.leftBarButtonItem = prettyDisplayModeButtonItem(splitViewController.displayMode)
            }

            if let nav = newDeets as? UINavigationController {
                // If newDeets is a newly created navigation controller then it won't have a splitViewController yet, so syncStyles() won't work at this point.
                if newDeets.splitViewController == nil, let masterNav = primaryViewController as? UINavigationController {
                    nav.syncStyles(from: masterNav, to: nav)
                } else {
                    nav.syncStyles()
                }
            }

            // Updating titles again _after_ separation, because registering for trait changes
            // doesn't trigger it.
            updateTitleViews()

            return newDeets
        }

        return nil
    }
}

// - MARK: Master Navigation Controller Transition Actions

extension CoreSplitViewController: UINavigationControllerDelegate {

    /**
     This method gets called only when a real transition occurs. UINavigationControllerDelegate.willShow/didShow also
     gets called when the navigation controller is removed from the screen and re-added for example on a tab bar change
     event so we can't use those to determine when a view controller is pushed for the first time.
     */
    open func navigationController(_ navigationController: UINavigationController,
                                   animationControllerFor operation: UINavigationController.Operation,
                                   from fromVC: UIViewController,
                                   to toVC: UIViewController)
    -> UIViewControllerAnimatedTransitioning? {
        toVC.showDefaultDetailViewIfNeeded()
        return nil
    }
}

// Needed for the above bug mentioned in comments
extension CoreSplitViewController: UIGestureRecognizerDelegate { }
