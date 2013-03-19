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
	
	NSArray *localData = [localDataJSON objectFromJSONStringWithParseOptions:JKParseOptionStrict error:&err];							
	NSArray *remoteData = [deviceDataJSON objectFromJSONStringWithParseOptions:JKParseOptionStrict error:&err];
	
	[localData enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newLocalItem = [[SMOPContentsItem alloc] initWithArray:obj];
		[localContents addObject:newLocalItem];
	}];
	
	[remoteData enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newDeviceItem = [[SMOPContentsItem alloc] initWithArray:obj];
		[deviceContents addObject:newDeviceItem];
	}];
	
	
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

- (void)mergeLocalAndDeviceContents {
	NSSet *deviceIds = [deviceContents valueForKey:@"uniqueId"];
	NSSet *localIds = [localContents valueForKey:@"uniqueId"];
	BOOL copyResult = FALSE;
	
	NSMutableSet *addToLocal = [NSMutableSet setWithSet:deviceIds];
	[addToLocal minusSet:localIds];
	NSArray *copyToLocal = [addToLocal allObjects];
	AFCApplicationDirectory *copyToLocalService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([copyToLocalService ensureConnectionIsOpen]) {
		for (NSString *item in copyToLocal) {
			//copyResult = [copyToLocalService copyRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]] toLocalFile:[localKeychainPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]]];
		}
		[copyToLocalService close];
	}
	[copyToLocalService release];
	
	NSMutableSet *addToDevice = [NSMutableSet setWithSet:localIds];
	[addToDevice minusSet:deviceIds];
	NSArray *copyToDevice = [addToDevice allObjects];
	AFCApplicationDirectory *copyToDeviceService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([copyToDeviceService ensureConnectionIsOpen]) {
		for (NSString *item in copyToDevice) {
			//copyResult = [copyToDeviceService copyLocalFile:[localKeychainPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]] toRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]]];
		}
		[copyToDeviceService close];
	}
	[copyToDeviceService release];
	
	
	NSMutableSet *matches = [NSMutableSet setWithSet:localIds];
	[matches unionSet:deviceIds];
	[matches minusSet:addToLocal];
	[matches minusSet:addToDevice];
	
	[matches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",obj];
		SMOPContentsItem *localItem = [[localContents filteredSetUsingPredicate:filterPredicate] anyObject];
		SMOPContentsItem *deviceItem = [[deviceContents filteredSetUsingPredicate:filterPredicate] anyObject];
		NSComparisonResult conflictComopare = [localItem.modifiedDate compare:deviceItem.modifiedDate];
		switch (conflictComopare) {
			case NSOrderedAscending: {
				// device newer
				break;
			};
			case NSOrderedSame: {
				break;
			};
			case NSOrderedDescending: {
				// local newer
				break;
			};
			default: {
				break;
			};
		}	
	}];
}

- (void)cleanUpMergeData {
	
}

- (void)synchronizePasswords {
	BOOL result = [self keychainChecks];
	if (result) {
		[self loadContentsData];
		[self mergeLocalAndDeviceContents];
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
