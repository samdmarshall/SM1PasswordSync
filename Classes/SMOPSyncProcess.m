//
//  SMOPSyncProcess.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPSyncProcess.h"
#import "SMOPFunctions.h"
#import "JSONKit.h"
#import "NSAlert+Additions.h"
#import "SMOPContentsItem.h"

@implementation SMOPSyncProcess

- (id)init {
	self = [super init];
	if (self) {
		localKeychainPath = (NSString *)OnePasswordKeychainPath();
		mergeKeychainPath = kSMOPApplicationSupportPath;
		deviceContents = [NSMutableSet new];
		localContents = [NSMutableSet new];
	}
	return self;
}

- (void)setSyncDevice:(AMDevice *)syncDevice {
	device = syncDevice;
}

- (void)loadContentsData {
	NSError *err;
	
	NSString *localDataJSON = [NSString stringWithContentsOfFile:[localKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] encoding:NSUTF8StringEncoding error:&err];
	NSString *deviceDataJSON = [NSString stringWithContentsOfFile:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] encoding:NSUTF8StringEncoding error:&err];
	
	[[localDataJSON objectFromJSONStringWithParseOptions:JKParseOptionStrict error:&err] enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newLocalItem = [[[SMOPContentsItem alloc] initWithArray:obj] autorelease];
		[localContents addObject:newLocalItem];
	}];
	
	[[deviceDataJSON objectFromJSONStringWithParseOptions:JKParseOptionStrict error:&err] enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newDeviceItem = [[[SMOPContentsItem alloc] initWithArray:obj] autorelease];
		[deviceContents addObject:newDeviceItem];
	}];
	
	//NSArray *localData = [localDataJSON objectFromJSONStringWithParseOptions:JKParseOptionStrict error:&err];							
	//NSArray *remoteData = [deviceDataJSON objectFromJSONStringWithParseOptions:JKParseOptionStrict error:&err];
	
	//[localContents addObjectsFromArray:localData];
	//[deviceContents addObjectsFromArray:remoteData];
}

- (BOOL)keychainChecks {
	BOOL directory;
	BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:localKeychainPath isDirectory:&directory];
	if (result && directory) {
		result = [[NSFileManager defaultManager] fileExistsAtPath:[localKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] isDirectory:&directory];
		if (!result) {
			// empty local keychain file, prompt.
			if ([NSAlert emptyKeychainAlertAtPath:localKeychainPath] == NSAlertFirstButtonReturn) {
				return NO;
			}
		}
		// check device file
		BOOL deviceContentsCheck = FALSE;
		AFCApplicationDirectory *fileCheck = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([fileCheck ensureConnectionIsOpen]) {
			deviceContentsCheck = [fileCheck fileExistsAtPath:[kOnePasswordRemotePath stringByAppendingPathComponent:kOnePasswordInternalContentsPath]];
			[fileCheck close];
		}
		[fileCheck release];
		
		// move to merge
		BOOL copyToMerge = FALSE;
		if (!deviceContentsCheck) {
			if ([NSAlert emptyKeychainAlertAtPath:[device deviceName]] == NSAlertFirstButtonReturn) {
				return NO;
			}
		} else {
			AFCApplicationDirectory *fileMerge = [device newAFCApplicationDirectory:kOnePasswordBundleId];
			if ([fileMerge ensureConnectionIsOpen]) {
				copyToMerge = [fileMerge copyRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] toLocalFile:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath]];
				[fileMerge close];
			}
			[fileMerge release];
		}
		result = ((deviceContentsCheck && copyToMerge) ? TRUE : FALSE);
	}
	return result;
}

- (NSSet *)mergeLocalAndDeviceContents {
	NSMutableSet *conflictItems = [NSMutableSet new];
	
	return conflictItems;
}

- (void)cleanUpMergeData {
	
}

- (void)synchronizePasswords {
	BOOL result = [self keychainChecks];
	if (result) {
		[self loadContentsData];
		
		[self cleanUpMergeData];
	} else {
		NSLog(@"Connection Failed");
	}
}

- (void)dealloc {
	[localKeychainPath release];
	[mergeKeychainPath release];
	[localContents release];
	[deviceContents release];
	[device release];
	[super dealloc];
}

@end
