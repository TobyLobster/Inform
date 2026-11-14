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

NS_ASSUME_NONNULL_BEGIN

///
/// WKWebView category that implements the find controller delegate functions
///
@interface WKWebView(IFFindWebView) <IFFindDelegate>

/// Selects a match that Find in Files found in the page, and scrolls it into view. The match is found with its
/// context, the line of the searched text that it's in, after the element with the anchor given, or anywhere in the
/// page; failing that, the first of the match's text after the anchor is selected. The text is compared without its
/// whitespace, which the search's text has where the page's tags were. The handler is told whether it was selected.
- (void) selectMatchAtRange: (NSRange) range
                  inContext: (NSString*) context
                afterAnchor: (nullable NSString*) anchor
          completionHandler: (nullable void (NS_SWIFT_UI_ACTOR ^)(bool selected)) completionHandler;

@end

NS_ASSUME_NONNULL_END
