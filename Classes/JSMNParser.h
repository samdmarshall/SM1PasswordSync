//
//  JSMNParser.h
//  SM1Password Sync
//
//  Created by sam on 3/20/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "jsmn.h"

enum JSMNParserType {
	kJSMNParserContentsType = 0,
	kJSMNParserItemType = 1
};

@interface JSMNParser : NSObject {
	jsmntok_t *tokens;
	uint32_t count;
	NSString *jsonData;
	uint32_t offset;
	BOOL contentsParse;
}
+ (NSUInteger)tokenCountForObject:(id)obj;
+ (NSString *)serializeJSON:(id)obj;

- (id)initWithPath:(NSString *)path tokenCount:(NSInteger)total;
- (id)deserializeJSON;
- (id)deserializeContents;
- (id)parseFromIndex:(NSInteger)index;

@end
