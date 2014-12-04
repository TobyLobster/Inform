//
//  IFProjectPolicy.h
//  Inform
//
//  Created by Andrew Hunter on 04/09/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFProjectController;
@interface IFProjectPolicy : NSObject {
	IFProjectController* projectController;
	BOOL redirectToDocs;
	BOOL redirectToExtensionDocs;
}

// Bug workaround
+ (NSURL*) fileURLWithPath: (NSString*) path;

// Initialisation
- (id) initWithProjectController: (IFProjectController*) pane;

// Setting up
- (void)				 setProjectController: (IFProjectController*) controller;
- (IFProjectController*) projectController;

- (void)				 setRedirectToDocs: (BOOL) redirect;
- (BOOL)				 redirectToDocs;

- (void)				 setRedirectToExtensionDocs: (BOOL) redirect;
- (BOOL)				 redirectToExtensionDocs;

// Replace the "library:" prefix of the URL string with the URL for the enclosing document
+(NSURL*) urlFromLibraryURL: (NSURL*) url
                   frameURL: (NSURL*) frameURL;
@end

#import "IFProjectController.h"
