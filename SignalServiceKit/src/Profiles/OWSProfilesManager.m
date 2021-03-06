//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "OWSProfilesManager.h"
#import "NSData+hexString.h"
#import "NSDate+OWS.h"
#import "OWSMessageSender.h"
#import "SecurityUtils.h"
#import "TSAccountManager.h"
#import "TSGroupThread.h"
#import "TSStorageManager.h"
#import "TSThread.h"
#import "TSYapDatabaseObject.h"
#import "TextSecureKitEnv.h"

NS_ASSUME_NONNULL_BEGIN

@interface UserProfile : TSYapDatabaseObject

@property (nonatomic, readonly) NSString *recipientId;
@property (nonatomic, nullable) NSString *profileName;
@property (nonatomic, nullable) NSString *avatarUrl;
@property (nonatomic, nullable) NSString *avatarDigest;

// This filename is relative to OWSProfilesManager.profileAvatarsDirPath.
@property (nonatomic, nullable) NSString *avatarFileName;

// This should reflect when either:
//
// * The last successful update was started.
// * The in-flight update was started.
@property (nonatomic, nullable) NSDate *lastUpdateDate;

- (instancetype)init NS_UNAVAILABLE;

@end

#pragma mark -

@implementation UserProfile

- (instancetype)initWithRecipientId:(NSString *)recipientId
                        profileName:(NSString *_Nullable)profileName
                          avatarUrl:(NSString *_Nullable)avatarUrl
                       avatarDigest:(NSString *_Nullable)avatarDigest
                     avatarFileName:(NSString *_Nullable)avatarFileName
{
    self = [super initWithUniqueId:recipientId];

    if (!self) {
        return self;
    }

    OWSAssert(recipientId.length > 0);
    _recipientId = recipientId;
    _profileName = profileName;
    _avatarUrl = avatarUrl;
    _avatarDigest = avatarDigest;
    _avatarFileName = avatarFileName;

    return self;
}

#pragma mark - NSObject

- (BOOL)isEqual:(UserProfile *)other
{
    return ([other isKindOfClass:[UserProfile class]] && [self.recipientId isEqualToString:other.recipientId] &&
        [self.profileName isEqualToString:other.profileName] && [self.avatarUrl isEqualToString:other.avatarUrl] &&
        [self.avatarDigest isEqualToString:other.avatarDigest] &&
        [self.avatarFileName isEqualToString:other.avatarFileName]);
}

- (NSUInteger)hash
{
    return self.recipientId.hash ^ self.profileName.hash ^ self.avatarUrl.hash ^ self.avatarDigest.hash
        ^ self.avatarFileName.hash;
}

@end

#pragma mark -

NSString *const kNSNotificationName_LocalProfileDidChange = @"kNSNotificationName_LocalProfileDidChange";
NSString *const kNSNotificationName_OtherUsersProfileDidChange = @"kNSNotificationName_OtherUsersProfileDidChange";

NSString *const kOWSProfilesManager_Collection = @"kOWSProfilesManager_Collection";
// This key is used to persist the local user's profile key.
NSString *const kOWSProfilesManager_LocalProfileSecretKey = @"kOWSProfilesManager_LocalProfileSecretKey";

NSString *const kOWSProfilesManager_UserWhitelistCollection = @"kOWSProfilesManager_UserWhitelistCollection";
NSString *const kOWSProfilesManager_GroupWhitelistCollection = @"kOWSProfilesManager_GroupWhitelistCollection";

NSString *const kOWSProfilesManager_OtherUsersProfileKeysCollection
    = @"kOWSProfilesManager_OtherUsersProfileKeysCollection";

// TODO:
static const NSInteger kProfileKeyLength = 16;

@interface OWSProfilesManager ()

@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) YapDatabaseConnection *dbConnection;

// This property should only be mutated on the main thread,
//
// NOTE: Do not access this property directly; use getOrCreateLocalUserProfile instead.
@property (nonatomic, nullable) UserProfile *localUserProfile;
// This property should only be mutated on the main thread,
@property (nonatomic, nullable) UIImage *localCachedAvatarImage;

// These caches are lazy-populated.  The single point of truth is the database.
//
// These three properties can be accessed on any thread.
@property (atomic, readonly) NSMutableDictionary<NSString *, NSNumber *> *userProfileWhitelistCache;
@property (atomic, readonly) NSMutableDictionary<NSString *, NSNumber *> *groupProfileWhitelistCache;
@property (atomic, readonly) NSMutableDictionary<NSString *, NSData *> *otherUsersProfileKeyCache;

// This property should only be mutated on the main thread,
@property (nonatomic, readonly) NSCache<NSString *, UIImage *> *otherUsersProfileAvatarImageCache;

@end

#pragma mark -

@implementation OWSProfilesManager

+ (instancetype)sharedManager
{
    static OWSProfilesManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}

- (instancetype)initDefault
{
    TSStorageManager *storageManager = [TSStorageManager sharedManager];
    OWSMessageSender *messageSender = [TextSecureKitEnv sharedEnv].messageSender;

    return [self initWithStorageManager:storageManager messageSender:messageSender];
}

- (instancetype)initWithStorageManager:(TSStorageManager *)storageManager
                         messageSender:(OWSMessageSender *)messageSender
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSAssert([NSThread isMainThread]);
    OWSAssert(storageManager);
    OWSAssert(messageSender);

    _messageSender = messageSender;
    _dbConnection = storageManager.newDatabaseConnection;
    _userProfileWhitelistCache = [NSMutableDictionary new];
    _groupProfileWhitelistCache = [NSMutableDictionary new];
    _otherUsersProfileKeyCache = [NSMutableDictionary new];
    _otherUsersProfileAvatarImageCache = [NSCache new];

    OWSSingletonAssert();

    // Register this manager with the message sender.
    // This is a circular dependency.
    [messageSender setProfilesManager:self];

    // Try to load.
    _localProfileKey = [self.dbConnection objectForKey:kOWSProfilesManager_LocalProfileSecretKey
                                            inCollection:kOWSProfilesManager_Collection];
    if (!_localProfileKey) {
        // Generate
        _localProfileKey = [OWSProfilesManager generateLocalProfileKey];
        // Persist
        [self.dbConnection setObject:_localProfileKey
                                forKey:kOWSProfilesManager_LocalProfileSecretKey
                          inCollection:kOWSProfilesManager_Collection];
    }
    OWSAssert(_localProfileKey.length == kProfileKeyLength);

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)appLaunchDidBegin
{
    // Do nothing; we only want to make sure this singleton is created on startup.
}

#pragma mark - User Profile Accessor

- (UserProfile *)getOrCreateUserProfileForRecipientId:(NSString *)recipientId
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(recipientId.length > 0);

    __block UserProfile *instance;
    // Make sure to read on the local db connection for consistency.
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        instance = [UserProfile fetchObjectWithUniqueID:recipientId transaction:transaction];

        if (!instance) {
            instance = [[UserProfile alloc] initWithRecipientId:recipientId
                                                    profileName:nil
                                                      avatarUrl:nil
                                                   avatarDigest:nil
                                                 avatarFileName:nil];
            [instance saveWithTransaction:transaction];
        }
    }];

    OWSAssert(instance);

    return instance;
}

- (nullable UserProfile *)getOrCreateLocalUserProfile
{
    OWSAssert([NSThread isMainThread]);

    if (!self.localUserProfile) {
        NSString *_Nullable recipientId = [TSAccountManager localNumber];
        if (!recipientId) {
            OWSFail(@"Missing local number.");
            return nil;
        }
        self.localUserProfile = [self getOrCreateUserProfileForRecipientId:recipientId];
    }
    return self.localUserProfile;
}

#pragma mark - Local Profile Key

+ (NSData *)generateLocalProfileKey
{
    // TODO:
    DDLogVerbose(@"%@ Profile key generation is not yet implemented.", self.tag);
    return [SecurityUtils generateRandomBytes:kProfileKeyLength];
}

#pragma mark - Local Profile

- (NSString *)localProfileName
{
    OWSAssert([NSThread isMainThread]);

    return [self getOrCreateLocalUserProfile].profileName;
}

- (UIImage *)localProfileAvatarImage
{
    OWSAssert([NSThread isMainThread]);

    return self.localCachedAvatarImage;
}

- (void)updateLocalProfileName:(nullable NSString *)profileName
                   avatarImage:(nullable UIImage *)avatarImage
                       success:(void (^)())successBlock
                       failure:(void (^)())failureBlockParameter
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(successBlock);
    OWSAssert(failureBlockParameter);

    // Ensure that the failure block is called on the main thread.
    void (^failureBlock)() = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlockParameter();
        });
    };

    // The final steps are to:
    //
    // * Try to update the service.
    // * Update client state on success.
    void (^tryToUpdateService)(NSString *_Nullable, NSString *_Nullable, NSString *_Nullable) = ^(
        NSString *_Nullable avatarUrl, NSString *_Nullable avatarDigest, NSString *_Nullable avatarFileName) {
        [self updateProfileOnService:profileName
            avatarUrl:avatarUrl
            avatarDigest:avatarDigest
            success:^{
                // All reads and writes to user profiles should happen on the main thread.
                dispatch_async(dispatch_get_main_queue(), ^{
                    UserProfile *userProfile = [self getOrCreateLocalUserProfile];
                    OWSAssert(userProfile);
                    userProfile.profileName = profileName;
                    userProfile.avatarUrl = avatarUrl;
                    userProfile.avatarDigest = avatarDigest;
                    userProfile.avatarFileName = avatarFileName;
                    // Make sure to save on the local db connection for consistency.
                    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                        [userProfile saveWithTransaction:transaction];
                    }];
                    self.localCachedAvatarImage = avatarImage;

                    successBlock();

                    [[NSNotificationCenter defaultCenter] postNotificationName:kNSNotificationName_LocalProfileDidChange
                                                                        object:nil
                                                                      userInfo:nil];
                });
            }
            failure:^{
                failureBlock();
            }];
    };

    UserProfile *userProfile = [self getOrCreateLocalUserProfile];
    OWSAssert(userProfile);

    // If we have a new avatar image, we must first:
    //
    // * Encode it to JPEG.
    // * Write it to disk.
    // * Upload it to service.
    if (avatarImage) {
        if (self.localCachedAvatarImage == avatarImage) {
            OWSAssert(userProfile.avatarUrl.length > 0);
            OWSAssert(userProfile.avatarDigest.length > 0);
            OWSAssert(userProfile.avatarFileName.length > 0);

            DDLogVerbose(@"%@ Updating local profile on service with unchanged avatar.", self.tag);
            // If the avatar hasn't changed, reuse the existing metadata.
            tryToUpdateService(userProfile.avatarUrl, userProfile.avatarDigest, userProfile.avatarFileName);
        } else {
            DDLogVerbose(@"%@ Updating local profile on service with new avatar.", self.tag);
            [self writeAvatarToDisk:avatarImage
                success:^(NSData *data, NSString *fileName) {
                    [self uploadAvatarToService:data
                        fileName:fileName
                        success:^(NSString *avatarUrl, NSString *avatarDigest) {
                            tryToUpdateService(avatarUrl, avatarDigest, fileName);
                        }
                        failure:^{
                            failureBlock();
                        }];
                }
                failure:^{
                    failureBlock();
                }];
        }
    } else {
        DDLogVerbose(@"%@ Updating local profile on service with no avatar.", self.tag);
        tryToUpdateService(nil, nil, nil);
    }
}

- (void)writeAvatarToDisk:(UIImage *)avatar
                  success:(void (^)(NSData *data, NSString *fileName))successBlock
                  failure:(void (^)())failureBlock
{
    OWSAssert(avatar);
    OWSAssert(successBlock);
    OWSAssert(failureBlock);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (avatar) {
            NSData *_Nullable data = UIImageJPEGRepresentation(avatar, 1.f);
            OWSAssert(data);
            if (data) {
                NSString *fileName = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"jpg"];
                NSString *filePath = [self.profileAvatarsDirPath stringByAppendingPathComponent:fileName];
                BOOL success = [data writeToFile:filePath atomically:YES];
                OWSAssert(success);
                if (success) {
                    successBlock(data, fileName);
                    return;
                }
            }
        }
        failureBlock();
    });
}

// TODO: The exact API & encryption scheme for avatars is not yet settled.
- (void)uploadAvatarToService:(NSData *)data
                     fileName:(NSString *)fileName
                      success:(void (^)(NSString *avatarUrl, NSString *avatarDigest))successBlock
                      failure:(void (^)())failureBlock
{
    OWSAssert(data.length > 0);
    OWSAssert(fileName.length > 0);
    OWSAssert(successBlock);
    OWSAssert(failureBlock);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // TODO:
        NSString *avatarUrl = @"avatarUrl";
        NSString *avatarDigest = @"avatarDigest";
        if (YES) {
            successBlock(avatarUrl, avatarDigest);
            return;
        }
        failureBlock();
    });
}

// TODO: The exact API & encryption scheme for profiles is not yet settled.
- (void)updateProfileOnService:(nullable NSString *)localProfileName
                     avatarUrl:(nullable NSString *)avatarUrl
                  avatarDigest:(nullable NSString *)avatarDigest
                       success:(void (^)())successBlock
                       failure:(void (^)())failureBlock
{
    OWSAssert(successBlock);
    OWSAssert(failureBlock);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // TODO:
        if (YES) {
            successBlock();
            return;
        }
        failureBlock();
    });
}

#pragma mark - Profile Whitelist

- (void)addUserToProfileWhitelist:(NSString *)recipientId
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(recipientId.length > 0);

    [self.dbConnection setBool:YES forKey:recipientId inCollection:kOWSProfilesManager_UserWhitelistCollection];
    self.userProfileWhitelistCache[recipientId] = @(YES);
}

- (void)addUsersToProfileWhitelist:(NSArray<NSString *> *)recipientIds
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(recipientIds);

    NSMutableArray<NSString *> *newRecipientIds = [NSMutableArray new];
    for (NSString *recipientId in recipientIds) {
        if (!self.userProfileWhitelistCache[recipientId]) {
            [newRecipientIds addObject:recipientId];
        }
    }

    if (newRecipientIds.count < 1) {
        return;
    }

    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        for (NSString *recipientId in recipientIds) {
            [transaction setObject:@(YES) forKey:recipientId inCollection:kOWSProfilesManager_UserWhitelistCollection];
            self.userProfileWhitelistCache[recipientId] = @(YES);
        }
    }];
}

- (BOOL)isUserInProfileWhitelist:(NSString *)recipientId
{
    OWSAssert(recipientId.length > 0);

    NSNumber *_Nullable value = self.userProfileWhitelistCache[recipientId];
    if (value) {
        return [value boolValue];
    }

    value = @([self.dbConnection hasObjectForKey:recipientId inCollection:kOWSProfilesManager_UserWhitelistCollection]);
    self.userProfileWhitelistCache[recipientId] = value;
    return [value boolValue];
}

- (void)addGroupIdToProfileWhitelist:(NSData *)groupId
{
    OWSAssert(groupId.length > 0);

    NSString *groupIdKey = [groupId hexadecimalString];
    [self.dbConnection setObject:@(1) forKey:groupIdKey inCollection:kOWSProfilesManager_GroupWhitelistCollection];
    self.groupProfileWhitelistCache[groupIdKey] = @(YES);
}

- (BOOL)isGroupIdInProfileWhitelist:(NSData *)groupId
{
    OWSAssert(groupId.length > 0);

    NSString *groupIdKey = [groupId hexadecimalString];
    NSNumber *_Nullable value = self.groupProfileWhitelistCache[groupIdKey];
    if (value) {
        return [value boolValue];
    }

    value =
        @(nil != [self.dbConnection objectForKey:groupIdKey inCollection:kOWSProfilesManager_GroupWhitelistCollection]);
    self.groupProfileWhitelistCache[groupIdKey] = value;
    return [value boolValue];
}

- (BOOL)isThreadInProfileWhitelist:(TSThread *)thread
{
    OWSAssert(thread);

    if (thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        NSData *groupId = groupThread.groupModel.groupId;
        return [OWSProfilesManager.sharedManager isGroupIdInProfileWhitelist:groupId];
    } else {
        NSString *recipientId = thread.contactIdentifier;
        return [OWSProfilesManager.sharedManager isUserInProfileWhitelist:recipientId];
    }
}

- (void)setContactRecipientIds:(NSArray<NSString *> *)contactRecipientIds
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(contactRecipientIds);
    
    // TODO: The persisted whitelist could either be:
    //
    // * Just users manually added to the whitelist.
    // * Also include users auto-added by, for example, being in the user's
    //   contacts or when the user initiates a 1:1 conversation with them, etc.
    [self addUsersToProfileWhitelist:contactRecipientIds];
}

#pragma mark - Other User's Profiles

- (void)setProfileKey:(NSData *)profileKey forRecipientId:(NSString *)recipientId
{
    OWSAssert(profileKey.length == kProfileKeyLength);
    OWSAssert(recipientId.length > 0);
    if (profileKey.length != kProfileKeyLength) {
        return;
    }

    NSData *_Nullable existingProfileKey = [self profileKeyForRecipientId:recipientId];
    if (existingProfileKey &&
        [existingProfileKey isEqual:profileKey]) {
        // Ignore redundant update.
        return;
    }

    [self.dbConnection setObject:profileKey
                          forKey:recipientId
                    inCollection:kOWSProfilesManager_OtherUsersProfileKeysCollection];
    self.otherUsersProfileKeyCache[recipientId] = profileKey;
}

- (nullable NSData *)profileKeyForRecipientId:(NSString *)recipientId
{
    OWSAssert(recipientId.length > 0);

    NSData *_Nullable profileKey = self.otherUsersProfileKeyCache[recipientId];
    if (profileKey.length > 0) {
        return profileKey;
    }

    profileKey =
        [self.dbConnection dataForKey:recipientId inCollection:kOWSProfilesManager_OtherUsersProfileKeysCollection];
    if (profileKey) {
        OWSAssert(profileKey.length == kProfileKeyLength);
        self.otherUsersProfileKeyCache[recipientId] = profileKey;
    }
    return profileKey;
}

- (nullable NSString *)profileNameForRecipientId:(NSString *)recipientId
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(recipientId.length > 0);

    [self fetchProfileForRecipientId:recipientId];

    UserProfile *userProfile = [self getOrCreateUserProfileForRecipientId:recipientId];
    return userProfile.profileName;
}

- (nullable UIImage *)profileAvatarForRecipientId:(NSString *)recipientId
{
    OWSAssert([NSThread isMainThread]);
    OWSAssert(recipientId.length > 0);

    [self fetchProfileForRecipientId:recipientId];

    UIImage *_Nullable image = [self.otherUsersProfileAvatarImageCache objectForKey:recipientId];
    if (image) {
        return image;
    }

    UserProfile *userProfile = [self getOrCreateUserProfileForRecipientId:recipientId];
    if (userProfile.avatarFileName) {
        image = [self loadProfileAvatarWithFilename:userProfile.avatarFileName];
        if (image) {
            [self.otherUsersProfileAvatarImageCache setObject:image forKey:recipientId];
        }
    }

    return image;
}

- (void)fetchProfileForRecipientId:(NSString *)recipientId
{
    OWSAssert(recipientId.length > 0);

    UserProfile *userProfile = [self getOrCreateUserProfileForRecipientId:recipientId];

    // Throttle and debounce the updates.
    const NSTimeInterval kMaxRefreshFrequency = 5 * kMinuteInterval;
    if (userProfile.lastUpdateDate && fabs([userProfile.lastUpdateDate timeIntervalSinceNow]) < kMaxRefreshFrequency) {
        // This profile was updated recently or already has an update in flight.
        return;
    }

    userProfile.lastUpdateDate = [NSDate new];
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [userProfile saveWithTransaction:transaction];
    }];

    // TODO: Actually update the profile.
}

#pragma mark - Avatar Disk Cache

- (nullable UIImage *)loadProfileAvatarWithFilename:(NSString *)fileName
{
    OWSAssert(fileName.length > 0);

    NSString *filePath = [self.profileAvatarsDirPath stringByAppendingPathComponent:fileName];
    UIImage *_Nullable image = [UIImage imageWithContentsOfFile:filePath];
    return image;
}

- (NSString *)profileAvatarsDirPath
{
    static NSString *profileAvatarsDirPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *documentsPath =
            [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        profileAvatarsDirPath = [documentsPath stringByAppendingPathComponent:@"ProfileAvatars"];

        BOOL isDirectory;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:profileAvatarsDirPath isDirectory:&isDirectory];
        if (exists) {
            OWSAssert(isDirectory);

            DDLogInfo(@"Profile avatars directory already exists");
        } else {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:profileAvatarsDirPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];
            if (error) {
                DDLogError(@"Failed to create profile avatars directory: %@", error);
            }
        }
    });
    return profileAvatarsDirPath;
}

// TODO: We may want to clean up this directory in the "orphan cleanup" logic.

#pragma mark - Notifications

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    OWSAssert([NSThread isMainThread]);

    @synchronized(self)
    {
        // TODO: Sync if necessary.
    }
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
