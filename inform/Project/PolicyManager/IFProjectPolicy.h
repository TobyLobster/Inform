//
//  IFProjectPolicy.h
//  Inform
//
//  Created by Andrew Hunter on 04/09/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFProjectController;

@interface IFProjectPolicy : NSObject<WebPolicyDelegate>

// Initialisation
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithProjectController: (IFProjectController*) pane NS_DESIGNATED_INITIALIZER;

// Setting up
@property (atomic, strong) IFProjectController *  projectController;
@property (atomic)         BOOL                   redirectToDocs;
@property (atomic)         BOOL                   redirectToExtensionDocs;

// Replace the "library:" prefix of the URL string with the URL for the enclosing document
+(NSURL*) urlFromLibraryURL: (NSURL*) url
                   frameURL: (NSURL*) frameURL;
@end
