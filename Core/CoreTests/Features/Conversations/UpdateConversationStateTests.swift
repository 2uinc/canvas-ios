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

import XCTest
@testable import Core

class UpdateConversationStateTests: CoreTestCase {

    func testPostRequest() {
        let conversationId = "testId"
        let newState = ConversationWorkflowState.read
        let useCase = UpdateConversationState(id: conversationId, state: newState)
        let result = APIConversation.make()
        api.mock(useCase.request, value: result)

        let expectation = XCTestExpectation(description: "make request")
        useCase.makeRequest(environment: environment) { (conversation, _, _) in
            expectation.fulfill()
            XCTAssertEqual(conversation?.id, result.id)
        }
        wait(for: [expectation], timeout: 1)
    }

    func testPostRequestError() {
        let conversationId = "testId"
        let newState = ConversationWorkflowState.read
        let useCase = UpdateConversationState(id: conversationId, state: newState)
        api.mock(useCase.request, error: NSError.instructureError("Error"))

        let expectation = XCTestExpectation(description: "make request")
        useCase.makeRequest(environment: environment) { (_, _, error) in
            expectation.fulfill()
            XCTAssertNotNil(error)
        }
        wait(for: [expectation], timeout: 1)
    }

    func testScope() {
        let conversationId = "testId"
        let newState = ConversationWorkflowState.read
        let useCase = UpdateConversationState(id: conversationId, state: newState)

        XCTAssertEqual(useCase.scope.predicate, NSPredicate(key: #keyPath(InboxMessageListItem.messageId), equals: conversationId))
    }

    func testWrite() {
        let conversationId = "testId"
        let newState = ConversationWorkflowState.read
        let useCase = UpdateConversationState(id: conversationId, state: newState)
        let apiconversation = APIConversation.make(workflow_state: .unread)
        Conversation.save(apiconversation, in: databaseClient)
        InboxMessageListItem.save(
            apiconversation,
            currentUserID: AppEnvironment.shared.currentSession?.userID ?? "",
            isSent: false,
            contextFilter: .none,
            scopeFilter: .sent,
            in: databaseClient
        )

        XCTAssertEqual((databaseClient.fetch() as [Conversation]).count, 1)
        XCTAssertEqual((databaseClient.fetch() as [Conversation]).first?.workflowState, .unread)

        let response = APIConversation.make(workflow_state: .read)
        useCase.write(response: response, urlResponse: nil, to: databaseClient)

        XCTAssertEqual((databaseClient.fetch() as [Conversation]).count, 1)
        XCTAssertEqual((databaseClient.fetch() as [Conversation]).first?.workflowState, newState)
    }
}
