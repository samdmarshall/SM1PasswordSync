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

static BOOL InstallAppToDevice(CFStringRef path, struct am_device *device, void *transfer_callback, void *install_callback) {
	int afcFd;
	CFStringRef keys[] = { CFSTR("PackageType") };
	CFStringRef values[] = { CFSTR("Developer") };
	CFDictionaryRef options = CFDictionaryCreate(NULL, (const void **)&keys, (const void **)&values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    int installFd;
	BOOL copyResult = FALSE, installResult = FALSE;
	copyResult = (AMDeviceConnect(device) == MDERR_OK ?
		(AMDeviceIsPaired(device) ?
			(AMDeviceValidatePairing(device) == MDERR_OK ?
				(AMDeviceStartSession(device) == MDERR_OK ?
					(AMDeviceStartService(device, AMSVC_AFC, &afcFd, NULL) == MDERR_OK ?
						(AMDeviceStopSession(device) == MDERR_OK ?
							(AMDeviceDisconnect(device) == MDERR_OK ?
								(AMDeviceTransferApplication(afcFd, path, NULL, transfer_callback, NULL) == MDERR_OK ? TRUE : FALSE)
							: FALSE)
						: FALSE)
					: FALSE)
				: FALSE)
			: FALSE)
		: FALSE)
	: FALSE);
	close(afcFd);
	if (copyResult)
		installResult = (AMDeviceConnect(device) == MDERR_OK ?
			(AMDeviceIsPaired(device) ?
				(AMDeviceValidatePairing(device) == MDERR_OK ?
					(AMDeviceStartSession(device) == MDERR_OK ?
						(AMDeviceStartService(device, AMSVC_INSTALLATION_PROXY, &installFd, NULL) == MDERR_OK ?
							(AMDeviceStopSession(device) == MDERR_OK ?
								(AMDeviceDisconnect(device) == MDERR_OK ?
									(AMDeviceInstallApplication(installFd, path, options, install_callback, NULL) == MDERR_OK ? TRUE : FALSE)
								: FALSE)
							: FALSE)
						: FALSE)
					: FALSE)
				: FALSE)
			: FALSE)
		: FALSE);
	close(installFd);
	CFRelease(options);
	return (copyResult && installResult);
}

static inline NSString* MobileApplicationsDirectory() {
	BOOL dir;
	NSString *iTunesDatabasePath = [[[NSString alloc] initWithString:[@"~/Music/iTunes/iTunes Music Library.xml" stringByExpandingTildeInPath]] autorelease];
	if ([[NSFileManager defaultManager] fileExistsAtPath:iTunesDatabasePath isDirectory:&dir]) {
		NSDictionary *iTunesDatabase = [[[NSDictionary alloc] initWithContentsOfFile:iTunesDatabasePath] autorelease];
		return [[[NSURL URLWithString:[iTunesDatabase objectForKey:@"Music Folder"]] path] stringByAppendingPathComponent:@"Mobile Applications"];
	} else {
		return nil;
	}
}

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