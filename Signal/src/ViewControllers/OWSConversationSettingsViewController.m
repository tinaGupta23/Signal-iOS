//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "OWSConversationSettingsViewController.h"
#import "BlockListUIUtils.h"
#import "ContactsViewHelper.h"
#import "Environment.h"
#import "FingerprintViewController.h"
#import "OWSAddToContactViewController.h"
#import "OWSAvatarBuilder.h"
#import "OWSBlockingManager.h"
#import "OWSContactsManager.h"
#import "OWSProfileManager.h"
#import "PhoneNumber.h"
#import "ShowGroupMembersViewController.h"
#import "Signal-Swift.h"
#import "UIFont+OWS.h"
#import "UIUtil.h"
#import "UIView+OWS.h"
#import "UpdateGroupViewController.h"
#import <25519/Curve25519.h>
#import <SignalServiceKit/NSDate+millisecondTimeStamp.h>
#import <SignalServiceKit/OWSDisappearingConfigurationUpdateInfoMessage.h>
#import <SignalServiceKit/OWSDisappearingMessagesConfiguration.h>
#import <SignalServiceKit/OWSMessageSender.h>
#import <SignalServiceKit/OWSNotifyRemoteOfUpdatedDisappearingConfigurationJob.h>
#import <SignalServiceKit/TSGroupThread.h>
#import <SignalServiceKit/TSOutgoingMessage.h>
#import <SignalServiceKit/TSStorageManager.h>
#import <SignalServiceKit/TSThread.h>

@import ContactsUI;

NS_ASSUME_NONNULL_BEGIN

@interface OWSConversationSettingsViewController () <ContactEditingDelegate, ContactsViewHelperDelegate>

@property (nonatomic) TSThread *thread;

@property (nonatomic) NSArray<NSNumber *> *disappearingMessagesDurations;
@property (nonatomic) OWSDisappearingMessagesConfiguration *disappearingMessagesConfiguration;

@property (nonatomic, readonly) TSStorageManager *storageManager;
@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) OWSBlockingManager *blockingManager;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) UIImageView *avatarView;
@property (nonatomic, readonly) UILabel *disappearingMessagesDurationLabel;

@end

#pragma mark -

@implementation OWSConversationSettingsViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (void)commonInit
{
    _storageManager = [TSStorageManager sharedManager];
    _contactsManager = [Environment getCurrent].contactsManager;
    _messageSender = [Environment getCurrent].messageSender;
    _blockingManager = [OWSBlockingManager sharedManager];
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];

    [self observeNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
}

- (NSString *)threadName
{
    NSString *threadName = self.thread.name;
    if ([threadName isEqualToString:self.thread.contactIdentifier]) {
        threadName =
            [PhoneNumber bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:self.thread.contactIdentifier];
    } else if (threadName.length == 0 && [self isGroupThread]) {
        threadName = NSLocalizedString(@"NEW_GROUP_DEFAULT_TITLE", @"");
    }
    return threadName;
}

- (BOOL)isGroupThread
{
    return [self.thread isKindOfClass:[TSGroupThread class]];
}

- (void)configureWithThread:(TSThread *)thread
{
    OWSAssert(thread);
    self.thread = thread;

    if ([self.thread isKindOfClass:[TSContactThread class]]) {
        self.title = NSLocalizedString(
            @"CONVERSATION_SETTINGS_CONTACT_INFO_TITLE", @"Navbar title when viewing settings for a 1-on-1 thread");
    } else {
        self.title = NSLocalizedString(
            @"CONVERSATION_SETTINGS_GROUP_INFO_TITLE", @"Navbar title when viewing settings for a group thread");
    }

    [self updateEditButton];
}

- (void)updateEditButton
{
    OWSAssert(self.thread);

    if ([self.thread isKindOfClass:[TSContactThread class]] && self.contactsManager.supportsContactEditing
        && self.hasExistingContact) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"EDIT_TXT", nil)
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(didTapEditButton)];
    }
}

- (BOOL)hasExistingContact
{
    OWSAssert([self.thread isKindOfClass:[TSContactThread class]]);
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    NSString *recipientId = contactThread.contactIdentifier;
    return self.contactsManager.allContactsMap[recipientId] != nil;
}

#pragma mark - ContactEditingDelegate

- (void)didFinishEditingContact
{
    [self updateTableContents];

    DDLogDebug(@"%@ %s", self.tag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - CNContactViewControllerDelegate

- (void)contactViewController:(CNContactViewController *)viewController
       didCompleteWithContact:(nullable CNContact *)contact
{
    [self updateTableContents];

    if (contact) {
        // Saving normally returns you to the "Show Contact" view
        // which we're not interested in, so we skip it here. There is
        // an unfortunate blip of the "Show Contact" view on slower devices.
        DDLogDebug(@"%@ completed editing contact.", self.tag);
        [self dismissViewControllerAnimated:NO completion:nil];
    } else {
        DDLogDebug(@"%@ canceled editing contact.", self.tag);
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    _disappearingMessagesDurationLabel = [UILabel new];

    self.disappearingMessagesDurations = [OWSDisappearingMessagesConfiguration validDurationsSeconds];

    self.disappearingMessagesConfiguration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId];

    if (!self.disappearingMessagesConfiguration) {
        self.disappearingMessagesConfiguration =
            [[OWSDisappearingMessagesConfiguration alloc] initDefaultWithThreadId:self.thread.uniqueId];
    }

    [self updateTableContents];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.showVerificationOnAppear) {
        self.showVerificationOnAppear = NO;
        if (self.isGroupThread) {
            [self showGroupMembersView];
        } else {
            [self showVerificationView];
        }
    }
}

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];
    contents.title = NSLocalizedString(@"CONVERSATION_SETTINGS", @"title for conversation settings screen");

    __weak OWSConversationSettingsViewController *weakSelf = self;

    // Main section.

    OWSTableSection *mainSection = [OWSTableSection new];

    mainSection.customHeaderView = [self mainSectionHeader];
    mainSection.customHeaderHeight = @(100.f);

    if ([self.thread isKindOfClass:[TSContactThread class]] && self.contactsManager.supportsContactEditing
        && !self.hasExistingContact) {
        [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            return
                [weakSelf disclosureCellWithName:NSLocalizedString(@"CONVERSATION_SETTINGS_NEW_CONTACT",
                                                     @"Label for 'new contact' button in conversation settings view.")
                                        iconName:@"table_ic_new_contact"];
        }
                                 actionBlock:^{
                                     [weakSelf presentContactViewController];
                                 }]];
        [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            return
                [weakSelf disclosureCellWithName:NSLocalizedString(@"CONVERSATION_SETTINGS_ADD_TO_EXISTING_CONTACT",
                                                     @"Label for 'new contact' button in conversation settings view.")
                                        iconName:@"table_ic_add_to_existing_contact"];
        }
                                 actionBlock:^{
                                     OWSConversationSettingsViewController *strongSelf = weakSelf;
                                     OWSCAssert(strongSelf);
                                     TSContactThread *contactThread = (TSContactThread *)strongSelf.thread;
                                     NSString *recipientId = contactThread.contactIdentifier;
                                     [strongSelf presentAddToContactViewControllerWithRecipientId:recipientId];
                                 }]];
    }

    if (!self.isGroupThread && self.thread.hasSafetyNumbers) {
        [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            return [weakSelf
                disclosureCellWithName:
                    NSLocalizedString(@"VERIFY_PRIVACY",
                        @"Label for button or row which allows users to verify the safety number of another user.")
                              iconName:@"table_ic_not_verified"];
        }
                                 actionBlock:^{
                                     [weakSelf showVerificationView];
                                 }]];
    }

    if ([OWSProfileManager.sharedManager isThreadInProfileWhitelist:self.thread]) {
        [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            return [weakSelf
                labelCellWithName:(self.isGroupThread
                                          ? NSLocalizedString(
                                                @"CONVERSATION_SETTINGS_VIEW_PROFILE_IS_SHARED_WITH_GROUP",
                                                @"Indicates that user's profile has been shared with a group.")
                                          : NSLocalizedString(@"CONVERSATION_SETTINGS_VIEW_PROFILE_IS_SHARED_WITH_USER",
                                                @"Indicates that user's profile has been shared with a user."))iconName
                                 :@"table_ic_share_profile"];
        }
                                                       actionBlock:nil]];
    } else {
        [mainSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
            return
                [weakSelf disclosureCellWithName:(self.isGroupThread
                                                         ? NSLocalizedString(
                                                               @"CONVERSATION_SETTINGS_VIEW_SHARE_PROFILE_WITH_GROUP",
                                                               @"Action that shares user profile with a group.")
                                                         : NSLocalizedString(
                                                               @"CONVERSATION_SETTINGS_VIEW_SHARE_PROFILE_WITH_USER",
                                                               @"Action that shares user profile with a user."))iconName
                                                :@"table_ic_share_profile"];
        }
                                 actionBlock:^{
                                     [weakSelf showShareProfileAlert];
                                 }]];
    }

    [mainSection
        addItem:[OWSTableItem itemWithCustomCellBlock:^{
            UITableViewCell *cell = [UITableViewCell new];
            OWSConversationSettingsViewController *strongSelf = weakSelf;
            OWSCAssert(strongSelf);
            cell.preservesSuperviewLayoutMargins = YES;
            cell.contentView.preservesSuperviewLayoutMargins = YES;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UIView *topView = [UIView containerView];
            [cell.contentView addSubview:topView];
            [topView autoPinLeadingAndTrailingToSuperview];
            [topView autoPinEdgeToSuperviewEdge:ALEdgeTop];
            [topView autoSetDimension:ALDimensionHeight toSize:kOWSTable_DefaultCellHeight];

            UIImageView *iconView = [strongSelf viewForIconWithName:@"table_ic_hourglass"];
            [topView addSubview:iconView];
            [iconView autoVCenterInSuperview];
            [iconView autoPinLeadingToSuperView];

            UILabel *rowLabel = [UILabel new];
            rowLabel.text = NSLocalizedString(@"DISAPPEARING_MESSAGES", @"table cell label in conversation settings");
            rowLabel.textColor = [UIColor blackColor];
            rowLabel.font = [UIFont ows_regularFontWithSize:17.f];
            rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [topView addSubview:rowLabel];
            [rowLabel autoVCenterInSuperview];
            [rowLabel autoPinLeadingToTrailingOfView:iconView margin:weakSelf.iconSpacing];

            UISwitch *switchView = [UISwitch new];
            switchView.on = strongSelf.disappearingMessagesConfiguration.isEnabled;
            [switchView addTarget:strongSelf
                           action:@selector(disappearingMessagesSwitchValueDidChange:)
                 forControlEvents:UIControlEventValueChanged];
            [topView addSubview:switchView];
            [switchView autoVCenterInSuperview];
            [switchView autoPinLeadingToTrailingOfView:rowLabel margin:weakSelf.iconSpacing];
            [switchView autoPinTrailingToSuperView];

            UILabel *subtitleLabel = [UILabel new];
            subtitleLabel.text
                = NSLocalizedString(@"DISAPPEARING_MESSAGES_DESCRIPTION", @"subheading in conversation settings");
            subtitleLabel.textColor = [UIColor blackColor];
            subtitleLabel.font = [UIFont ows_footnoteFont];
            subtitleLabel.numberOfLines = 0;
            subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
            [cell.contentView addSubview:subtitleLabel];
            [subtitleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:topView];
            [subtitleLabel autoPinEdge:ALEdgeLeading toEdge:ALEdgeLeading ofView:rowLabel];
            [subtitleLabel autoPinTrailingToSuperView];

            return cell;
        }
                                      // TODO: We shouldn't hard-code a row height that will contain the cell content.
                                      customRowHeight:108.f
                                          actionBlock:nil]];

    if (self.disappearingMessagesConfiguration.isEnabled) {
        [mainSection
            addItem:[OWSTableItem
                        itemWithCustomCellBlock:^{
                            UITableViewCell *cell = [UITableViewCell new];
                            OWSConversationSettingsViewController *strongSelf = weakSelf;
                            OWSCAssert(strongSelf);
                            cell.preservesSuperviewLayoutMargins = YES;
                            cell.contentView.preservesSuperviewLayoutMargins = YES;
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;

                            UIView *topView = [UIView containerView];
                            [cell.contentView addSubview:topView];
                            [topView autoPinLeadingAndTrailingToSuperview];
                            [topView autoPinEdgeToSuperviewEdge:ALEdgeTop];
                            [topView autoSetDimension:ALDimensionHeight toSize:kOWSTable_DefaultCellHeight];

                            UIImageView *iconView = [strongSelf viewForIconWithName:@"table_ic_hourglass"];
                            [topView addSubview:iconView];
                            [iconView autoVCenterInSuperview];
                            [iconView autoPinLeadingToSuperView];

                            UILabel *rowLabel = strongSelf.disappearingMessagesDurationLabel;
                            [strongSelf updateDisappearingMessagesDurationLabel];
                            rowLabel.textColor = [UIColor blackColor];
                            rowLabel.font = [UIFont ows_footnoteFont];
                            rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
                            [topView addSubview:rowLabel];
                            [rowLabel autoVCenterInSuperview];
                            [rowLabel autoPinLeadingToTrailingOfView:iconView margin:weakSelf.iconSpacing];

                            UISlider *slider = [UISlider new];
                            slider.maximumValue = (float)(strongSelf.disappearingMessagesDurations.count - 1);
                            slider.minimumValue = 0;
                            slider.continuous = YES; // NO fires change event only once you let go
                            slider.value = strongSelf.disappearingMessagesConfiguration.durationIndex;
                            [slider addTarget:strongSelf
                                          action:@selector(durationSliderDidChange:)
                                forControlEvents:UIControlEventValueChanged];
                            [cell.contentView addSubview:slider];
                            [slider autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:topView];
                            [slider autoPinEdge:ALEdgeLeading toEdge:ALEdgeLeading ofView:rowLabel];
                            [slider autoPinTrailingToSuperView];

                            return cell;
                        }
                                // TODO: We shouldn't hard-code a row height that will contain the cell content.
                                customRowHeight:84.f
                                    actionBlock:nil]];
    }

    [contents addSection:mainSection];

    // Group settings section.

    if (self.isGroupThread) {
        NSArray *groupItems = @[
            [OWSTableItem itemWithCustomCellBlock:^{
                return [weakSelf disclosureCellWithName:NSLocalizedString(@"EDIT_GROUP_ACTION",
                                                            @"table cell label in conversation settings")
                                               iconName:@"table_ic_group_edit"];
            }
                actionBlock:^{
                    [weakSelf showUpdateGroupView:UpdateGroupMode_Default];
                }],
            [OWSTableItem itemWithCustomCellBlock:^{
                return [weakSelf disclosureCellWithName:NSLocalizedString(@"LIST_GROUP_MEMBERS_ACTION",
                                                            @"table cell label in conversation settings")
                                               iconName:@"table_ic_group_members"];
            }
                actionBlock:^{
                    [weakSelf showGroupMembersView];
                }],
            [OWSTableItem itemWithCustomCellBlock:^{
                return [weakSelf disclosureCellWithName:NSLocalizedString(@"LEAVE_GROUP_ACTION",
                                                            @"table cell label in conversation settings")
                                               iconName:@"table_ic_group_leave"];
            }
                actionBlock:^{
                    [weakSelf didTapLeaveGroup];
                }],
        ];

        [contents addSection:[OWSTableSection sectionWithTitle:NSLocalizedString(@"GROUP_MANAGEMENT_SECTION",
                                                                   @"Conversation settings table section title")
                                                         items:groupItems]];
    }

    // Mute thread section.

    OWSTableSection *muteSection = [OWSTableSection new];
    [muteSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        OWSConversationSettingsViewController *strongSelf = weakSelf;
        OWSCAssert(strongSelf);
        cell.preservesSuperviewLayoutMargins = YES;
        cell.contentView.preservesSuperviewLayoutMargins = YES;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        UIImageView *iconView = [strongSelf viewForIconWithName:@"table_ic_mute_thread"];
        [cell.contentView addSubview:iconView];
        [iconView autoVCenterInSuperview];
        [iconView autoPinLeadingToSuperView];

        UILabel *rowLabel = [UILabel new];
        rowLabel.text = NSLocalizedString(
            @"CONVERSATION_SETTINGS_MUTE_LABEL", @"label for 'mute thread' cell in conversation settings");
        rowLabel.textColor = [UIColor blackColor];
        rowLabel.font = [UIFont ows_regularFontWithSize:17.f];
        rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell.contentView addSubview:rowLabel];
        [rowLabel autoVCenterInSuperview];
        [rowLabel autoPinLeadingToTrailingOfView:iconView margin:weakSelf.iconSpacing];

        NSString *muteStatus = NSLocalizedString(
            @"CONVERSATION_SETTINGS_MUTE_NOT_MUTED", @"Indicates that the current thread is not muted.");
        NSDate *mutedUntilDate = strongSelf.thread.mutedUntilDate;
        NSDate *now = [NSDate date];
        if (mutedUntilDate != nil && [mutedUntilDate timeIntervalSinceDate:now] > 0) {
            NSCalendar *calendar = [NSCalendar currentCalendar];
            NSCalendarUnit calendarUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
            NSDateComponents *muteUntilComponents = [calendar components:calendarUnits fromDate:mutedUntilDate];
            NSDateComponents *nowComponents = [calendar components:calendarUnits fromDate:now];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            if (nowComponents.year != muteUntilComponents.year || nowComponents.month != muteUntilComponents.month
                || nowComponents.day != muteUntilComponents.day) {

                [dateFormatter setDateStyle:NSDateFormatterShortStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            } else {
                [dateFormatter setDateStyle:NSDateFormatterNoStyle];
                [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            }

            muteStatus =
                [NSString stringWithFormat:NSLocalizedString(@"CONVERSATION_SETTINGS_MUTED_UNTIL_FORMAT",
                                               @"Indicates that this thread is muted until a given date or time. "
                                               @"Embeds {{The date or time which the thread is muted until}}."),
                          [dateFormatter stringFromDate:mutedUntilDate]];
        }

        cell.detailTextLabel.text = muteStatus;
        return cell;
    }
                             customRowHeight:45.f
                             actionBlock:^{
                                 [weakSelf showMuteUnmuteActionSheet];
                             }]];
    muteSection.footerTitle
        = NSLocalizedString(@"MUTE_BEHAVIOR_EXPLANATION", @"An explanation of the consequences of muting a thread.");
    [contents addSection:muteSection];

    // Block user section.

    if (!self.isGroupThread) {
        BOOL isBlocked = [[_blockingManager blockedPhoneNumbers] containsObject:self.thread.contactIdentifier];

        OWSTableSection *section = [OWSTableSection new];
        section.footerTitle = NSLocalizedString(
            @"BLOCK_BEHAVIOR_EXPLANATION", @"An explanation of the consequences of blocking another user.");
        [section addItem:[OWSTableItem itemWithCustomCellBlock:^{
            UITableViewCell *cell =
                [weakSelf disclosureCellWithName:NSLocalizedString(@"CONVERSATION_SETTINGS_BLOCK_THIS_USER",
                                                     @"table cell label in conversation settings")
                                        iconName:@"table_ic_block"];
            OWSConversationSettingsViewController *strongSelf = weakSelf;
            OWSCAssert(strongSelf);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UISwitch *blockUserSwitch = [UISwitch new];
            blockUserSwitch.on = isBlocked;
            [blockUserSwitch addTarget:strongSelf
                                action:@selector(blockUserSwitchDidChange:)
                      forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = blockUserSwitch;
            return cell;
        }
                                                   actionBlock:nil]];
        [contents addSection:section];
    }

    self.contents = contents;
}

- (CGFloat)iconSpacing
{
    return 12.f;
}

- (UITableViewCell *)cellWithName:(NSString *)name iconName:(NSString *)iconName
{
    OWSAssert(name.length > 0);
    OWSAssert(iconName.length > 0);

    UITableViewCell *cell = [UITableViewCell new];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;

    UIImageView *iconView = [self viewForIconWithName:iconName];
    [cell.contentView addSubview:iconView];
    [iconView autoVCenterInSuperview];
    [iconView autoPinLeadingToSuperView];

    UILabel *rowLabel = [UILabel new];
    rowLabel.text = name;
    rowLabel.textColor = [UIColor blackColor];
    rowLabel.font = [UIFont ows_regularFontWithSize:17.f];
    rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [cell.contentView addSubview:rowLabel];
    [rowLabel autoVCenterInSuperview];
    [rowLabel autoPinLeadingToTrailingOfView:iconView margin:self.iconSpacing];
    [rowLabel autoPinTrailingToSuperView];

    return cell;
}

- (UITableViewCell *)disclosureCellWithName:(NSString *)name iconName:(NSString *)iconName
{
    UITableViewCell *cell = [self cellWithName:name iconName:iconName];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (UITableViewCell *)labelCellWithName:(NSString *)name iconName:(NSString *)iconName
{
    UITableViewCell *cell = [self cellWithName:name iconName:iconName];
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

- (UIView *)mainSectionHeader
{
    UIView *mainSectionHeader = [UIView new];
    UIView *threadInfoView = [UIView containerView];
    [mainSectionHeader addSubview:threadInfoView];
    [threadInfoView autoPinWidthToSuperviewWithMargin:16.f];
    [threadInfoView autoPinHeightToSuperviewWithMargin:16.f];

    const NSUInteger kAvatarSize = 68;
    UIImage *avatarImage =
        [OWSAvatarBuilder buildImageForThread:self.thread diameter:kAvatarSize contactsManager:self.contactsManager];
    OWSAssert(avatarImage);

    AvatarImageView *avatarView = [[AvatarImageView alloc] initWithImage:avatarImage];
    _avatarView = avatarView;
    [threadInfoView addSubview:avatarView];
    [avatarView autoVCenterInSuperview];
    [avatarView autoPinLeadingToSuperView];
    [avatarView autoSetDimension:ALDimensionWidth toSize:kAvatarSize];
    [avatarView autoSetDimension:ALDimensionHeight toSize:kAvatarSize];

    UIView *threadNameView = [UIView containerView];
    [threadInfoView addSubview:threadNameView];
    [threadNameView autoVCenterInSuperview];
    [threadNameView autoPinTrailingToSuperView];
    [threadNameView autoPinLeadingToTrailingOfView:avatarView margin:16.f];

    UILabel *threadTitleLabel = [UILabel new];
    threadTitleLabel.text = self.threadName;
    threadTitleLabel.textColor = [UIColor blackColor];
    threadTitleLabel.font = [UIFont ows_dynamicTypeTitle2Font];
    threadTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [threadNameView addSubview:threadTitleLabel];
    [threadTitleLabel autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [threadTitleLabel autoPinWidthToSuperview];

    __block UIView *lastTitleView = threadTitleLabel;

    if (![self isGroupThread]) {
        const CGFloat kSubtitlePointSize = 12.f;
        void (^addSubtitle)(NSAttributedString *) = ^(NSAttributedString *subtitle) {
            UILabel *subtitleLabel = [UILabel new];
            subtitleLabel.textColor = [UIColor ows_darkGrayColor];
            subtitleLabel.font = [UIFont ows_regularFontWithSize:kSubtitlePointSize];
            subtitleLabel.attributedText = subtitle;
            subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            [threadNameView addSubview:subtitleLabel];
            [subtitleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastTitleView];
            [subtitleLabel autoPinLeadingToSuperView];
            lastTitleView = subtitleLabel;
        };

        NSString *recipientId = self.thread.contactIdentifier;

        BOOL hasName = ![self.thread.name isEqualToString:recipientId];
        if (hasName) {
            NSAttributedString *subtitle = [[NSAttributedString alloc]
                initWithString:[PhoneNumber
                                   bestEffortFormatPartialUserSpecifiedTextToLookLikeAPhoneNumber:recipientId]];
            addSubtitle(subtitle);
        }

        BOOL isVerified = [[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipientId]
            == OWSVerificationStateVerified;
        if (isVerified) {
            NSMutableAttributedString *subtitle = [NSMutableAttributedString new];
            // "checkmark"
            [subtitle appendAttributedString:[[NSAttributedString alloc]
                                                 initWithString:@"\uf00c "
                                                     attributes:@{
                                                         NSFontAttributeName :
                                                             [UIFont ows_fontAwesomeFont:kSubtitlePointSize],
                                                     }]];
            [subtitle appendAttributedString:[[NSAttributedString alloc]
                                                 initWithString:NSLocalizedString(@"PRIVACY_IDENTITY_IS_VERIFIED_BADGE",
                                                                    @"Badge indicating that the user is verified.")]];
            addSubtitle(subtitle);
        }
    }

    [lastTitleView autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    [mainSectionHeader
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(conversationNameTouched:)]];
    mainSectionHeader.userInteractionEnabled = YES;

    return mainSectionHeader;
}

- (void)conversationNameTouched:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if (self.isGroupThread) {
            CGPoint location = [sender locationInView:self.avatarView];
            if (CGRectContainsPoint(self.avatarView.bounds, location)) {
                [self showUpdateGroupView:UpdateGroupMode_EditGroupAvatar];
            } else {
                [self showUpdateGroupView:UpdateGroupMode_EditGroupName];
            }
        } else {
            if (self.contactsManager.supportsContactEditing) {
                [self presentContactViewController];
            }
        }
    }
}

- (UIImageView *)viewForIconWithName:(NSString *)iconName
{
    UIImage *icon = [UIImage imageNamed:iconName];
    OWSAssert(icon);
    UIImageView *iconView = [UIImageView new];
    iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    iconView.tintColor = [UIColor colorWithRGBHex:0x505050];
    iconView.contentMode = UIViewContentModeScaleToFill;
    [iconView autoSetDimension:ALDimensionWidth toSize:24.f];
    [iconView autoSetDimension:ALDimensionHeight toSize:24.f];
    return iconView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // In case we're dismissing a CNContactViewController which requires default system appearance
    [UIUtil applySignalAppearence];

    // HACK to unselect rows when swiping back
    // http://stackoverflow.com/questions/19379510/uitableviewcell-doesnt-get-deselected-when-swiping-back-quickly
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];

    [self updateTableContents];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (self.disappearingMessagesConfiguration.isNewRecord && !self.disappearingMessagesConfiguration.isEnabled) {
        // don't save defaults, else we'll unintentionally save the configuration and notify the contact.
        return;
    }

    if (self.disappearingMessagesConfiguration.dictionaryValueDidChange) {
        [self.disappearingMessagesConfiguration save];
        OWSDisappearingConfigurationUpdateInfoMessage *infoMessage =
            [[OWSDisappearingConfigurationUpdateInfoMessage alloc]
                initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                           thread:self.thread
                    configuration:self.disappearingMessagesConfiguration];
        [infoMessage save];

        [OWSNotifyRemoteOfUpdatedDisappearingConfigurationJob
            runWithConfiguration:self.disappearingMessagesConfiguration
                          thread:self.thread
                   messageSender:self.messageSender];
    }
}

#pragma mark - Actions

- (void)showShareProfileAlert
{
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    UIAlertAction *leaveAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_VIEW_SHARE_PROFILE",
                            @"Button to confirm that user wants to share their profile with a user or group.")
                  style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *_Nonnull action) {
                    [self shareProfile];
                }];
    [alertController addAction:leaveAction];

    UIAlertAction *cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", nil)
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *_Nonnull action) {
                    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                }];
    [alertController addAction:cancelAction];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)shareProfile
{
    [OWSProfileManager.sharedManager addThreadToProfileWhitelist:self.thread];

    [self updateTableContents];
}

- (void)showVerificationView
{
    NSString *recipientId = self.thread.contactIdentifier;
    OWSAssert(recipientId.length > 0);

    [FingerprintViewController presentFromViewController:self recipientId:recipientId];
}

- (void)showGroupMembersView
{
    ShowGroupMembersViewController *showGroupMembersViewController = [ShowGroupMembersViewController new];
    [showGroupMembersViewController configWithThread:(TSGroupThread *)self.thread];
    [self.navigationController pushViewController:showGroupMembersViewController animated:YES];
}

- (void)showUpdateGroupView:(UpdateGroupMode)mode
{
    OWSAssert(self.conversationSettingsViewDelegate);

    UpdateGroupViewController *updateGroupViewController = [UpdateGroupViewController new];
    updateGroupViewController.conversationSettingsViewDelegate = self.conversationSettingsViewDelegate;
    updateGroupViewController.thread = (TSGroupThread *)self.thread;
    updateGroupViewController.mode = mode;

    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:updateGroupViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)presentContactViewController
{
    if (!self.contactsManager.supportsContactEditing) {
        DDLogError(@"%@ Contact editing not supported", self.tag);
        OWSAssert(NO);
        return;
    }
    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        DDLogError(@"%@ unexpected thread: %@ in %s", self.tag, self.thread, __PRETTY_FUNCTION__);
        OWSAssert(NO);
        return;
    }

    TSContactThread *contactThread = (TSContactThread *)self.thread;
    [self.contactsViewHelper presentContactViewControllerForRecipientId:contactThread.contactIdentifier
                                                     fromViewController:self
                                                        editImmediately:YES];
}

- (void)presentAddToContactViewControllerWithRecipientId:(NSString *)recipientId
{
    if (!self.contactsManager.supportsContactEditing) {
        // Should not expose UI that lets the user get here.
        OWSFail(@"%@ Contact editing not supported.", self.tag);
        return;
    }

    if (!self.contactsManager.isSystemContactsAuthorized) {
        [self.contactsViewHelper presentMissingContactAccessAlertControllerFromViewController:self];
        return;
    }

    OWSAddToContactViewController *viewController = [OWSAddToContactViewController new];
    [viewController configureWithRecipientId:recipientId];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)didTapEditButton
{
    [self presentContactViewController];
}

- (void)didTapLeaveGroup
{
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:NSLocalizedString(@"CONFIRM_LEAVE_GROUP_TITLE", @"Alert title")
                                            message:NSLocalizedString(@"CONFIRM_LEAVE_GROUP_DESCRIPTION", @"Alert body")
                                     preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *leaveAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"LEAVE_BUTTON_TITLE", @"Confirmation button within contextual alert")
                  style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *_Nonnull action) {
                    [self leaveGroup];
                }];
    [alertController addAction:leaveAction];

    UIAlertAction *cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", nil)
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *_Nonnull action) {
                    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
                }];
    [alertController addAction:cancelAction];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)leaveGroup
{
    TSGroupThread *gThread = (TSGroupThread *)self.thread;
    TSOutgoingMessage *message = [[TSOutgoingMessage alloc] initWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                     inThread:gThread
                                                             groupMetaMessage:TSGroupMessageQuit];
    [self.messageSender sendMessage:message
        success:^{
            DDLogInfo(@"%@ Successfully left group.", self.tag);
        }
        failure:^(NSError *error) {
            DDLogWarn(@"%@ Failed to leave group with error: %@", self.tag, error);
        }];

    NSMutableArray *newGroupMemberIds = [NSMutableArray arrayWithArray:gThread.groupModel.groupMemberIds];
    [newGroupMemberIds removeObject:[self.storageManager localNumber]];
    gThread.groupModel.groupMemberIds = newGroupMemberIds;
    [gThread save];

    [self.navigationController popViewControllerAnimated:YES];
}

- (void)disappearingMessagesSwitchValueDidChange:(UISwitch *)sender
{
    UISwitch *disappearingMessagesSwitch = (UISwitch *)sender;

    [self toggleDisappearingMessages:disappearingMessagesSwitch.isOn];

    [self updateTableContents];
}

- (void)blockUserSwitchDidChange:(id)sender
{
    OWSAssert(!self.isGroupThread);

    if (![sender isKindOfClass:[UISwitch class]]) {
        DDLogError(@"%@ Unexpected sender for block user switch: %@", self.tag, sender);
        OWSAssert(0);
    }
    UISwitch *blockUserSwitch = (UISwitch *)sender;

    BOOL isCurrentlyBlocked = [[_blockingManager blockedPhoneNumbers] containsObject:self.thread.contactIdentifier];

    if (blockUserSwitch.isOn) {
        OWSAssert(!isCurrentlyBlocked);
        if (isCurrentlyBlocked) {
            return;
        }
        [BlockListUIUtils showBlockPhoneNumberActionSheet:self.thread.contactIdentifier
                                       fromViewController:self
                                          blockingManager:_blockingManager
                                          contactsManager:_contactsManager
                                          completionBlock:^(BOOL isBlocked) {
                                              // Update switch state if user cancels action.
                                              blockUserSwitch.on = isBlocked;
                                          }];
    } else {
        OWSAssert(isCurrentlyBlocked);
        if (!isCurrentlyBlocked) {
            return;
        }
        [BlockListUIUtils showUnblockPhoneNumberActionSheet:self.thread.contactIdentifier
                                         fromViewController:self
                                            blockingManager:_blockingManager
                                            contactsManager:_contactsManager
                                            completionBlock:^(BOOL isBlocked) {
                                                // Update switch state if user cancels action.
                                                blockUserSwitch.on = isBlocked;
                                            }];
    }
}

- (void)toggleDisappearingMessages:(BOOL)flag
{
    self.disappearingMessagesConfiguration.enabled = flag;

    [self updateTableContents];
}

- (void)durationSliderDidChange:(UISlider *)slider
{
    // snap the slider to a valid value
    NSUInteger index = (NSUInteger)(slider.value + 0.5);
    [slider setValue:index animated:YES];
    NSNumber *numberOfSeconds = self.disappearingMessagesDurations[index];
    self.disappearingMessagesConfiguration.durationSeconds = [numberOfSeconds unsignedIntValue];

    [self updateDisappearingMessagesDurationLabel];
}

- (void)updateDisappearingMessagesDurationLabel
{
    if (self.disappearingMessagesConfiguration.isEnabled) {
        NSString *keepForFormat = NSLocalizedString(@"KEEP_MESSAGES_DURATION",
            @"Slider label embeds {{TIME_AMOUNT}}, e.g. '2 hours'. See *_TIME_AMOUNT strings for examples.");
        self.disappearingMessagesDurationLabel.text =
            [NSString stringWithFormat:keepForFormat, self.disappearingMessagesConfiguration.durationString];
    } else {
        self.disappearingMessagesDurationLabel.text
            = NSLocalizedString(@"KEEP_MESSAGES_FOREVER", @"Slider label when disappearing messages is off");
    }

    [self.disappearingMessagesDurationLabel setNeedsLayout];
    [self.disappearingMessagesDurationLabel.superview setNeedsLayout];
}

- (void)showMuteUnmuteActionSheet
{
    // The "unmute" action sheet has no title or message; the
    // action label speaks for itself.
    NSString *title = nil;
    NSString *message = nil;
    if (!self.thread.isMuted) {
        title = NSLocalizedString(
            @"CONVERSATION_SETTINGS_MUTE_ACTION_SHEET_TITLE", @"Title of the 'mute this thread' action sheet.");
        message = NSLocalizedString(
            @"MUTE_BEHAVIOR_EXPLANATION", @"An explanation of the consequences of muting a thread.");
    }

    UIAlertController *actionSheetController =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    __weak OWSConversationSettingsViewController *weakSelf = self;
    if (self.thread.isMuted) {
        UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_UNMUTE_ACTION",
                                                                   @"Label for button to unmute a thread.")
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *_Nonnull ignore) {
                                                           [weakSelf setThreadMutedUntilDate:nil];
                                                       }];
        [actionSheetController addAction:action];
    } else {
#ifdef DEBUG
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_MUTE_ONE_MINUTE_ACTION",
                                                         @"Label for button to mute a thread for a minute.")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_Nonnull ignore) {
                                                 NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                                                 NSCalendar *calendar = [NSCalendar currentCalendar];
                                                 [calendar setTimeZone:timeZone];
                                                 NSDateComponents *dateComponents = [NSDateComponents new];
                                                 [dateComponents setMinute:1];
                                                 NSDate *mutedUntilDate =
                                                     [calendar dateByAddingComponents:dateComponents
                                                                               toDate:[NSDate date]
                                                                              options:0];
                                                 [weakSelf setThreadMutedUntilDate:mutedUntilDate];
                                             }]];
#endif
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_MUTE_ONE_HOUR_ACTION",
                                                         @"Label for button to mute a thread for a hour.")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_Nonnull ignore) {
                                                 NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                                                 NSCalendar *calendar = [NSCalendar currentCalendar];
                                                 [calendar setTimeZone:timeZone];
                                                 NSDateComponents *dateComponents = [NSDateComponents new];
                                                 [dateComponents setHour:1];
                                                 NSDate *mutedUntilDate =
                                                     [calendar dateByAddingComponents:dateComponents
                                                                               toDate:[NSDate date]
                                                                              options:0];
                                                 [weakSelf setThreadMutedUntilDate:mutedUntilDate];
                                             }]];
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_MUTE_ONE_DAY_ACTION",
                                                         @"Label for button to mute a thread for a day.")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_Nonnull ignore) {
                                                 NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                                                 NSCalendar *calendar = [NSCalendar currentCalendar];
                                                 [calendar setTimeZone:timeZone];
                                                 NSDateComponents *dateComponents = [NSDateComponents new];
                                                 [dateComponents setDay:1];
                                                 NSDate *mutedUntilDate =
                                                     [calendar dateByAddingComponents:dateComponents
                                                                               toDate:[NSDate date]
                                                                              options:0];
                                                 [weakSelf setThreadMutedUntilDate:mutedUntilDate];
                                             }]];
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_MUTE_ONE_WEEK_ACTION",
                                                         @"Label for button to mute a thread for a week.")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_Nonnull ignore) {
                                                 NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                                                 NSCalendar *calendar = [NSCalendar currentCalendar];
                                                 [calendar setTimeZone:timeZone];
                                                 NSDateComponents *dateComponents = [NSDateComponents new];
                                                 [dateComponents setDay:7];
                                                 NSDate *mutedUntilDate =
                                                     [calendar dateByAddingComponents:dateComponents
                                                                               toDate:[NSDate date]
                                                                              options:0];
                                                 [weakSelf setThreadMutedUntilDate:mutedUntilDate];
                                             }]];
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"CONVERSATION_SETTINGS_MUTE_ONE_YEAR_ACTION",
                                                         @"Label for button to mute a thread for a year.")
                                               style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *_Nonnull ignore) {
                                                 NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                                                 NSCalendar *calendar = [NSCalendar currentCalendar];
                                                 [calendar setTimeZone:timeZone];
                                                 NSDateComponents *dateComponents = [NSDateComponents new];
                                                 [dateComponents setYear:1];
                                                 NSDate *mutedUntilDate =
                                                     [calendar dateByAddingComponents:dateComponents
                                                                               toDate:[NSDate date]
                                                                              options:0];
                                                 [weakSelf setThreadMutedUntilDate:mutedUntilDate];
                                             }]];
    }

    UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", @"")
                                                            style:UIAlertActionStyleCancel
                                                          handler:nil];
    [actionSheetController addAction:dismissAction];

    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)setThreadMutedUntilDate:(nullable NSDate *)value
{
    [self.thread updateWithMutedUntilDate:value];
    [self updateTableContents];
}

#pragma mark - Notifications

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssert([NSThread isMainThread]);

    [self updateTableContents];
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end

NS_ASSUME_NONNULL_END
