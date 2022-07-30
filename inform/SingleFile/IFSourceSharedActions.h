//
//  IFSourceSharedActions.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

@interface IFSourceSharedActions : NSObject

// Menu options
- (void) shiftLeftTextViewInDocument: (NSDocument*) document
                            textView: (NSTextView*) textView;
- (void) shiftRightTextViewInDocument: (NSDocument*) document
                             textView: (NSTextView*) textView;
- (void) renumberSectionsInDocument: (NSDocument*) document
                           textView: (NSTextView*) textView;
- (void) commentOutSelectionInDocument: (NSDocument*) document
                              textView: (NSTextView*) textView;
- (void) uncommentSelectionInDocument: (NSDocument*) document
                             textView: (NSTextView*) textView;

@end
