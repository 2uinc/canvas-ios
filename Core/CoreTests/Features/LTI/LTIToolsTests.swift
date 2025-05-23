//
// This file is part of Canvas.
// Copyright (C) 2019-present  Instructure, Inc.
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

import SafariServices
import XCTest
@testable import Core

class LTIToolsTests: CoreTestCase {
    class MockView: UIViewController {
        var presented: UIViewController?
        override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
            presented = viewControllerToPresent
            completion?()
        }
    }
    let mockView = MockView()

    var didOpenExternalURL: URL?

    override func tearDown() {
        UserDefaults.standard.set(nil, forKey: "open_lti_safari")
        super.tearDown()
    }

    func testInitLink() {
        XCTAssertNil(LTITools(link: nil, navigationType: .linkActivated, env: environment))
        XCTAssertNil(LTITools(link: URL(string: "/"), navigationType: .linkActivated, env: environment))
        XCTAssertNil(LTITools(link: URL(string: "https://else.where/external_tools/retrieve?url=/"), navigationType: .linkActivated, env: environment))
        XCTAssertEqual(LTITools(link: URL(string: "/external_tools/retrieve?url=/", relativeTo: environment.api.baseURL), navigationType: .linkActivated, env: environment)?.url, URL(string: "/"))
        XCTAssertEqual(LTITools(link: URL(string: "/courses/1/external_tools/2", relativeTo: environment.api.baseURL), navigationType: .other, env: environment)?.id, "2")
        XCTAssertEqual(LTITools(link: URL(string: "/courses/1/external_tools/2?display=borderless", relativeTo: environment.api.baseURL), navigationType: .linkActivated, env: environment)?.id, nil)
    }

    func testInitLinkContext() {
        let defaultContext = LTITools(
            link: URL(string: "/external_tools/retrieve?url=/", relativeTo: environment.api.baseURL),
            navigationType: .linkActivated,
            env: environment
        )
        XCTAssertEqual(defaultContext?.context.contextType, .account)
        XCTAssertEqual(defaultContext?.context.id, "self")

        let course = LTITools(
            link: URL(string: "/courses/1/external_tools/retrieve?url=/", relativeTo: environment.api.baseURL),
            navigationType: .linkActivated,
            env: environment
        )
        XCTAssertEqual(course?.context.contextType, .course)
        XCTAssertEqual(course?.context.id, "1")

        let account = LTITools(
            link: URL(string: "/accounts/2/external_tools/retrieve?url=/", relativeTo: environment.api.baseURL),
            navigationType: .linkActivated,
            env: environment
        )
        XCTAssertEqual(account?.context.contextType, .account)
        XCTAssertEqual(account?.context.id, "2")

        let querylessExternalTool = LTITools(
            link: URL(string: "/courses/1/external_tools/2", relativeTo: environment.api.baseURL),
            navigationType: .other,
            env: environment
        )
        XCTAssertEqual(querylessExternalTool?.context.contextType, .course)
        XCTAssertEqual(querylessExternalTool?.context.id, "1")
        XCTAssertEqual(querylessExternalTool?.launchType, .course_navigation)

        let queriedExternalTool = LTITools(
            link: URL(string: "/courses/1/external_tools/2?display=borderless", relativeTo: environment.api.baseURL),
            navigationType: .linkActivated,
            env: environment
        )
        XCTAssertEqual(queriedExternalTool, nil)
    }

    func testGetSessionlessLaunchURL() {
        let tools = LTITools(
            context: .course("1"),
            id: nil,
            url: nil,
            launchType: nil,
            isQuizLTI: nil,
            assignmentID: nil,
            moduleItemID: nil,
            env: environment
        )
        let request = GetSessionlessLaunchURLRequest(context: .course("1"),
                                                     id: nil,
                                                     url: nil,
                                                     assignmentID: nil,
                                                     moduleItemID: nil,
                                                     launchType: nil,
                                                     resourceLinkLookupUUID: nil)
        let actualURL = URL(string: "/someplace")!

        api.mock(request, value: nil)
        var url: URL?
        let doneNil = expectation(description: "callback completed")
        tools.getSessionlessLaunchURL { result in
            url = result
            doneNil.fulfill()
        }
        wait(for: [doneNil], timeout: 1)
        XCTAssertNil(url)

        api.mock(request, value: nil, error: APIRequestableError.invalidPath(""))
        let doneError = expectation(description: "callback completed")
        tools.getSessionlessLaunchURL { result in
            url = result
            doneError.fulfill()
        }
        wait(for: [doneError], timeout: 1)
        XCTAssertNil(url)

        api.mock(request, value: .make(url: actualURL))
        let doneValue = expectation(description: "callback completed")
        tools.getSessionlessLaunchURL { result in
            url = result
            doneValue.fulfill()
        }
        wait(for: [doneValue], timeout: 1)
        XCTAssertEqual(url, actualURL)
    }

    func testPresentTool() throws {
        let tools = LTITools(
            context: .course("1"),
            id: nil,
            url: nil,
            launchType: nil,
            isQuizLTI: nil,
            assignmentID: nil,
            moduleItemID: nil,
            env: environment
        )
        let request = GetSessionlessLaunchURLRequest(context: .course("1"),
                                                     id: nil,
                                                     url: nil,
                                                     assignmentID: nil,
                                                     moduleItemID: nil,
                                                     launchType: nil,
                                                     resourceLinkLookupUUID: nil)
        let actualURL = URL(string: "https://canvas.instructure.com")!

        api.mock(request, value: nil)
        var success = false
        let doneNil = expectation(description: "callback completed")
        tools.presentTool(from: mockView, animated: false) { result in
            success = result
            doneNil.fulfill()
        }
        wait(for: [doneNil], timeout: 1)
        XCTAssertFalse(success)
        XCTAssertNil(mockView.presented)

        api.mock(request, value: nil, error: APIRequestableError.invalidPath(""))
        let doneError = expectation(description: "callback completed")
        tools.presentTool(from: mockView, animated: false) { result in
            success = result
            doneError.fulfill()
        }
        wait(for: [doneError], timeout: 1)
        XCTAssertFalse(success)
        XCTAssertNil(mockView.presented)

        api.mock(request, value: .make(url: actualURL))
        let doneValue = expectation(description: "callback completed")
        tools.presentTool(from: mockView, animated: false) { result in
            success = result
            doneValue.fulfill()
        }
        wait(for: [doneValue], timeout: 1)
        XCTAssertTrue(success)
        let sfSafari = try XCTUnwrap(router.presented as? SFSafariViewController)
        XCTAssert(router.lastRoutedTo(viewController: sfSafari, from: mockView, withOptions: .modal(.overFullScreen)))
    }

    func testPresentToolInSafariProper() {
        let tools = LTITools(isQuizLTI: nil, env: environment)
        let request = GetSessionlessLaunchURLRequest(context: tools.context,
                                                     id: nil,
                                                     url: nil,
                                                     assignmentID: nil,
                                                     moduleItemID: nil,
                                                     launchType: nil,
                                                     resourceLinkLookupUUID: nil)
        let url = URL(string: "https://canvas.instructure.com")!
        api.mock(request, value: .make(url: url))
        UserDefaults.standard.set(true, forKey: "open_lti_safari")
        tools.presentTool(from: mockView, animated: true)
        XCTAssertEqual(login.externalURL, url.appendingQueryItems(URLQueryItem(name: "platform", value: "mobile")))
        XCTAssertNil(router.presented)
    }

    func testPresentQuizLTI() throws {
        let tools = LTITools(isQuizLTI: true, env: environment)
        let request = GetSessionlessLaunchURLRequest(context: tools.context,
                                                     id: nil,
                                                     url: nil,
                                                     assignmentID: nil,
                                                     moduleItemID: nil,
                                                     launchType: nil,
                                                     resourceLinkLookupUUID: nil)
        let url = URL(string: "https://canvas.instructure.com")!
        api.mock(request, value: .make(name: "Google Apps", url: url))
        tools.presentTool(from: mockView, animated: true)
        let controller = try XCTUnwrap(router.presented as? CoreWebViewController)
        XCTAssertTrue(router.lastRoutedTo(viewController: controller, from: mockView, withOptions: .modal(.overFullScreen, embedInNav: true)))
    }

    func testPresentGoogleApp() throws {
        let tools = LTITools(isQuizLTI: nil, env: environment)
        let request = GetSessionlessLaunchURLRequest(context: tools.context,
                                                     id: nil,
                                                     url: nil,
                                                     assignmentID: nil,
                                                     moduleItemID: nil,
                                                     launchType: nil,
                                                     resourceLinkLookupUUID: nil)
        let url = URL(string: "https://canvas.instructure.com")!
        api.mock(request, value: .make(name: "Google Apps", url: url))
        tools.presentTool(from: mockView, animated: true)
        let controller = try XCTUnwrap(router.presented as? GoogleCloudAssignmentViewController)
        XCTAssertTrue(router.lastRoutedTo(viewController: controller, from: mockView, withOptions: .modal(.overFullScreen, embedInNav: true, addDoneButton: true)))
    }

    func testPresentStudio() throws {
        let url = URL(string: "https://canvas.instructure.com?custom_arc_launch_type=global_nav")!
        let tools = LTITools(url: url, isQuizLTI: nil, env: environment)
        let request = GetSessionlessLaunchURLRequest(context: tools.context,
                                                     id: nil,
                                                     url: url,
                                                     assignmentID: nil,
                                                     moduleItemID: nil,
                                                     launchType: nil,
                                                     resourceLinkLookupUUID: nil)

        api.mock(request, value: .make(name: "", url: .make()))
        tools.presentTool(from: mockView, animated: true)

        let controller = try XCTUnwrap(router.presented as? StudioViewController)
        XCTAssertTrue(router.lastRoutedTo(viewController: controller,
                                          from: mockView,
                                          withOptions: .modal(
                                            .overFullScreen,
                                            embedInNav: false,
                                            addDoneButton: false
                                          )))
    }

    func testMarksModuleItemAsRead() {
        api.mock(PostMarkModuleItemRead(courseID: "1", moduleID: "2", moduleItemID: "3"))
        let tools = LTITools(context: .course("1"), launchType: .module_item, isQuizLTI: nil, moduleID: "2", moduleItemID: "3", env: environment)
        let request = GetSessionlessLaunchURLRequest(context: tools.context,
                                                     id: nil,
                                                     url: nil,
                                                     assignmentID: nil,
                                                     moduleItemID: "3",
                                                     launchType: .module_item,
                                                     resourceLinkLookupUUID: nil)
        api.mock(request, value: .make())
        let expectation = XCTestExpectation(description: "notification was sent")
        let observer = NotificationCenter.default.addObserver(forName: .CompletedModuleItemRequirement, object: nil, queue: nil) { _ in
            expectation.fulfill()
        }
        tools.presentTool(from: mockView, animated: true)
        wait(for: [expectation], timeout: 1)
        NotificationCenter.default.removeObserver(observer)
    }

    func testPresentWhenURLIsAlreadySessionlessLaunch() {
        let url = URL(string: "https://canvas.instructure.com/courses/1/external_tools/sessionless_launch")!
        let tools = LTITools(
            context: nil,
            id: nil,
            url: url,
            launchType: nil,
            isQuizLTI: nil,
            assignmentID: nil,
            moduleItemID: nil,
            env: environment
        )
        let data = try! APIJSONEncoder().encode(APIGetSessionlessLaunchResponse.make())
        api.mock(url: url, data: data)
        var success = false
        let done = XCTestExpectation(description: "present tool callback")
        tools.presentTool(from: mockView, animated: false) { result in
            success = result
            done.fulfill()
        }
        wait(for: [done], timeout: 1)
        XCTAssertTrue(success)
    }

    func testConvenienceInitSucceedingWithResourceLinkLookupUUID() {
        let url = URL(string: "https://canvas.instructure.com/courses/1/external_tools/retrieve?resource_link_lookup_uuid=123")!
        let testee = LTITools(link: url, navigationType: .linkActivated, env: environment)

        guard let testee = testee else {
            return XCTFail()
        }

        XCTAssertEqual(testee.resourceLinkLookupUUID, "123")
        XCTAssertEqual(testee.request.resourceLinkLookupUUID, "123")
    }
}
