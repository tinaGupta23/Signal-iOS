//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "NSDate+millisecondTimeStamp.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import "OWSDisappearingMessagesFinder.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSFakeContactsManager.h"
#import "TSContactThread.h"
#import "TSMessage.h"
#import "TSStorageManager.h"
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSDisappearingMessagesJob (Testing)

- (void)run;
- (void)becomeConsistentWithConfigurationForMessage:(TSMessage *)message
                                    contactsManager:(id<ContactsManagerProtocol>)contactsManager;

@end

@interface OWSDisappearingMessagesJobTest : XCTestCase

@end

@implementation OWSDisappearingMessagesJobTest

- (void)setUp
{
    [super setUp];
    [TSMessage removeAllObjectsInCollection];
}

- (void)testRemoveAnyExpiredMessage
{
    TSThread *thread = [TSContactThread getOrCreateThreadWithContactId:@"fake-thread-id"];
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    TSMessage *expiredMessage1 = [[TSMessage alloc] initWithTimestamp:1
                                                             inThread:thread
                                                          messageBody:@"expiredMessage1"
                                                        attachmentIds:@[]
                                                     expiresInSeconds:1
                                                      expireStartedAt:now - 20000];
    [expiredMessage1 save];

    TSMessage *expiredMessage2 = [[TSMessage alloc] initWithTimestamp:1
                                                             inThread:thread
                                                          messageBody:@"expiredMessage2"
                                                        attachmentIds:@[]
                                                     expiresInSeconds:2
                                                      expireStartedAt:now - 2001];
    [expiredMessage2 save];

    TSMessage *notYetExpiredMessage = [[TSMessage alloc] initWithTimestamp:1
                                                                  inThread:thread
                                                               messageBody:@"notYetExpiredMessage"
                                                             attachmentIds:@[]
                                                          expiresInSeconds:20
                                                           expireStartedAt:now - 10000];
    [notYetExpiredMessage save];

    TSMessage *unExpiringMessage = [[TSMessage alloc] initWithTimestamp:1
                                                               inThread:thread
                                                            messageBody:@"unexpiringMessage"
                                                          attachmentIds:@[]
                                                       expiresInSeconds:0
                                                        expireStartedAt:0];
    [unExpiringMessage save];

    
    OWSDisappearingMessagesJob *job = [OWSDisappearingMessagesJob sharedJob];

    // Sanity Check.
    XCTAssertEqual(4, [TSMessage numberOfKeysInCollection]);
    [job run];
    
    //FIXME remove sleep hack in favor of expiringMessage completion handler
    sleep(4);
    XCTAssertEqual(2, [TSMessage numberOfKeysInCollection]);
}

- (void)testBecomeConsistentWithMessageConfiguration
{
    TSThread *thread = [TSContactThread getOrCreateThreadWithContactId:@"fake-thread-id"];
    [thread save];

    OWSDisappearingMessagesJob *job = [OWSDisappearingMessagesJob sharedJob];
    
    OWSDisappearingMessagesConfiguration *configuration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:thread.uniqueId];
    [configuration remove];

    TSMessage *expiringMessage = [[TSMessage alloc] initWithTimestamp:1
                                                             inThread:thread
                                                          messageBody:@"notYetExpiredMessage"
                                                        attachmentIds:@[]
                                                     expiresInSeconds:20
                                                      expireStartedAt:0];
    [expiringMessage save];

    [job becomeConsistentWithConfigurationForMessage:expiringMessage contactsManager:[OWSFakeContactsManager new]];
    configuration = [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:thread.uniqueId];

    XCTAssertNotNil(configuration);
    XCTAssert(configuration.isEnabled);
    XCTAssertEqual(20, configuration.durationSeconds);
}

- (void)testBecomeConsistentWithUnexpiringMessageConfiguration
{
    TSThread *thread = [TSContactThread getOrCreateThreadWithContactId:@"fake-thread-id"];
    [thread save];

    OWSDisappearingMessagesConfiguration *configuration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:thread.uniqueId];
    [configuration remove];

    TSMessage *unExpiringMessage = [[TSMessage alloc] initWithTimestamp:1
                                                               inThread:thread
                                                            messageBody:@"unexpiringMessage"
                                                          attachmentIds:@[]
                                                       expiresInSeconds:0
                                                        expireStartedAt:0];
    [unExpiringMessage save];
    [OWSDisappearingMessagesJob becomeConsistentWithConfigurationForMessage:unExpiringMessage contactsManager:[OWSFakeContactsManager new]];
    XCTAssertNil([OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:thread.uniqueId]);
}

@end

NS_ASSUME_NONNULL_END
