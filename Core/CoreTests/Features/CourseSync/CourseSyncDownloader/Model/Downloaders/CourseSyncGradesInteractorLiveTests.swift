//
// This file is part of Canvas.
// Copyright (C) 2023-present  Instructure, Inc.
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

@testable import Core
import XCTest

class CourseSyncGradesInteractorLiveTests: CoreTestCase {
    private var testee: CourseSyncGradesInteractorLive!

    override func setUp() {
        super.setUp()
        envResolver.userIdOverride = "testUser"
        testee = CourseSyncGradesInteractorLive(envResolver: envResolver)

        mockCourseColors()
        mockGradingPeriods()
        mockCourse()
        mockEnrollments()
        mockAssignments()
    }

    override func tearDown() {
        testee = nil
        envResolver.userIdOverride = nil
        super.tearDown()
    }

    func testSuccessfulSync() {
        XCTAssertFinish(testee.getContent(courseId: "testCourse"))
    }

    func testColorSyncFailure() {
        mockCourseColorsFailure()
        XCTAssertFailure(testee.getContent(courseId: "testCourse"))
    }

    func testGradingPeriodsSyncFailure() {
        mockGradingPeriodsFailure()
        XCTAssertFailure(testee.getContent(courseId: "testCourse"))
    }

    func testCourseSyncFailure() {
        mockCourseFailure()
        XCTAssertFailure(testee.getContent(courseId: "testCourse"))
    }

    func testEnrollmentsSyncFailure() {
        mockEnrollmentsFailure()
        XCTAssertFailure(testee.getContent(courseId: "testCourse"))
    }

    func testAssignmentsSyncFailure() {
        mockAssignmentsFailure()
        XCTAssertFailure(testee.getContent(courseId: "testCourse"))
    }

    // MARK: - Helpers

    // MARK: Colors

    private func mockCourseColors() {
        api.mock(GetCustomColors(), value: .init(custom_colors: [:]))
    }

    private func mockCourseColorsFailure() {
        api.mock(GetCustomColors(), error: NSError.instructureError(""))
    }

    // MARK: Grading Periods

    private func mockGradingPeriods() {
        api.mock(GetGradingPeriods(courseID: "testCourse"),
                 value: [.make(id: "testGradingPeriod")])
    }

    private func mockGradingPeriodsFailure() {
        api.mock(GetGradingPeriods(courseID: "testCourse"),
                 error: NSError.instructureError(""))
    }

    // MARK: Course

    private func mockCourse() {
        let mockEnrollment = APIEnrollment.make(id: nil,
                                                enrollment_state: .active,
                                                type: "StudentEnrollment",
                                                user_id: "testUser",
                                                current_grading_period_id: "testGradingPeriod")
        api.mock(GetCourse(courseID: "testCourse"),
                 value: .make(id: "testCourse", enrollments: [mockEnrollment]))
    }

    private func mockCourseFailure() {
        api.mock(GetCourse(courseID: "testCourse"),
                 error: NSError.instructureError(""))
    }

    // MARK: Enrollments

    private let enrollmentUseCase = GetEnrollments(context: .course("testCourse"),
                                                   userID: "testUser",
                                                   gradingPeriodID: "testGradingPeriod",
                                                   types: ["StudentEnrollment"],
                                                   states: [.active])
    private func mockEnrollments() {
        api.mock(enrollmentUseCase,
                 value: [])
    }

    private func mockEnrollmentsFailure() {
        api.mock(enrollmentUseCase,
                 error: NSError.instructureError(""))
    }

    // MARK: Assignments

    private let assignmentsRequest = GetAssignmentGroupsRequest(
        courseID: "testCourse",
        gradingPeriodID: "testGradingPeriod",
        perPage: 100
    )

    private let assignmentsWithoutGradingPeriodRequest = GetAssignmentGroupsRequest(
        courseID: "testCourse",
        gradingPeriodID: nil,
        perPage: 100
    )

    private func mockAssignments() {
        api.mock(assignmentsRequest,
                 value: [])
        api.mock(assignmentsWithoutGradingPeriodRequest,
                 value: [])
    }

    private func mockAssignmentsFailure() {
        api.mock(assignmentsRequest,
                 error: NSError.instructureError(""))
    }
}
