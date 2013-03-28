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
		mergeKeychainPath = [kSMOPSyncPath retain];
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

- (void)pushKeychain {
	BOOL pushAttempt = FALSE;
	AFCApplicationDirectory *pushToDevice = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([pushToDevice ensureConnectionIsOpen]) {
		afc_connection conn = [pushToDevice getAFC];
		AFCDirectoryCreate(conn, [kOnePasswordRemotePath UTF8String]);
		NSArray *keychainContents = [[NSFileManager defaultManager] subpathsAtPath:localKeychainPath];
		for (NSString *path in keychainContents) {
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:[localKeychainPath stringByAppendingPathComponent:path] isDirectory:&isDir]) {
				if (isDir) {
					AFCDirectoryCreate(conn, [[kOnePasswordRemotePath stringByAppendingPathComponent:path] UTF8String]);
				} else {
					pushAttempt = [pushToDevice copyLocalFile:[localKeychainPath stringByAppendingPathComponent:path] toRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:path]];
				}
			}
		}
		[pushToDevice close];
	}
	[pushToDevice release];
}

- (BOOL)keychainChecks {
	BOOL directory;
	BOOL result = [[NSFileManager defaultManager] fileExistsAtPath:localKeychainPath isDirectory:&directory];
	if (result && directory) {
		result = [[NSFileManager defaultManager] fileExistsAtPath:[localKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] isDirectory:&directory];
		if (!result) {
			// empty local keychain file, prompt.
			if ([NSAlert cannotFindLocalKeychain] == NSAlertFirstButtonReturn) {
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
			if ([NSAlert cannotFindKeychainOnDevice:[device deviceName]] == NSAlertFirstButtonReturn) {
				[self pushKeychain];
			} else {
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
		
		BOOL copyResult = TRUE;
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
		
		NSMutableSet *newContents = [NSMutableSet new];
		
		AFCApplicationDirectory *initiateSync = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([initiateSync ensureConnectionIsOpen]) {
			afc_connection conn = [initiateSync getAFC];
			afc_error_t initialError = AFCDirectoryCreate(conn, [@"/Documents/SMOP/" UTF8String]);		
			[initiateSync close];
		}
		[initiateSync release];

		NSArray *copyToLocal = [addToLocal allObjects];
		AFCApplicationDirectory *copyToLocalService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([copyToLocalService ensureConnectionIsOpen]) {
			for (NSString *item in copyToLocal) {
				copyResult = [copyToLocalService copyRemoteFile:GetDeviceOnePasswordItemWithName(item) toLocalFile:GetLocalOnePasswordItemWithName(item)];
				if (copyResult) {
					NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",item];
					SMOPContentsItem *deviceItem = [[deviceContents filteredSetUsingPredicate:filterPredicate] anyObject];
					[newContents addObject:deviceItem];
				}
			}
			[copyToLocalService close];
		}
		[copyToLocalService release];

		NSArray *copyToDevice = [addToDevice allObjects];
		AFCApplicationDirectory *copyToDeviceService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([copyToDeviceService ensureConnectionIsOpen]) {
			for (NSString *item in copyToDevice) {
				copyResult = [copyToDeviceService copyLocalFile:GetLocalOnePasswordItemWithName(item) toRemoteFile:GetDeviceOnePasswordItemWithName(item)];
				if (copyResult) {
					NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",item];
					SMOPContentsItem *localItem = [[localContents filteredSetUsingPredicate:filterPredicate] anyObject];
					[newContents addObject:localItem];
				}
			}
			[copyToDeviceService close];
		}
		[copyToDeviceService release];
		
		[matches enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			BOOL copyResult = TRUE;
			NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",obj];
			SMOPContentsItem *localItem = [[localContents filteredSetUsingPredicate:filterPredicate] anyObject];
			SMOPContentsItem *deviceItem = [[deviceContents filteredSetUsingPredicate:filterPredicate] anyObject];
			NSComparisonResult conflictCompare = [localItem.modifiedDate compare:deviceItem.modifiedDate];
			switch (conflictCompare) {
				case NSOrderedDescending: {
					// local newer
					AFCApplicationDirectory *copyToDevice = [device newAFCApplicationDirectory:kOnePasswordBundleId];
					if ([copyToDevice ensureConnectionIsOpen]) {
						afc_connection conn = [copyToDevice getAFC];
						afc_error_t _err = AFCRemovePath(conn, [GetDeviceOnePasswordItemWithName(obj) UTF8String]);
						if (_err == 0) {
							copyResult = [copyToDevice copyLocalFile:GetLocalOnePasswordItemWithName(obj) toRemoteFile:GetDeviceOnePasswordItemWithName(obj)];
						} else {
							// throw error
							[NSAlert connectionErrorWithDevice:[device deviceName]];
							*stop = YES;
						}
						[copyToDevice close];
					}
					[copyToDevice release];
					
					if (copyResult)
						[newContents addObject:localItem];
					
					break;
				};
				case NSOrderedAscending: {
					// device newer
					AFCApplicationDirectory *copyToMergeService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
					if ([copyToMergeService ensureConnectionIsOpen]) {
						copyResult = [copyToMergeService copyRemoteFile:GetDeviceOnePasswordItemWithName(obj) toLocalFile:GetMergeOnePasswordItemWithName(obj)];
						[copyToMergeService close];
					}
					[copyToMergeService release];
					
					if (copyResult) {
						// remove local file then move from merge
						copyResult = [[NSFileManager defaultManager] removeItemAtPath:GetLocalOnePasswordItemWithName(obj) error:nil];
						if (copyResult)
							copyResult = [[NSFileManager defaultManager] moveItemAtPath:GetMergeOnePasswordItemWithName(obj) toPath:GetLocalOnePasswordItemWithName(obj) error:nil];
						if (copyResult)
							[newContents addObject:deviceItem];
					}
					break;
				};
				case NSOrderedSame: {
					[newContents addObject:localItem];
					break;
				};
				default: {
					break;
				};
			}	
		}];
		
		// write updated contents.js
		NSString *contentsJS = [JSMNParser serializeJSON:[newContents allObjects]];
		copyResult = [[NSFileManager defaultManager] removeItemAtPath:[OnePasswordKeychainPath() stringByAppendingPathComponent:kOnePasswordInternalContentsPath] error:nil];
		if (copyResult)
			copyResult = [contentsJS writeToFile:[OnePasswordKeychainPath() stringByAppendingPathComponent:kOnePasswordInternalContentsPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
		if (copyResult) {
			AFCApplicationDirectory *contentsToDevice = [device newAFCApplicationDirectory:kOnePasswordBundleId];
			if ([contentsToDevice ensureConnectionIsOpen]) {
				afc_connection conn = [contentsToDevice getAFC];
				afc_error_t _err = AFCRemovePath(conn, [[kOnePasswordRemotePath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] UTF8String]);
				if (_err == 0) {
					copyResult = [contentsToDevice copyLocalFile:[OnePasswordKeychainPath() stringByAppendingPathComponent:kOnePasswordInternalContentsPath] toRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:kOnePasswordInternalContentsPath]];
				} else {
					// throw error
					[NSAlert connectionErrorWithDevice:[device deviceName]];
				}
				[contentsToDevice close];
			}
			[contentsToDevice release];
		}
		
		AFCApplicationDirectory *finalizeSync = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([finalizeSync ensureConnectionIsOpen]) {
			afc_connection conn = [finalizeSync getAFC];
			afc_error_t finalError = AFCRemovePath(conn, [@"/Documents/SMOP/" UTF8String]);
			[finalizeSync close];
		}
		[finalizeSync release];
		
		[newContents release];
		[addToLocal release];
		[addToDevice release];
		[matches release];
	}
}

- (void)cleanUpMergeData {
	[[NSFileManager defaultManager] removeItemAtPath:kSMOPSyncPath error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPSyncPath withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)synchronizePasswords {
	[self cleanUpMergeData];
	BOOL result = [self keychainChecks];
	if (result) {
		[self loadContentsData];
		[self mergeLocalAndDeviceContents];
		[self cleanUpMergeData];
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
