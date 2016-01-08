//
//  IFPolicyManager.m
//  Inform
//
//  Created by Toby Nelson 2015
//

#import <WebKit/WebKit.h>

#import "IFPolicyManager.h"
#import "IFProjectPolicy.h"

@implementation IFPolicyManager

-(instancetype) init { self = [super init]; return self; }

-(instancetype) initWithProjectController:(IFProjectController *) projectController {
    self = [super init];

    if( self ) {
        _generalPolicy    = [[IFProjectPolicy alloc] initWithProjectController: projectController];

        _docPolicy        = [[IFProjectPolicy alloc] initWithProjectController: projectController];
        [_docPolicy setRedirectToDocs: YES];
        [_docPolicy setRedirectToExtensionDocs: NO];

        _extensionsPolicy = [[IFProjectPolicy alloc] initWithProjectController: projectController];
        [_extensionsPolicy setRedirectToDocs: NO];
        [_extensionsPolicy setRedirectToExtensionDocs: YES];
    }
    return self;
}

@end
