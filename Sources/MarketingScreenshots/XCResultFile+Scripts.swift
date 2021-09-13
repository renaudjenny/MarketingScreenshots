import XCResultKit

extension XCResultFile {
    var testPlanSummariesId: String? {
        getInvocationRecord()?.actions.first?.actionResult.testsRef?.id
    }

    func screenshotAttachmentPayloadId(summaryId: String) -> String? {
        print("###")
        print(getActionTestSummary(id: summaryId))
        print("#1")
        print(getActionTestSummary(id: summaryId)?.activitySummaries.first(where: {
            $0.activityType == "com.apple.dt.xctest.activity-type.attachmentContainer"
        }))
        print("#2")
        print(getActionTestSummary(id: summaryId)?.activitySummaries.first(where: {
            $0.activityType == "com.apple.dt.xctest.activity-type.attachmentContainer"
        })?.attachments.first)
        print("#3")
        print(getActionTestSummary(id: summaryId)?.activitySummaries.first(where: {
            $0.activityType == "com.apple.dt.xctest.activity-type.attachmentContainer"
        })?.attachments.first?.payloadRef?.id)
        print("###")

        return getActionTestSummary(id: summaryId)?
            .activitySummaries.first(where: {
                $0.activityType == "com.apple.dt.xctest.activity-type.attachmentContainer"
            })?
            .attachments.first?
            .payloadRef?.id
    }
}

extension ActionTestPlanRunSummary {
    var screenshotTests: [ActionTestMetadata]? {
        testableSummaries.first?
            .tests.first?
            .subtestGroups.first?
            .subtestGroups.first?
            .subtests
    }
}
