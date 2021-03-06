// Generated by the protocol buffer compiler.  DO NOT EDIT!

#import "OWSFingerprintProtos.pb.h"
// @@protoc_insertion_point(imports)

@implementation OWSFingerprintProtosOwsfingerprintProtosRoot
static PBExtensionRegistry* extensionRegistry = nil;
+ (PBExtensionRegistry*) extensionRegistry {
  return extensionRegistry;
}

+ (void) initialize {
  if (self == [OWSFingerprintProtosOwsfingerprintProtosRoot class]) {
    PBMutableExtensionRegistry* registry = [PBMutableExtensionRegistry registry];
    [self registerAllExtensions:registry];
    [ObjectivecDescriptorRoot registerAllExtensions:registry];
    extensionRegistry = registry;
  }
}
+ (void) registerAllExtensions:(PBMutableExtensionRegistry*) registry {
}
@end

@interface OWSFingerprintProtosLogicalFingerprint ()
@property (strong) NSData* identityData;
@end

@implementation OWSFingerprintProtosLogicalFingerprint

- (BOOL) hasIdentityData {
  return !!hasIdentityData_;
}
- (void) setHasIdentityData:(BOOL) _value_ {
  hasIdentityData_ = !!_value_;
}
@synthesize identityData;
- (instancetype) init {
  if ((self = [super init])) {
    self.identityData = [NSData data];
  }
  return self;
}
static OWSFingerprintProtosLogicalFingerprint* defaultOWSFingerprintProtosLogicalFingerprintInstance = nil;
+ (void) initialize {
  if (self == [OWSFingerprintProtosLogicalFingerprint class]) {
    defaultOWSFingerprintProtosLogicalFingerprintInstance = [[OWSFingerprintProtosLogicalFingerprint alloc] init];
  }
}
+ (instancetype) defaultInstance {
  return defaultOWSFingerprintProtosLogicalFingerprintInstance;
}
- (instancetype) defaultInstance {
  return defaultOWSFingerprintProtosLogicalFingerprintInstance;
}
- (BOOL) isInitialized {
  return YES;
}
- (void) writeToCodedOutputStream:(PBCodedOutputStream*) output {
  if (self.hasIdentityData) {
    [output writeData:1 value:self.identityData];
  }
  [self.unknownFields writeToCodedOutputStream:output];
}
- (SInt32) serializedSize {
  __block SInt32 size_ = memoizedSerializedSize;
  if (size_ != -1) {
    return size_;
  }

  size_ = 0;
  if (self.hasIdentityData) {
    size_ += computeDataSize(1, self.identityData);
  }
  size_ += self.unknownFields.serializedSize;
  memoizedSerializedSize = size_;
  return size_;
}
+ (OWSFingerprintProtosLogicalFingerprint*) parseFromData:(NSData*) data {
  return (OWSFingerprintProtosLogicalFingerprint*)[[[OWSFingerprintProtosLogicalFingerprint builder] mergeFromData:data] build];
}
+ (OWSFingerprintProtosLogicalFingerprint*) parseFromData:(NSData*) data extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  return (OWSFingerprintProtosLogicalFingerprint*)[[[OWSFingerprintProtosLogicalFingerprint builder] mergeFromData:data extensionRegistry:extensionRegistry] build];
}
+ (OWSFingerprintProtosLogicalFingerprint*) parseFromInputStream:(NSInputStream*) input {
  return (OWSFingerprintProtosLogicalFingerprint*)[[[OWSFingerprintProtosLogicalFingerprint builder] mergeFromInputStream:input] build];
}
+ (OWSFingerprintProtosLogicalFingerprint*) parseFromInputStream:(NSInputStream*) input extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  return (OWSFingerprintProtosLogicalFingerprint*)[[[OWSFingerprintProtosLogicalFingerprint builder] mergeFromInputStream:input extensionRegistry:extensionRegistry] build];
}
+ (OWSFingerprintProtosLogicalFingerprint*) parseFromCodedInputStream:(PBCodedInputStream*) input {
  return (OWSFingerprintProtosLogicalFingerprint*)[[[OWSFingerprintProtosLogicalFingerprint builder] mergeFromCodedInputStream:input] build];
}
+ (OWSFingerprintProtosLogicalFingerprint*) parseFromCodedInputStream:(PBCodedInputStream*) input extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  return (OWSFingerprintProtosLogicalFingerprint*)[[[OWSFingerprintProtosLogicalFingerprint builder] mergeFromCodedInputStream:input extensionRegistry:extensionRegistry] build];
}
+ (OWSFingerprintProtosLogicalFingerprintBuilder*) builder {
  return [[OWSFingerprintProtosLogicalFingerprintBuilder alloc] init];
}
+ (OWSFingerprintProtosLogicalFingerprintBuilder*) builderWithPrototype:(OWSFingerprintProtosLogicalFingerprint*) prototype {
  return [[OWSFingerprintProtosLogicalFingerprint builder] mergeFrom:prototype];
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) builder {
  return [OWSFingerprintProtosLogicalFingerprint builder];
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) toBuilder {
  return [OWSFingerprintProtosLogicalFingerprint builderWithPrototype:self];
}
- (void) writeDescriptionTo:(NSMutableString*) output withIndent:(NSString*) indent {
  if (self.hasIdentityData) {
    [output appendFormat:@"%@%@: %@\n", indent, @"identityData", self.identityData];
  }
  [self.unknownFields writeDescriptionTo:output withIndent:indent];
}
- (void) storeInDictionary:(NSMutableDictionary *)dictionary {
  if (self.hasIdentityData) {
    [dictionary setObject: self.identityData forKey: @"identityData"];
  }
  [self.unknownFields storeInDictionary:dictionary];
}
- (BOOL) isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[OWSFingerprintProtosLogicalFingerprint class]]) {
    return NO;
  }
  OWSFingerprintProtosLogicalFingerprint *otherMessage = other;
  return
      self.hasIdentityData == otherMessage.hasIdentityData &&
      (!self.hasIdentityData || [self.identityData isEqual:otherMessage.identityData]) &&
      (self.unknownFields == otherMessage.unknownFields || (self.unknownFields != nil && [self.unknownFields isEqual:otherMessage.unknownFields]));
}
- (NSUInteger) hash {
  __block NSUInteger hashCode = 7;
  if (self.hasIdentityData) {
    hashCode = hashCode * 31 + [self.identityData hash];
  }
  hashCode = hashCode * 31 + [self.unknownFields hash];
  return hashCode;
}
@end

@interface OWSFingerprintProtosLogicalFingerprintBuilder()
@property (strong) OWSFingerprintProtosLogicalFingerprint* resultLogicalFingerprint;
@end

@implementation OWSFingerprintProtosLogicalFingerprintBuilder
@synthesize resultLogicalFingerprint;
- (instancetype) init {
  if ((self = [super init])) {
    self.resultLogicalFingerprint = [[OWSFingerprintProtosLogicalFingerprint alloc] init];
  }
  return self;
}
- (PBGeneratedMessage*) internalGetResult {
  return resultLogicalFingerprint;
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) clear {
  self.resultLogicalFingerprint = [[OWSFingerprintProtosLogicalFingerprint alloc] init];
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) clone {
  return [OWSFingerprintProtosLogicalFingerprint builderWithPrototype:resultLogicalFingerprint];
}
- (OWSFingerprintProtosLogicalFingerprint*) defaultInstance {
  return [OWSFingerprintProtosLogicalFingerprint defaultInstance];
}
- (OWSFingerprintProtosLogicalFingerprint*) build {
  [self checkInitialized];
  return [self buildPartial];
}
- (OWSFingerprintProtosLogicalFingerprint*) buildPartial {
  OWSFingerprintProtosLogicalFingerprint* returnMe = resultLogicalFingerprint;
  self.resultLogicalFingerprint = nil;
  return returnMe;
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) mergeFrom:(OWSFingerprintProtosLogicalFingerprint*) other {
  if (other == [OWSFingerprintProtosLogicalFingerprint defaultInstance]) {
    return self;
  }
  if (other.hasIdentityData) {
    [self setIdentityData:other.identityData];
  }
  [self mergeUnknownFields:other.unknownFields];
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) mergeFromCodedInputStream:(PBCodedInputStream*) input {
  return [self mergeFromCodedInputStream:input extensionRegistry:[PBExtensionRegistry emptyRegistry]];
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) mergeFromCodedInputStream:(PBCodedInputStream*) input extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  PBUnknownFieldSetBuilder* unknownFields = [PBUnknownFieldSet builderWithUnknownFields:self.unknownFields];
  while (YES) {
    SInt32 tag = [input readTag];
    switch (tag) {
      case 0:
        [self setUnknownFields:[unknownFields build]];
        return self;
      default: {
        if (![self parseUnknownField:input unknownFields:unknownFields extensionRegistry:extensionRegistry tag:tag]) {
          [self setUnknownFields:[unknownFields build]];
          return self;
        }
        break;
      }
      case 10: {
        [self setIdentityData:[input readData]];
        break;
      }
    }
  }
}
- (BOOL) hasIdentityData {
  return resultLogicalFingerprint.hasIdentityData;
}
- (NSData*) identityData {
  return resultLogicalFingerprint.identityData;
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) setIdentityData:(NSData*) value {
  resultLogicalFingerprint.hasIdentityData = YES;
  resultLogicalFingerprint.identityData = value;
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintBuilder*) clearIdentityData {
  resultLogicalFingerprint.hasIdentityData = NO;
  resultLogicalFingerprint.identityData = [NSData data];
  return self;
}
@end

@interface OWSFingerprintProtosLogicalFingerprints ()
@property UInt32 version;
@property (strong) OWSFingerprintProtosLogicalFingerprint* localFingerprint;
@property (strong) OWSFingerprintProtosLogicalFingerprint* remoteFingerprint;
@end

@implementation OWSFingerprintProtosLogicalFingerprints

- (BOOL) hasVersion {
  return !!hasVersion_;
}
- (void) setHasVersion:(BOOL) _value_ {
  hasVersion_ = !!_value_;
}
@synthesize version;
- (BOOL) hasLocalFingerprint {
  return !!hasLocalFingerprint_;
}
- (void) setHasLocalFingerprint:(BOOL) _value_ {
  hasLocalFingerprint_ = !!_value_;
}
@synthesize localFingerprint;
- (BOOL) hasRemoteFingerprint {
  return !!hasRemoteFingerprint_;
}
- (void) setHasRemoteFingerprint:(BOOL) _value_ {
  hasRemoteFingerprint_ = !!_value_;
}
@synthesize remoteFingerprint;
- (instancetype) init {
  if ((self = [super init])) {
    self.version = 0;
    self.localFingerprint = [OWSFingerprintProtosLogicalFingerprint defaultInstance];
    self.remoteFingerprint = [OWSFingerprintProtosLogicalFingerprint defaultInstance];
  }
  return self;
}
static OWSFingerprintProtosLogicalFingerprints* defaultOWSFingerprintProtosLogicalFingerprintsInstance = nil;
+ (void) initialize {
  if (self == [OWSFingerprintProtosLogicalFingerprints class]) {
    defaultOWSFingerprintProtosLogicalFingerprintsInstance = [[OWSFingerprintProtosLogicalFingerprints alloc] init];
  }
}
+ (instancetype) defaultInstance {
  return defaultOWSFingerprintProtosLogicalFingerprintsInstance;
}
- (instancetype) defaultInstance {
  return defaultOWSFingerprintProtosLogicalFingerprintsInstance;
}
- (BOOL) isInitialized {
  return YES;
}
- (void) writeToCodedOutputStream:(PBCodedOutputStream*) output {
  if (self.hasVersion) {
    [output writeUInt32:1 value:self.version];
  }
  if (self.hasLocalFingerprint) {
    [output writeMessage:2 value:self.localFingerprint];
  }
  if (self.hasRemoteFingerprint) {
    [output writeMessage:3 value:self.remoteFingerprint];
  }
  [self.unknownFields writeToCodedOutputStream:output];
}
- (SInt32) serializedSize {
  __block SInt32 size_ = memoizedSerializedSize;
  if (size_ != -1) {
    return size_;
  }

  size_ = 0;
  if (self.hasVersion) {
    size_ += computeUInt32Size(1, self.version);
  }
  if (self.hasLocalFingerprint) {
    size_ += computeMessageSize(2, self.localFingerprint);
  }
  if (self.hasRemoteFingerprint) {
    size_ += computeMessageSize(3, self.remoteFingerprint);
  }
  size_ += self.unknownFields.serializedSize;
  memoizedSerializedSize = size_;
  return size_;
}
+ (OWSFingerprintProtosLogicalFingerprints*) parseFromData:(NSData*) data {
  return (OWSFingerprintProtosLogicalFingerprints*)[[[OWSFingerprintProtosLogicalFingerprints builder] mergeFromData:data] build];
}
+ (OWSFingerprintProtosLogicalFingerprints*) parseFromData:(NSData*) data extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  return (OWSFingerprintProtosLogicalFingerprints*)[[[OWSFingerprintProtosLogicalFingerprints builder] mergeFromData:data extensionRegistry:extensionRegistry] build];
}
+ (OWSFingerprintProtosLogicalFingerprints*) parseFromInputStream:(NSInputStream*) input {
  return (OWSFingerprintProtosLogicalFingerprints*)[[[OWSFingerprintProtosLogicalFingerprints builder] mergeFromInputStream:input] build];
}
+ (OWSFingerprintProtosLogicalFingerprints*) parseFromInputStream:(NSInputStream*) input extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  return (OWSFingerprintProtosLogicalFingerprints*)[[[OWSFingerprintProtosLogicalFingerprints builder] mergeFromInputStream:input extensionRegistry:extensionRegistry] build];
}
+ (OWSFingerprintProtosLogicalFingerprints*) parseFromCodedInputStream:(PBCodedInputStream*) input {
  return (OWSFingerprintProtosLogicalFingerprints*)[[[OWSFingerprintProtosLogicalFingerprints builder] mergeFromCodedInputStream:input] build];
}
+ (OWSFingerprintProtosLogicalFingerprints*) parseFromCodedInputStream:(PBCodedInputStream*) input extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  return (OWSFingerprintProtosLogicalFingerprints*)[[[OWSFingerprintProtosLogicalFingerprints builder] mergeFromCodedInputStream:input extensionRegistry:extensionRegistry] build];
}
+ (OWSFingerprintProtosLogicalFingerprintsBuilder*) builder {
  return [[OWSFingerprintProtosLogicalFingerprintsBuilder alloc] init];
}
+ (OWSFingerprintProtosLogicalFingerprintsBuilder*) builderWithPrototype:(OWSFingerprintProtosLogicalFingerprints*) prototype {
  return [[OWSFingerprintProtosLogicalFingerprints builder] mergeFrom:prototype];
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) builder {
  return [OWSFingerprintProtosLogicalFingerprints builder];
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) toBuilder {
  return [OWSFingerprintProtosLogicalFingerprints builderWithPrototype:self];
}
- (void) writeDescriptionTo:(NSMutableString*) output withIndent:(NSString*) indent {
  if (self.hasVersion) {
    [output appendFormat:@"%@%@: %@\n", indent, @"version", [NSNumber numberWithInteger:self.version]];
  }
  if (self.hasLocalFingerprint) {
    [output appendFormat:@"%@%@ {\n", indent, @"localFingerprint"];
    [self.localFingerprint writeDescriptionTo:output
                         withIndent:[NSString stringWithFormat:@"%@  ", indent]];
    [output appendFormat:@"%@}\n", indent];
  }
  if (self.hasRemoteFingerprint) {
    [output appendFormat:@"%@%@ {\n", indent, @"remoteFingerprint"];
    [self.remoteFingerprint writeDescriptionTo:output
                         withIndent:[NSString stringWithFormat:@"%@  ", indent]];
    [output appendFormat:@"%@}\n", indent];
  }
  [self.unknownFields writeDescriptionTo:output withIndent:indent];
}
- (void) storeInDictionary:(NSMutableDictionary *)dictionary {
  if (self.hasVersion) {
    [dictionary setObject: [NSNumber numberWithInteger:self.version] forKey: @"version"];
  }
  if (self.hasLocalFingerprint) {
   NSMutableDictionary *messageDictionary = [NSMutableDictionary dictionary]; 
   [self.localFingerprint storeInDictionary:messageDictionary];
   [dictionary setObject:[NSDictionary dictionaryWithDictionary:messageDictionary] forKey:@"localFingerprint"];
  }
  if (self.hasRemoteFingerprint) {
   NSMutableDictionary *messageDictionary = [NSMutableDictionary dictionary]; 
   [self.remoteFingerprint storeInDictionary:messageDictionary];
   [dictionary setObject:[NSDictionary dictionaryWithDictionary:messageDictionary] forKey:@"remoteFingerprint"];
  }
  [self.unknownFields storeInDictionary:dictionary];
}
- (BOOL) isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isKindOfClass:[OWSFingerprintProtosLogicalFingerprints class]]) {
    return NO;
  }
  OWSFingerprintProtosLogicalFingerprints *otherMessage = other;
  return
      self.hasVersion == otherMessage.hasVersion &&
      (!self.hasVersion || self.version == otherMessage.version) &&
      self.hasLocalFingerprint == otherMessage.hasLocalFingerprint &&
      (!self.hasLocalFingerprint || [self.localFingerprint isEqual:otherMessage.localFingerprint]) &&
      self.hasRemoteFingerprint == otherMessage.hasRemoteFingerprint &&
      (!self.hasRemoteFingerprint || [self.remoteFingerprint isEqual:otherMessage.remoteFingerprint]) &&
      (self.unknownFields == otherMessage.unknownFields || (self.unknownFields != nil && [self.unknownFields isEqual:otherMessage.unknownFields]));
}
- (NSUInteger) hash {
  __block NSUInteger hashCode = 7;
  if (self.hasVersion) {
    hashCode = hashCode * 31 + [[NSNumber numberWithInteger:self.version] hash];
  }
  if (self.hasLocalFingerprint) {
    hashCode = hashCode * 31 + [self.localFingerprint hash];
  }
  if (self.hasRemoteFingerprint) {
    hashCode = hashCode * 31 + [self.remoteFingerprint hash];
  }
  hashCode = hashCode * 31 + [self.unknownFields hash];
  return hashCode;
}
@end

@interface OWSFingerprintProtosLogicalFingerprintsBuilder()
@property (strong) OWSFingerprintProtosLogicalFingerprints* resultLogicalFingerprints;
@end

@implementation OWSFingerprintProtosLogicalFingerprintsBuilder
@synthesize resultLogicalFingerprints;
- (instancetype) init {
  if ((self = [super init])) {
    self.resultLogicalFingerprints = [[OWSFingerprintProtosLogicalFingerprints alloc] init];
  }
  return self;
}
- (PBGeneratedMessage*) internalGetResult {
  return resultLogicalFingerprints;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) clear {
  self.resultLogicalFingerprints = [[OWSFingerprintProtosLogicalFingerprints alloc] init];
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) clone {
  return [OWSFingerprintProtosLogicalFingerprints builderWithPrototype:resultLogicalFingerprints];
}
- (OWSFingerprintProtosLogicalFingerprints*) defaultInstance {
  return [OWSFingerprintProtosLogicalFingerprints defaultInstance];
}
- (OWSFingerprintProtosLogicalFingerprints*) build {
  [self checkInitialized];
  return [self buildPartial];
}
- (OWSFingerprintProtosLogicalFingerprints*) buildPartial {
  OWSFingerprintProtosLogicalFingerprints* returnMe = resultLogicalFingerprints;
  self.resultLogicalFingerprints = nil;
  return returnMe;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) mergeFrom:(OWSFingerprintProtosLogicalFingerprints*) other {
  if (other == [OWSFingerprintProtosLogicalFingerprints defaultInstance]) {
    return self;
  }
  if (other.hasVersion) {
    [self setVersion:other.version];
  }
  if (other.hasLocalFingerprint) {
    [self mergeLocalFingerprint:other.localFingerprint];
  }
  if (other.hasRemoteFingerprint) {
    [self mergeRemoteFingerprint:other.remoteFingerprint];
  }
  [self mergeUnknownFields:other.unknownFields];
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) mergeFromCodedInputStream:(PBCodedInputStream*) input {
  return [self mergeFromCodedInputStream:input extensionRegistry:[PBExtensionRegistry emptyRegistry]];
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) mergeFromCodedInputStream:(PBCodedInputStream*) input extensionRegistry:(PBExtensionRegistry*) extensionRegistry {
  PBUnknownFieldSetBuilder* unknownFields = [PBUnknownFieldSet builderWithUnknownFields:self.unknownFields];
  while (YES) {
    SInt32 tag = [input readTag];
    switch (tag) {
      case 0:
        [self setUnknownFields:[unknownFields build]];
        return self;
      default: {
        if (![self parseUnknownField:input unknownFields:unknownFields extensionRegistry:extensionRegistry tag:tag]) {
          [self setUnknownFields:[unknownFields build]];
          return self;
        }
        break;
      }
      case 8: {
        [self setVersion:[input readUInt32]];
        break;
      }
      case 18: {
        OWSFingerprintProtosLogicalFingerprintBuilder* subBuilder = [OWSFingerprintProtosLogicalFingerprint builder];
        if (self.hasLocalFingerprint) {
          [subBuilder mergeFrom:self.localFingerprint];
        }
        [input readMessage:subBuilder extensionRegistry:extensionRegistry];
        [self setLocalFingerprint:[subBuilder buildPartial]];
        break;
      }
      case 26: {
        OWSFingerprintProtosLogicalFingerprintBuilder* subBuilder = [OWSFingerprintProtosLogicalFingerprint builder];
        if (self.hasRemoteFingerprint) {
          [subBuilder mergeFrom:self.remoteFingerprint];
        }
        [input readMessage:subBuilder extensionRegistry:extensionRegistry];
        [self setRemoteFingerprint:[subBuilder buildPartial]];
        break;
      }
    }
  }
}
- (BOOL) hasVersion {
  return resultLogicalFingerprints.hasVersion;
}
- (UInt32) version {
  return resultLogicalFingerprints.version;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) setVersion:(UInt32) value {
  resultLogicalFingerprints.hasVersion = YES;
  resultLogicalFingerprints.version = value;
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) clearVersion {
  resultLogicalFingerprints.hasVersion = NO;
  resultLogicalFingerprints.version = 0;
  return self;
}
- (BOOL) hasLocalFingerprint {
  return resultLogicalFingerprints.hasLocalFingerprint;
}
- (OWSFingerprintProtosLogicalFingerprint*) localFingerprint {
  return resultLogicalFingerprints.localFingerprint;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) setLocalFingerprint:(OWSFingerprintProtosLogicalFingerprint*) value {
  resultLogicalFingerprints.hasLocalFingerprint = YES;
  resultLogicalFingerprints.localFingerprint = value;
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) setLocalFingerprintBuilder:(OWSFingerprintProtosLogicalFingerprintBuilder*) builderForValue {
  return [self setLocalFingerprint:[builderForValue build]];
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) mergeLocalFingerprint:(OWSFingerprintProtosLogicalFingerprint*) value {
  if (resultLogicalFingerprints.hasLocalFingerprint &&
      resultLogicalFingerprints.localFingerprint != [OWSFingerprintProtosLogicalFingerprint defaultInstance]) {
    resultLogicalFingerprints.localFingerprint =
      [[[OWSFingerprintProtosLogicalFingerprint builderWithPrototype:resultLogicalFingerprints.localFingerprint] mergeFrom:value] buildPartial];
  } else {
    resultLogicalFingerprints.localFingerprint = value;
  }
  resultLogicalFingerprints.hasLocalFingerprint = YES;
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) clearLocalFingerprint {
  resultLogicalFingerprints.hasLocalFingerprint = NO;
  resultLogicalFingerprints.localFingerprint = [OWSFingerprintProtosLogicalFingerprint defaultInstance];
  return self;
}
- (BOOL) hasRemoteFingerprint {
  return resultLogicalFingerprints.hasRemoteFingerprint;
}
- (OWSFingerprintProtosLogicalFingerprint*) remoteFingerprint {
  return resultLogicalFingerprints.remoteFingerprint;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) setRemoteFingerprint:(OWSFingerprintProtosLogicalFingerprint*) value {
  resultLogicalFingerprints.hasRemoteFingerprint = YES;
  resultLogicalFingerprints.remoteFingerprint = value;
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) setRemoteFingerprintBuilder:(OWSFingerprintProtosLogicalFingerprintBuilder*) builderForValue {
  return [self setRemoteFingerprint:[builderForValue build]];
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) mergeRemoteFingerprint:(OWSFingerprintProtosLogicalFingerprint*) value {
  if (resultLogicalFingerprints.hasRemoteFingerprint &&
      resultLogicalFingerprints.remoteFingerprint != [OWSFingerprintProtosLogicalFingerprint defaultInstance]) {
    resultLogicalFingerprints.remoteFingerprint =
      [[[OWSFingerprintProtosLogicalFingerprint builderWithPrototype:resultLogicalFingerprints.remoteFingerprint] mergeFrom:value] buildPartial];
  } else {
    resultLogicalFingerprints.remoteFingerprint = value;
  }
  resultLogicalFingerprints.hasRemoteFingerprint = YES;
  return self;
}
- (OWSFingerprintProtosLogicalFingerprintsBuilder*) clearRemoteFingerprint {
  resultLogicalFingerprints.hasRemoteFingerprint = NO;
  resultLogicalFingerprints.remoteFingerprint = [OWSFingerprintProtosLogicalFingerprint defaultInstance];
  return self;
}
@end


// @@protoc_insertion_point(global_scope)
