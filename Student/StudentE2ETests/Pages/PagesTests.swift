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

import TestsFoundation
import XCTest

class PagesTests: E2ETestCase {
    func testFrontPageLoadsByDefault() {
        // MARK: Seed the usual stuff and a front page for the course
        let student = seeder.createUser()
        let course = seeder.createCourse()
        seeder.enrollStudent(student, in: course)
        let frontPage = DashboardHelper.createFrontPageForCourse(course: course)

        // MARK: Get the user logged in and check the course card
        logInDSUser(student)
        let courseCard = DashboardHelper.courseCard(course: course).waitUntil(.visible)
        XCTAssertTrue(courseCard.isVisible)

        // MARK: Check pages button
        courseCard.hit()
        let pagesButton = CourseDetailsHelper.cell(type: .pages).waitUntil(.visible)
        XCTAssertTrue(pagesButton.isVisible)

        // MARK: Check front page button
        pagesButton.hit()
        let frontPageButton = PagesHelper.frontPage.waitUntil(.visible)
        XCTAssertTrue(frontPageButton.isVisible)

        // MARK: Check title of front page
        frontPageButton.hit()
        let frontPageTitle = app.find(labelContaining: frontPage.title).waitUntil(.visible)
        XCTAssertTrue(frontPageTitle.isVisible)
    }

    func testDeepLinks() {
        // MARK: Seed the usual stuff and a front page containing some deep links
        let student = seeder.createUser()
        let course = seeder.createCourse()
        let assignmentName = "Deep Link Assignment"
        let assignment = AssignmentsHelper.createAssignment(course: course, name: assignmentName)
        let assignmentLink = PagesHelper.createLinkToAssignment(course: course, assignment: assignment)

        let discussionTitle = "Deep Link Discussion"
        let discussion = DiscussionsHelper.createDiscussion(course: course, title: discussionTitle)
        let discussionLink = PagesHelper.createLinkToDiscussion(course: course, discussion: discussion)

        let announcementTitle = "Deep Link Announcement"
        let announcement = DiscussionsHelper.createDiscussion(course: course, title: announcementTitle, isAnnouncement: true)
        let announcementLink = PagesHelper.createLinkToDiscussion(course: course, discussion: announcement)

        let body = "\(assignmentLink)\n\(discussionLink)\n\(announcementLink)"
        PagesHelper.createDeepLinkFrontPage(course: course, body: body)

        // MARK: Enroll student in the course and get the user logged in
        seeder.enrollStudent(student, in: course)
        logInDSUser(student)
        let courseCard = DashboardHelper.courseCard(course: course).waitUntil(.visible)
        XCTAssertTrue(courseCard.isVisible)

        // MARK: Navigate to the front page of the course
        PagesHelper.navigateToFrontPage(course: course)

        // MARK: Check deep link to the assignment
        let assignmentDeepLink = app.find(labelContaining: assignment.name).waitUntil(.visible)
        XCTAssertTrue(assignmentDeepLink.isVisible)

        assignmentDeepLink.hit()
        let assignmentDetailsNameLabel = AssignmentsHelper.Details.name.waitUntil(.visible)
        XCTAssertTrue(assignmentDetailsNameLabel.isVisible)

        // MARK: Check deep link to discussion
        AssignmentsHelper.Details.backButton.hit()
        let discussionDeepLink = app.find(labelContaining: discussion.title).waitUntil(.visible)
        XCTAssertTrue(discussionDeepLink.isVisible)

        discussionDeepLink.hit()
        let discussionDetailsTitle = DiscussionsHelper.NewDetails.discussionTitle(discussion: discussion).waitUntil(.visible)
        XCTAssertTrue(discussionDetailsTitle.isVisible)

        // MARK: Check deep link to announcement
        DiscussionsHelper.Details.backButton.hit()
        let announcementDeepLink = app.find(labelContaining: announcement.title).waitUntil(.visible)
        XCTAssertTrue(announcementDeepLink.isVisible)

        announcementDeepLink.hit()
        let announcementDetailsTitle = DiscussionsHelper.NewDetails.discussionTitle(discussion: announcement).waitUntil(.visible)
        XCTAssertTrue(announcementDetailsTitle.isVisible)
    }
}
