//
//  IFSyntaxManager.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxData.h"

//
// Manages NSTextStorage objects registered
//
@interface IFSyntaxManager : NSObject {
}

//
// Registration
//
+(void) registerTextStorage: (NSTextStorage*) storage
                       name: (NSString*) name
                       type: (IFHighlightType) type
               intelligence: (id<IFSyntaxIntelligence,NSObject>) intelligence
                undoManager: (NSUndoManager*) undoManager;
+(void) registerTextStorage: (NSTextStorage*) storage
                   filename: (NSString*) filename
               intelligence: (id<IFSyntaxIntelligence,NSObject>) intelligence
                undoManager: (NSUndoManager*) undoManager;

+(void) unregisterTextStorage: (NSTextStorage*) storage;
+(bool) isRegistered: (NSTextStorage*) storage;

//
// Syntax Highlighting
//
+(void) highlightAll: (NSTextStorage*) storage
     forceUpdateTabs: (bool) forceUpdateTabs;
+(void) preferencesChanged: (NSTextStorage*) storage;

//
// Intelligence
//
+(void) setIntelligenceForStorage: (NSTextStorage*) storage
                     intelligence: (id<IFSyntaxIntelligence,NSObject>) intelligence;
+(IFIntelFile*) intelligenceDataForStorage: (NSTextStorage*) storage;

//
// Restricted Storage
//
+(void) restrictStorage: (NSTextStorage*) storage
                  range: (NSRange) range
            forTextView: (NSTextView*) view;
+(void) removeRestriction: (NSTextStorage*) storage
              forTextView: (NSTextView*) view;
+(bool) isRestricted: (NSTextStorage*) storage
         forTextView: (NSTextView*) view;
+(NSRange) restrictedRange: (NSTextStorage*) storage
               forTextView: (NSTextView*) view;
+(NSTextStorage*) restrictedTextStorage: (NSTextStorage*) storage
                            forTextView: (NSTextView*) view;

//
// Renumbering sections
//
+(NSString*) textForLineWithStorage: (NSTextStorage*) storage
                         lineNumber: (int) line;
+(void) replaceLineWithStorage: (NSTextStorage*) storage
                    lineNumber: (int) lineNumber
                      withLine: (NSString*) line;

//
// Internal
//
+(IFSyntaxData*) dataForStorage:(NSTextStorage*) storage;

@end
