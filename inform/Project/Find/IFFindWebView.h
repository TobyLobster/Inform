//
//  IFFindWebView.h
//  Inform
//
//  Created by Andrew Hunter on 23/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "IFFindController.h"

///
/// WKWebView category that implements the find controller delegate functions
///
@interface WKWebView(IFFindWebView) <IFFindDelegate>

- (void) findNextMatch: (NSString*) match
                ofType: (IFFindType) type
     completionHandler: (void (^)(bool result))completionHandler;

- (void) findPreviousMatch: (NSString*) match
                    ofType: (IFFindType) type
         completionHandler: (void (^)(bool result))completionHandler;

@end
