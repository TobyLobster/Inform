//
//  ZoomPlugInInfo.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <ZoomPlugIns/ZoomPlugInInfo.h>
#import "ZoomPlugInManager.h"


@implementation ZoomPlugInInfo

#pragma mark - Initialisation

- (id) initWithBundleFilename: (NSString*) bundle {
	NSDictionary* plist = [[ZoomPlugInManager sharedPlugInManager] plistForBundleAtPath: bundle];

	// No information available if there's no plist for this bundle
	if (plist == nil) {
		self = [super init];
		return nil;
	}
	
	self = [self initFromPList: [plist objectForKey: @"ZoomPlugin"]];
	
	if (self) {
		// Get the information out of the plist
		NSString *imagePath = [[plist objectForKey: @"ZoomPlugin"] objectForKey: @"Image"];
		if (imagePath) {
			// trim and clean-up!
			NSString *tmpImgName = [imagePath.lastPathComponent stringByDeletingPathExtension];
			NSImage *tmpImage = [[NSBundle bundleWithPath:bundle] imageForResource:tmpImgName];
			if (!tmpImage) {
				tmpImage = [NSImage imageNamed:tmpImgName];
			}
			if (!tmpImage) {
				tmpImage = [[NSBundle mainBundle] imageForResource:tmpImgName];
			}
			if (tmpImage) {
				image = tmpImage;
			}
		}
		
		if (imagePath != nil && image == nil) {
			imagePath = [[bundle stringByAppendingPathComponent: imagePath] stringByStandardizingPath];
			image = [[NSImage alloc] initWithContentsOfFile:imagePath];
		}
		
		if (!image) {
			image = [NSImage imageNamed: @"zoom-app"];
		}
		
		// Work out the status (installed or downloaded as we're working from a path)
		NSString* standardPath = [bundle stringByStandardizingPath];
		NSString* mainBundlePath = [[[NSBundle mainBundle] bundlePath] stringByStandardizingPath];
		
		if ([mainBundlePath characterAtIndex: [mainBundlePath length]-1] != '/') {
			mainBundlePath = [mainBundlePath stringByAppendingString: @"/"];
		}
		
		if ([standardPath hasPrefix: mainBundlePath] || [standardPath hasPrefix: [ZoomPlugInManager plugInsPath]]) {
			status = ZoomPlugInInstalled;
		} else {
			status = ZoomPlugInDownloaded;
		}
		
		location = [NSURL fileURLWithPath: bundle];
	}
	
	return self;
}

static unsigned int ValueForHexChar(int hex) {
	if (hex >= '0' && hex <= '9') return hex - '0';
	if (hex >= 'a' && hex <= 'f') return hex - 'a' + 10;
	if (hex >= 'A' && hex <= 'F') return hex - 'A' + 10;
	return 0;
}

- (id) initFromPList: (NSDictionary*) plist {
	self = [super init];
	
	if (self) {
		// No information available if there's no plist for this bundle
		if (plist == nil) {
			return nil;
		}
		
		// Get the information out of the plist
		name				= [plist objectForKey: @"DisplayName"];
		author				= [plist objectForKey: @"Author"];
		interpreterAuthor	= [plist objectForKey: @"InterpreterAuthor"];
		interpreterVersion	= [plist objectForKey: @"InterpreterVersion"];
		version				= [plist objectForKey: @"Version"];
		image				= nil;
		status				= ZoomPlugInNotKnown;
		
		if ([plist objectForKey: @"URL"] != nil) {
			location = [[NSURL URLWithString: [plist objectForKey: @"URL"]] copy];			
		}
		
		// Get the MD5 value if it exists
		id md5raw = [plist objectForKey: @"MD5"];
		
		if ([md5raw isKindOfClass: [NSData class]]) {
			// Just use data values directly
			md5 = [md5raw copy];
		} else if ([md5raw isKindOfClass: [NSString class]]) {
			// Build a digest from string values
			unsigned char digest[16];
			int x;
			for (x=0; x<16; x++) {
				int pos = x*2;
				if (pos+1 >= [md5raw length]) break;
				
				unichar firstChar = [md5raw characterAtIndex: pos];
				unichar secondChar = [md5raw characterAtIndex: pos+1];
				
				digest[x] = (ValueForHexChar(firstChar)<<4)|ValueForHexChar(secondChar);
			}
			
			md5 = [[NSData alloc] initWithBytes: digest
										 length: 16];
		}
		
		if ([plist objectForKey: @"UpdateURL"] != nil) {
			updateUrl = [[NSURL URLWithString: [plist objectForKey: @"UpdateURL"]] copy];
		}
		
		// Check the plist entries
		if (name == nil) {
			return nil;
		}
		if (author == nil) {
			if (interpreterAuthor == nil) {
				return nil;
			}
			author = interpreterAuthor;
		}
		if (interpreterAuthor == nil) {
			interpreterAuthor = author;
		}
		if (version == nil || interpreterVersion == nil) {
			return nil;
		}
	}
	
	return self;	
}

#pragma mark - Copying

- (id) copyWithZone: (NSZone*) zone {
	ZoomPlugInInfo* newInfo = [[ZoomPlugInInfo alloc] init];
	
	newInfo->name 				= [name copy];
	newInfo->author 			= [author copy];
	newInfo->interpreterVersion	= [interpreterVersion copy];
	newInfo->interpreterAuthor 	= [interpreterAuthor copy];
	newInfo->version 			= [version copy];
	newInfo->image 				= [image copy];
	newInfo->location 			= [location copy];
	newInfo->md5 				= [md5 copy];
	newInfo->status 			= status;
	newInfo->updated 			= [updated copy];
	newInfo->updateUrl 			= [updateUrl copy];
	
	return newInfo;
}

#pragma mark - Retrieving the information

@synthesize name;
@synthesize author;
@synthesize version;
@synthesize interpreterAuthor;
@synthesize interpreterVersion;
@synthesize status;

- (NSString*) description {
	return [NSString stringWithFormat: @"Plug in: %@, version %@", [self name], [self version]];
}

@synthesize location;
@synthesize updateInfo = updated;
@synthesize download = updateDownload;
@synthesize md5;
@synthesize updateUrl;
@synthesize image;

@end
