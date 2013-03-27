//
//  SMOPSyncProcess.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPSyncProcess.h"
#import "SMOPFunctions.h"
#import "NSAlert+Additions.h"
#import "SMOPContentsItem.h"
#import "JSMNParser.h"

@implementation SMOPSyncProcess

- (id)init {
	self = [super init];
	if (self) {
		localKeychainPath = [(NSString *)OnePasswordKeychainPath() retain];
		mergeKeychainPath = [kSMOPApplicationSupportPath retain];
		deviceContents = [NSMutableSet new];
		localContents = [NSMutableSet new];
	}
	return self;
}

- (void)setSyncDevice:(AMDevice *)syncDevice {
	device = [syncDevice retain];
}

- (void)loadContentsData {
	JSMNParser *localParser = [[JSMNParser alloc] initWithPath:[localKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] tokenCount:GetLocalContentsItemCount()];
	NSArray *localData = [localParser deserializeJSON];	
	[localData enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newLocalItem = [[SMOPContentsItem alloc] initWithArray:obj];
		[localContents addObject:newLocalItem];
		[newLocalItem release];
	}];
	[localParser release];
	
	JSMNParser *deviceParser = [[JSMNParser alloc] initWithPath:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] tokenCount:GetRemoteContentsItemCount(device)];	
	NSArray *remoteData = [deviceParser deserializeJSON];
	[remoteData enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newDeviceItem = [[SMOPContentsItem alloc] initWithArray:obj];
		[deviceContents addObject:newDeviceItem];
		[newDeviceItem release];
	}];
	[deviceParser release];
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
	if ([deviceContents count] && [localContents count]) {
		NSSet *deviceIds = [deviceContents valueForKey:@"uniqueId"];
		NSSet *localIds = [localContents valueForKey:@"uniqueId"];
		
		BOOL copyResult = FALSE;
		NSMutableSet *matches = [NSMutableSet new];
		
		NSMutableSet *addToDevice = [NSMutableSet new];
		[localIds enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			NSPredicate *devicePredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", deviceIds];
		 	if ([devicePredicate evaluateWithObject:obj]) {
				NSPredicate *matchesPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", matches];
				if (![matchesPredicate evaluateWithObject:obj]) {
					[matches addObject:obj];
				}
			} else {
				[addToDevice addObject:obj];
			}
		}];
		
		NSMutableSet *addToLocal = [NSMutableSet new];
		[deviceIds enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			NSPredicate *localPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", localIds];
		 	if ([localPredicate evaluateWithObject:obj]) {
				NSPredicate *matchesPredicate = [NSPredicate predicateWithFormat:@"SELF IN %@", matches];
				if (![matchesPredicate evaluateWithObject:obj]) {
					[matches addObject:obj];
				}
			} else {
				[addToLocal addObject:obj];
			}
		}];
		

		NSArray *copyToLocal = [addToLocal allObjects];
		AFCApplicationDirectory *copyToLocalService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([copyToLocalService ensureConnectionIsOpen]) {
			for (NSString *item in copyToLocal) {
				//copyResult = [copyToLocalService copyRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]] toLocalFile:[localKeychainPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]]];
			}
			[copyToLocalService close];
		}
		[copyToLocalService release];
		[addToLocal release];

		NSArray *copyToDevice = [addToDevice allObjects];
		AFCApplicationDirectory *copyToDeviceService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([copyToDeviceService ensureConnectionIsOpen]) {
			for (NSString *item in copyToDevice) {
				//copyResult = [copyToDeviceService copyLocalFile:[localKeychainPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]] toRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:[NSString stringWithFormat:@"/data/default/%@.1password",item]]];
			}
			[copyToDeviceService close];
		}
		[copyToDeviceService release];
		[addToDevice release];
		
		[matches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",obj];
			SMOPContentsItem *localItem = [[localContents filteredSetUsingPredicate:filterPredicate] anyObject];
			SMOPContentsItem *deviceItem = [[deviceContents filteredSetUsingPredicate:filterPredicate] anyObject];
			NSComparisonResult conflictCompare = [localItem.modifiedDate compare:deviceItem.modifiedDate];
			switch (conflictCompare) {
				case NSOrderedAscending: {
					// device newer
					NSLog(@"Conflict Found From Device");
					break;
				};
				case NSOrderedSame: {
					// ignore, both are the same
					break;
				};
				case NSOrderedDescending: {
					// local newer
					NSLog(@"Conflict Found From Local");
					break;
				};
				default: {
					break;
				};
			}	
		}];
		[matches release];
	}
}

- (void)cleanUpMergeData {
	[[NSFileManager defaultManager] removeItemAtPath:[kSMOPApplicationSupportPath stringByAppendingPathComponent:@"/data/"] error:nil];
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
