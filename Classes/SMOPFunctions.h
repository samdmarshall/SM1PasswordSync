/*
 *  SMOPFunctions.h
 *  SM1Password Sync
 *
 *  Created by sam on 3/18/13.
 *  Copyright 2013 Sam Marshall. All rights reserved.
 *
 */
#import <CommonCrypto/CommonDigest.h>
#import "SMOPDefines.h"
#import "MobileDeviceAccess.h"

static inline NSData* SHA1HashOfFileAtPath(NSString *path) {
	unsigned char hashBytes[CC_SHA1_DIGEST_LENGTH];
	NSData *fileData = [NSData dataWithContentsOfFile:path];
	CC_SHA1([fileData bytes], [fileData length], hashBytes);
	return [NSData dataWithBytes:hashBytes length:CC_SHA1_DIGEST_LENGTH];
}

static inline NSString* OnePasswordKeychainPath() {
	NSDictionary *preferenceFile = [NSDictionary dictionaryWithContentsOfFile:kOnePasswordPreferencesPath];
	return [[preferenceFile objectForKey:@"AgileKeychainLocation"] stringByExpandingTildeInPath];
}

static inline NSInteger GetLocalContentsItemCount() {
	NSString *localPath = [[OnePasswordKeychainPath() stringByAppendingPathComponent:kOnePasswordInternalContentsPath] stringByDeletingLastPathComponent];
	NSInteger contentsDirectoryCount = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:localPath error:nil] count];
	return ((contentsDirectoryCount-5)*9)+1;
}

static inline NSInteger GetRemoteContentsItemCount(AMDevice *device) {
	NSInteger count = 1;
	AFCApplicationDirectory *contentsCount = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([contentsCount ensureConnectionIsOpen]) {
		NSInteger deviceDirContentsCount = [[contentsCount directoryContents:[kOnePasswordRemotePath stringByAppendingPathComponent:@"/data/default/"]] count];
		count = ((deviceDirContentsCount-3)*9)+1;
	}
	return count;
}

static inline NSString* GetLocalOnePasswordItemWithName(NSString *name) {
	return [OnePasswordKeychainPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",name]];
}

static inline NSString* GetMergeOnePasswordItemWithName(NSString *name) {
	return [kSMOPApplicationSupportPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/sync/data/default/%@.1password",name]];
}

static inline NSString* GetDeviceOnePasswordItemWithName(NSString *name) {
	return [kOnePasswordRemotePath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",name]];
}

static inline NSString* GetSyncStateFileForDevice(NSString *udid) {
	return [kSMOPSyncStatePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist",udid]];
}