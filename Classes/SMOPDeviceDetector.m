//
//  SMOPDeviceDetector.m
//  SM1Password Sync
//
//  Created by sam on 4/9/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPDeviceDetector.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOCFPlugIn.h>

@implementation SMOPDeviceDetector

+ (NSArray *)devicesSupportingIPhoneOS {
	NSMutableArray *devices = [NSMutableArray new];
	io_iterator_t iterator;
	mach_port_t masterPort;
	kern_return_t kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
	if (kr == kIOReturnSuccess && masterPort) {
		CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
		IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator);
		io_service_t usbDevice;
		while (usbDevice = IOIteratorNext(iterator)) {
			CFTypeRef supportsIPhoneOS = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("SupportsIPhoneOS"), kCFAllocatorDefault, kIORegistryIterateRecursively);
			if (supportsIPhoneOS) {
				CFTypeRef data = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("USB Serial Number"), kCFAllocatorDefault, kIORegistryIterateRecursively);
				[devices addObject:(NSString *)data];
			}
			IOObjectRelease(usbDevice);
		}
	} else {
		NSLog (@"Error: Couldn't create a master I/O Kit port(%08x)", kr);
	}
	mach_port_deallocate(mach_task_self(), masterPort);
	return devices;
}

@end
