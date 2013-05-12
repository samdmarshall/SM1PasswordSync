//
//  SMOPSyncProcess.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPSyncProcess.h"
#import "NSAlert+Additions.h"
#import "SMOPContentsItem.h"
#import "JSMNParser.h"
#import "ZipArchive.h"

void* callbackSelf;
// CFStringRef last_path = NULL;

void transfer_callback(CFDictionaryRef dict, int arg) {
    int percent;
    CFStringRef status = CFDictionaryGetValue(dict, CFSTR("Status"));
    CFNumberGetValue(CFDictionaryGetValue(dict, CFSTR("PercentComplete")), kCFNumberSInt32Type, &percent);
    if (CFEqual(status, CFSTR("CopyingFile"))) {
        CFStringRef path = CFDictionaryGetValue(dict, CFSTR("Path"));
        if (/*(last_path == NULL || !CFEqual(path, last_path)) &&*/ !CFStringHasSuffix(path, CFSTR(".ipa"))) {
            //printf("[%3d%%] Copying %s to device\n", percent / 2, CFStringGetCStringPtr(path, kCFStringEncodingMacRoman));
			[[(SMOPSyncProcess *)callbackSelf delegate] syncItemNumber:(percent / 2) ofTotal:100];
        }
        //if (last_path != NULL) {
				//  CFRelease(last_path);
        //}
        //last_path = CFStringCreateCopy(NULL, path);
    }
}

void install_callback(CFDictionaryRef dict, int arg) {
    int percent;
    //CFStringRef status = CFDictionaryGetValue(dict, CFSTR("Status"));
    CFNumberGetValue(CFDictionaryGetValue(dict, CFSTR("PercentComplete")), kCFNumberSInt32Type, &percent);
    //printf("[%3d%%] %s\n", (percent / 2) + 50, CFStringGetCStringPtr(status, kCFStringEncodingMacRoman));
	[[(SMOPSyncProcess *)callbackSelf delegate] syncItemNumber:((percent / 2) + 50) ofTotal:100];
}

@interface SMOPSyncProcess()
- (BOOL)validateKeysFileAtPath:(NSString *)path;
@end

@implementation SMOPSyncProcess

@synthesize delegate;

- (id)init {
	self = [super init];
	if (self) {
		callbackSelf = self;
		deviceContents = [NSMutableSet new];
		localContents = [NSMutableSet new];
		deviceSyncError = FALSE;
	}
	return self;
}

- (void)dealloc {
	[localContents release];
	[deviceContents release];
	[device release];
	[super dealloc];
}

- (AMDevice *)getSyncDevice {
	return device;
}

- (void)setSyncDevice:(AMDevice *)syncDevice withSyncStatus:(BOOL)status {
	device = [syncDevice retain];
	deviceSyncError = status;
	mergeKeychainPath = [kSMOPSyncPath stringByAppendingPathComponent:device.udid];
	localKeychainPath = (NSString *)OnePasswordKeychainPath();	
}

#pragma mark -
#pragma mark 1Password Sync

- (void)loadContentsData {
	JSMNParser *localParser = [[JSMNParser alloc] initWithPath:[OnePasswordKeychainPath() stringByAppendingPathComponent:kOnePasswordInternalContentsPath] tokenCount:GetLocalContentsItemCount()];
	NSArray *localData = [localParser deserializeContents];	
	[localData enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newLocalItem = [[SMOPContentsItem alloc] initWithArray:obj];
		[localContents addObject:newLocalItem];
		[newLocalItem release];
	}];
	[localParser release];
	
	JSMNParser *deviceParser = [[JSMNParser alloc] initWithPath:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalContentsPath] tokenCount:GetRemoteContentsItemCount(device)];	
	NSArray *remoteData = [deviceParser deserializeContents];
	[remoteData enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop) {
		SMOPContentsItem *newDeviceItem = [[SMOPContentsItem alloc] initWithArray:obj];
		[deviceContents addObject:newDeviceItem];
		[newDeviceItem release];
	}];
	[deviceParser release];
}

- (void)pushKeychain {
	BOOL pushAttempt = FALSE;
	NSUInteger syncItem = 0;
	AFCApplicationDirectory *pushToDevice = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([pushToDevice ensureConnectionIsOpen]) {
		[self initiateSyncingProcess];
		afc_connection conn = [pushToDevice getAFC];
		AFCDirectoryCreate(conn, [kOnePasswordRemotePath UTF8String]);
		NSArray *keychainContents = [[NSFileManager defaultManager] subpathsAtPath:localKeychainPath];
		NSUInteger syncItemsCount = [keychainContents count];
		for (NSString *path in keychainContents) {
			BOOL isDir;
			if ([[NSFileManager defaultManager] fileExistsAtPath:[localKeychainPath stringByAppendingPathComponent:path] isDirectory:&isDir]) {
				if (isDir) {
					AFCDirectoryCreate(conn, [[kOnePasswordRemotePath stringByAppendingPathComponent:path] UTF8String]);
				} else {
					pushAttempt = [pushToDevice copyLocalFile:[localKeychainPath stringByAppendingPathComponent:path] toRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:path]];
					if (pushAttempt) {
						syncItem++;
						NSString *fileName = [path lastPathComponent];
						if ([fileName isEqualToString:@"contents.js"]) {
							[self updateSyncingProcessToFile:fileName forSyncState:kContents];
						} else if ([fileName isEqualToString:@"1password.keys"]) {
							[self updateSyncingProcessToFile:fileName forSyncState:kCopyToDevice];
						} else if ([fileName isEqualToString:@"encryptionKeys.js"]) {
							[self updateSyncingProcessToFile:fileName forSyncState:kCopyToDevice];
						} else if ([[fileName pathExtension] isEqualToString:@"1password"]) {
							[self updateSyncingProcessToFile:[fileName stringByDeletingPathExtension] forSyncState:kCopyToDevice];
						} else {
							[self updateSyncingProcessToFile:fileName forSyncState:kCopyToDevice];
						}
						[self.delegate syncItemNumber:syncItem ofTotal:syncItemsCount];
					}
				}
			}
		}
		[self finishSyncingProcess];
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

- (BOOL)deviceSyncStateFileExistsLocally {
	NSString *deviceSyncFile = GetSyncStateFileForDevice([device udid]);
	return [[NSFileManager defaultManager] fileExistsAtPath:deviceSyncFile];
}

- (BOOL)validateKeysFileAtPath:(NSString *)path {		
	BOOL directory;
	BOOL checkLocalEncryption = [[NSFileManager defaultManager] fileExistsAtPath:[localKeychainPath stringByAppendingPathComponent:path] isDirectory:&directory];
	BOOL checkDeviceEncryption = FALSE;
	AFCApplicationDirectory *encryptionAccess = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([encryptionAccess ensureConnectionIsOpen]) {
		checkDeviceEncryption = [encryptionAccess fileExistsAtPath:[kOnePasswordRemotePath stringByAppendingPathComponent:path]];
		if (checkDeviceEncryption) {
			checkDeviceEncryption = [encryptionAccess copyRemoteFile:[kOnePasswordRemotePath stringByAppendingPathComponent:path] toLocalFile:[mergeKeychainPath stringByAppendingPathComponent:path]];
		}
		[encryptionAccess close];
	}
	[encryptionAccess release];
	return (checkLocalEncryption && checkDeviceEncryption);
}

- (BOOL)checkForSyncPossible {
	NSDictionary *localKeys, *remoteKeys, *localEncryptionKeys, *remoteEncryptionKeys;
	uint32_t tokenCount = 0;
	// check for valid keychain
	BOOL keysDict = [self validateKeysFileAtPath:kOnePasswordInternalKeysPath];
	if (keysDict) {
		localKeys = [NSDictionary dictionaryWithContentsOfFile:[localKeychainPath stringByAppendingPathComponent:kOnePasswordInternalKeysPath]];
		remoteKeys = [NSDictionary dictionaryWithContentsOfFile:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalKeysPath]];
		keysDict = [localKeys isEqualToDictionary:remoteKeys];
		if (keysDict) {
			tokenCount = [JSMNParser tokenCountForObject:localKeys] - 1;
		}
	}
		
	BOOL encryptionKeys = [self validateKeysFileAtPath:kOnePasswordInternalEncryptionKeysPath];
	if (encryptionKeys && keysDict) {
		JSMNParser *localEncryptionParser = [[JSMNParser alloc] initWithPath:[localKeychainPath stringByAppendingPathComponent:kOnePasswordInternalEncryptionKeysPath] tokenCount:tokenCount];
		localEncryptionKeys = [localEncryptionParser deserializeJSON];	
		[localEncryptionParser release];
		
		JSMNParser *remoteEncryptionParser = [[JSMNParser alloc] initWithPath:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalEncryptionKeysPath] tokenCount:tokenCount];
		remoteEncryptionKeys = [remoteEncryptionParser deserializeJSON];	
		[remoteEncryptionParser release];

		encryptionKeys = [localEncryptionKeys isEqualToDictionary:remoteEncryptionKeys];
	}
	
	[[NSFileManager defaultManager] removeItemAtPath:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalKeysPath] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[mergeKeychainPath stringByAppendingPathComponent:kOnePasswordInternalEncryptionKeysPath] error:nil];
	
	return (keysDict && encryptionKeys);
}

- (void)initiateSyncingProcess {
	if ([self deviceSyncStateFileExistsLocally]) {
		// this is a partial sync
	} else {
		// new sync
		
		NSMutableDictionary *syncState = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], kContents, [NSArray array], kCopyToDevice, [NSArray array], kCopyToLocal, [NSArray array], kMerge, nil];
		
		[syncState writeToFile:GetSyncStateFileForDevice([device udid]) atomically:YES];
		AFCApplicationDirectory *initiateSync = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([initiateSync ensureConnectionIsOpen]) {
			afc_connection conn = [initiateSync getAFC];
			AFCDirectoryCreate(conn, [@"/Documents/SMOP/" UTF8String]);
			[initiateSync copyLocalFile:GetSyncStateFileForDevice([device udid]) toRemoteFile:kSMOPDeviceSyncStatePath];
			[initiateSync close];
		}
		[initiateSync release];
	}
}

- (void)updateSyncingProcessToFile:(NSString *)name forSyncState:(NSString *)state {	
	if ([self deviceSyncStateFileExistsLocally]) {
		NSMutableDictionary *syncState = [NSDictionary dictionaryWithContentsOfFile:GetSyncStateFileForDevice([device udid])];
		if ([state isEqualToString:kContents]) {
			NSNumber *update = [syncState objectForKey:state];
			if (![update boolValue])
				[syncState setObject:[NSNumber numberWithBool:YES] forKey:state];
		} else {
			NSMutableArray *stage = [NSMutableArray arrayWithArray:[syncState objectForKey:state]];
			[stage addObject:name];
			[syncState setObject:stage forKey:state];
		}
		[syncState writeToFile:GetSyncStateFileForDevice([device udid]) atomically:YES];
	}
	
	// push update to device
	AFCApplicationDirectory *progressiveSync = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([progressiveSync ensureConnectionIsOpen]) {
		afc_connection conn = [progressiveSync getAFC];
		AFCRenamePath(conn, [kSMOPDeviceSyncStatePath UTF8String], [kSMOPDeviceLastSyncStatePath UTF8String]);
		BOOL copyResult = [progressiveSync copyLocalFile:GetSyncStateFileForDevice([device udid]) toRemoteFile:kSMOPDeviceSyncStatePath];
		if (copyResult) {
			AFCRemovePath(conn, [kSMOPDeviceLastSyncStatePath UTF8String]);
		} else {
			AFCRenamePath(conn, [kSMOPDeviceLastSyncStatePath UTF8String], [kSMOPDeviceSyncStatePath UTF8String]);
		}
		[progressiveSync close];
	}
	[progressiveSync release];
}

- (void)finishSyncingProcess {
	AFCApplicationDirectory *finalizeSync = [device newAFCApplicationDirectory:kOnePasswordBundleId];
	if ([finalizeSync ensureConnectionIsOpen]) {
		afc_connection conn = [finalizeSync getAFC];
		AFCRemovePath(conn, [kSMOPDeviceSyncStatePath UTF8String]);
		AFCRemovePath(conn, [@"/Documents/SMOP/" UTF8String]);
		AFCDirectoryCreate(conn, [[kOnePasswordRemotePath stringByAppendingPathComponent:@"/SMOPUpdate/"] UTF8String]);		
		AFCRemovePath(conn, [[kOnePasswordRemotePath stringByAppendingPathComponent:@"/SMOPUpdate/"] UTF8String]);
		[finalizeSync close];
	}
	[finalizeSync release];
	
	if ([self deviceSyncStateFileExistsLocally]) {
		[[NSFileManager defaultManager] removeItemAtPath:GetSyncStateFileForDevice([device udid]) error:nil];
	}
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
		
		[self initiateSyncingProcess];
		__block NSUInteger syncItem = 0;
		NSUInteger syncItemsCount = [addToLocal count] + [addToDevice count] + [matches count] + 1;
		NSArray *copyToLocal = [addToLocal allObjects];
		AFCApplicationDirectory *copyToLocalService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
		if ([copyToLocalService ensureConnectionIsOpen]) {
			for (NSString *item in copyToLocal) {
				copyResult = [copyToLocalService copyRemoteFile:GetDeviceOnePasswordItemWithName(item) toLocalFile:GetLocalOnePasswordItemWithName(item)];
				if (copyResult) {
					[self updateSyncingProcessToFile:item forSyncState:kCopyToLocal];
					syncItem++;
					NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",item];
					SMOPContentsItem *deviceItem = [[deviceContents filteredSetUsingPredicate:filterPredicate] anyObject];
					[newContents addObject:deviceItem];
					[self.delegate syncItemNumber:syncItem ofTotal:syncItemsCount];
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
					[self updateSyncingProcessToFile:item forSyncState:kCopyToDevice];
					syncItem++;
					NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"uniqueId == %@",item];
					SMOPContentsItem *localItem = [[localContents filteredSetUsingPredicate:filterPredicate] anyObject];
					[newContents addObject:localItem];
					[self.delegate syncItemNumber:syncItem ofTotal:syncItemsCount];
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
				case NSOrderedDescending: // local newer
				case NSOrderedAscending: // device newer
				{
					// while different cases, both require that we copy the items to local to do data handling.
					AFCApplicationDirectory *copyToMergeService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
					if ([copyToMergeService ensureConnectionIsOpen]) {
						copyResult = [copyToMergeService copyRemoteFile:GetDeviceOnePasswordItemWithName(obj) toLocalFile:GetMergeOnePasswordItemWithName(obj)];
						[copyToMergeService close];
						// do not try to remove the local file before we close AND RELEASE the service or we end up smashing the stack somehow and causing all sorts of havoc!
					}
					[copyToMergeService release];

					if (copyResult) {
						JSMNParser *deviceParse = [[JSMNParser alloc] initWithPath:GetMergeOnePasswordItemWithName(obj) tokenCount:2000]; // probably performance problems here and next line with static token count, but whatever it all works out in the end.
						JSMNParser *localParse = [[JSMNParser alloc] initWithPath:GetLocalOnePasswordItemWithName(obj) tokenCount:2000];

						NSMutableDictionary *deviceItemDictionary = [NSMutableDictionary new];
						NSMutableDictionary *localItemDictionary = [NSMutableDictionary new];
						// creating the mutable dictionaries and filling them out with parsed data.
						[deviceItemDictionary setDictionary:[deviceParse deserializeJSON]];
						[localItemDictionary setDictionary:[localParse deserializeJSON]];
						NSNumber *newDate = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];

						if (conflictCompare == NSOrderedDescending) {
							// local newer
							[deviceItemDictionary addEntriesFromDictionary:localItemDictionary];
							[deviceItemDictionary setObject:newDate forKey:@"updatedAt"];
							localItem.modifiedDate = newDate;
							NSString *mergedItem = [JSMNParser serializeJSON:deviceItemDictionary];
							copyResult = [mergedItem writeToFile:GetMergeOnePasswordItemWithName(obj) atomically:YES encoding:NSUTF8StringEncoding error:nil];
							[newContents addObject:localItem];
						}
						if (conflictCompare == NSOrderedAscending) {
							// device newer
							[localItemDictionary addEntriesFromDictionary:deviceItemDictionary];
							[localItemDictionary setObject:newDate forKey:@"updatedAt"];
							deviceItem.modifiedDate = newDate;
							NSString *mergedItem = [JSMNParser serializeJSON:localItemDictionary];
							copyResult = [mergedItem writeToFile:GetMergeOnePasswordItemWithName(obj) atomically:YES encoding:NSUTF8StringEncoding error:nil];
							[newContents addObject:deviceItem];
						}
						
						[deviceParse release];
						[localParse release];
						[deviceItemDictionary release];
						[localItemDictionary release];
						
						if (copyResult) {
							AFCApplicationDirectory *copyToDevice = [device newAFCApplicationDirectory:kOnePasswordBundleId];
							if ([copyToDevice ensureConnectionIsOpen]) {
								afc_connection conn = [copyToDevice getAFC];
								afc_error_t _err = AFCRemovePath(conn, [GetDeviceOnePasswordItemWithName(obj) UTF8String]);
								if (_err == 0) {
									copyResult = [copyToDevice copyLocalFile:GetMergeOnePasswordItemWithName(obj) toRemoteFile:GetDeviceOnePasswordItemWithName(obj)];
									if (copyResult) {
										syncItem++;
									}
								} else {
									// throw error
									[NSAlert connectionErrorWithDevice:[device deviceName]];
									*stop = YES;
								}
								[copyToDevice close];
							}
							[copyToDevice release];

							copyResult = [[NSFileManager defaultManager] removeItemAtPath:GetLocalOnePasswordItemWithName(obj) error:nil];
							if (copyResult)
								copyResult = [[NSFileManager defaultManager] moveItemAtPath:GetMergeOnePasswordItemWithName(obj) toPath:GetLocalOnePasswordItemWithName(obj) error:nil];
							if (copyResult) {
								[self updateSyncingProcessToFile:obj forSyncState:kMerge];
								[self.delegate syncItemNumber:syncItem ofTotal:syncItemsCount];
							}
						}
					}
					break;
				};
				case NSOrderedSame: {
					syncItem++;
					[self.delegate syncItemNumber:syncItem ofTotal:syncItemsCount];
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
					if (copyResult) {
						[self updateSyncingProcessToFile:@"contents.js" forSyncState:kContents];
						syncItem++;
						[self.delegate syncItemNumber:syncItem ofTotal:syncItemsCount];
					}
				} else {
					// throw error
					[NSAlert connectionErrorWithDevice:[device deviceName]];
				}
				[contentsToDevice close];
			}
			[contentsToDevice release];
		}
		
		[self.delegate syncItemNumber:100 ofTotal:100];
		
		[self finishSyncingProcess];
		
		[newContents release];
		[addToLocal release];
		[addToDevice release];
		[matches release];
	}
}

- (void)cleanUpMergeData {
	[[NSFileManager defaultManager] removeItemAtPath:mergeKeychainPath error:nil];
}

- (void)synchronizePasswords {
	BOOL okToSync = TRUE;
	if (deviceSyncError) {
		okToSync = FALSE;
		// check for device files and local files
		if ([NSAlert previousSyncError] == NSAlertSecondButtonReturn) {
			if ([self deviceSyncStateFileExistsLocally]) {
				// if it is a sync that happened here
				
				// try to resume from last attempt
				
				// ask if they want to roll back then roll forward
				
			} else {
				// if it is a sync that happened on another computer
				
				// ask if they want to rollback instead
			}
		}
	}
	if (okToSync) {
		BOOL result = [self keychainChecks];
		if (result) {
			result = [self checkForSyncPossible];
			if (result) {
				[self loadContentsData];
				[self mergeLocalAndDeviceContents];
				[self cleanUpMergeData];
			} else {
				[NSAlert keychainMismatchError];
			}
		}	
	}	
}

#pragma mark -
#pragma mark Application Install

- (void)installOnePassword {
	BOOL directory;
	__block NSString *appsDir = MobileApplicationsDirectory(nil);
	BOOL okToInstall = (appsDir != nil ? TRUE : FALSE);
	if (!okToInstall) {
		NSInteger result = [NSAlert mobileApplicationsNotFound];
		if (result == 1000) {
			NSOpenPanel *libraryLocationPanel = [NSOpenPanel openPanel];
			[libraryLocationPanel setCanChooseFiles:YES];
			[libraryLocationPanel setCanChooseDirectories:NO];
			[libraryLocationPanel setAllowsMultipleSelection:NO];
			[libraryLocationPanel setResolvesAliases:YES];
			[libraryLocationPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"xml",nil]];
			[libraryLocationPanel setMessage:@"Please find and open the \"iTunes Music Library.xml\" file."];
			[libraryLocationPanel setTitle:@"Open iTunes Music Library.xml"];
			[libraryLocationPanel beginWithCompletionHandler:^(NSInteger result){
				if (result) {
					appsDir = MobileApplicationsDirectory([[[libraryLocationPanel URLs] objectAtIndex:0] path]);
				}
			}];
		}
	}
	
	okToInstall = (appsDir != nil ? TRUE : FALSE);
	
	if (okToInstall) {
		okToInstall = [[NSFileManager defaultManager] fileExistsAtPath:appsDir isDirectory:&directory];
		if (okToInstall && directory) {
			NSArray *allApplications = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appsDir error:nil];
			NSPredicate *onePasswordAppPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS %@",@"1Password 4"];
			NSArray *results = [allApplications filteredArrayUsingPredicate:onePasswordAppPredicate];
			okToInstall = (results.count ? TRUE : FALSE);

			if (okToInstall) {
				NSString *ipaPath = [appsDir stringByAppendingPathComponent:[results objectAtIndex:0]];
				okToInstall = [[NSFileManager defaultManager] copyItemAtPath:ipaPath toPath:[kSMOPInstallPath stringByAppendingPathComponent:[ipaPath lastPathComponent]] error:nil];
				
				if (okToInstall) {
					NSString *zipFilePath = [kSMOPInstallPath stringByAppendingPathComponent:[ipaPath lastPathComponent]];
					NSString *output = [kSMOPInstallPath stringByAppendingPathComponent:@"extracted"];
					ZipArchive* za = [[ZipArchive alloc] init];
					if ([za UnzipOpenFile:zipFilePath]) {
						okToInstall = [za UnzipFileTo:output overWrite:YES];
						[za UnzipCloseFile];
					}
					[za release];	
				}
				
				if (okToInstall) {
					NSDictionary *appMetaData = [NSDictionary dictionaryWithContentsOfFile:[kSMOPInstallPath stringByAppendingPathComponent:@"/extracted/iTunesMetadata.plist"]];

					okToInstall = ([[appMetaData objectForKey:@"softwareVersionBundleId"] isEqualToString:kOnePasswordBundleId]);

					if (okToInstall) {
						NSString *onePasswordAppPath = [kSMOPInstallPath stringByAppendingPathComponent:@"/extracted/Payload/1Password.app"];
						CFStringRef installPath = CFStringCreateWithCString(NULL, [onePasswordAppPath UTF8String], kCFStringEncodingASCII);
						BOOL result = InstallAppToDevice(installPath, (struct am_device *)device.device, transfer_callback, install_callback);
						if (result) {
							[self.delegate syncItemNumber:100 ofTotal:100];
						} else {
							[NSAlert appInstallationFailure];
						}
						CFRelease(installPath);
						
						[self synchronizePasswords];
					}
				} else {
					// failed to extract
				}	
				[[NSFileManager defaultManager] removeItemAtPath:kSMOPInstallPath error:nil];
				[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPInstallPath withIntermediateDirectories:YES attributes:nil error:nil];
			} else {
				// couldn't find 1Password 4.ipa
				[NSAlert ipaNotFound];
			}
		}
	}
}

@end