//
//  JSMNParser.m
//  SM1Password Sync
//
//  Created by sam on 3/20/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "JSMNParser.h"


@implementation JSMNParser

- (id)initWithPath:(NSString *)path tokenCount:(NSInteger)total {
	self = [super init];
	tokens = (jsmntok_t *)malloc(sizeof(jsmntok_t)*total);
	if (self) {
		count = total;
		offset = 0;
		jsonData = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];		
		jsmn_parser localParser;
		jsmn_init(&localParser);
		jsmn_parse(&localParser, [jsonData cStringUsingEncoding:NSUnicodeStringEncoding], tokens, total);
	}
	return self;
}

- (id)deserializeJSON {	
	return [self parseFromIndex:0];
}

- (id)parseFromIndex:(NSInteger)index {
	id parsed = nil;
	switch (tokens[index].type) {
		case JSMN_PRIMITIVE: {
			NSInteger length = tokens[index].end-tokens[index].start;
			NSString *valueString = [jsonData substringWithRange:NSMakeRange(tokens[index].start,length)];
			if (length == 1) {
				if ([valueString isEqualToString:@"Y"] || [valueString isEqualToString:@"N"]) {
					parsed = valueString;
					break;
				}
			}
			NSNumberFormatter *stringFormatter = [[NSNumberFormatter alloc] init];
			[stringFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			parsed = [stringFormatter numberFromString:valueString];
			[stringFormatter release];
			break;
		};
		case JSMN_OBJECT: {
			if (tokens[index].size%2 == 0) {
				parsed = [NSMutableDictionary dictionaryWithCapacity:tokens[index].size/2];
				for (uint32_t i = 0; i < tokens[index].size; i+=2) {
					[parsed setObject:[self parseFromIndex:index+1+i] forKey:[self parseFromIndex:index+2+i]];
				}
			}
			//if (tokens[index].start)
			//	offset = tokens[index].size;
			break;
		};
		case JSMN_ARRAY: {
			parsed = [[NSMutableArray new] autorelease];
			for (uint32_t i = 0; i < tokens[index].size; i++) {
				offset++;
				[parsed addObject:[self parseFromIndex:offset]];
				offset = offset + tokens[offset].size;
			}
			break;
		};
		case JSMN_STRING: {
			if (tokens[index].end-tokens[index].start) {
				parsed = [jsonData substringWithRange:NSMakeRange(tokens[index].start,tokens[index].end-tokens[index].start)];
			} else {
				parsed = @"";
			}
			break;
		};
		default: {
			break;
		};
	}
	return parsed;
}

- (void)dealloc {
	[jsonData release];
	free(tokens);
	[super dealloc];
}

@end
