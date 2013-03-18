/*
 *  SMOPFunctions.h
 *  SM1Password Sync
 *
 *  Created by sam on 3/18/13.
 *  Copyright 2013 Sam Marshall. All rights reserved.
 *
 */

#import <CommonCrypto/CommonDigest.h>

CFDataRef SHA1HashOfFileAtPath(NSString *path) {
	unsigned char hashBytes[CC_SHA1_DIGEST_LENGTH];
	NSData *fileData = [NSData dataWithContentsOfFile:path];
    CC_SHA1([fileData bytes], [fileData length], hashBytes);
    return (CFDataRef)[NSData dataWithBytes:hashBytes length:CC_SHA1_DIGEST_LENGTH];
}

