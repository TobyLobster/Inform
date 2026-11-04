//
//  IFSyntaxManager.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFSyntaxData.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Manages NSTextStorage objects registered
///
@interface IFSyntaxManager : NSObject

//
// Registration
//
+(void) registerTextStorage: (NSTextStorage*) storage
                       name: (NSString*) name
                       type: (IFHighlightType) type
               intelligence: (nullable id<IFSyntaxIntelligence>) intelligence
                undoManager: (nullable NSUndoManager*) undoManager;
+(void) registerTextStorage: (NSTextStorage*) storage
                   filename: (NSString*) filename
               intelligence: (nullable id<IFSyntaxIntelligence>) intelligence
                undoManager: (nullable NSUndoManager*) undoManager;

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
                     intelligence: (nullable id<IFSyntaxIntelligence>) intelligence;
+(nullable IFIntelFile*) intelligenceDataForStorage: (NSTextStorage*) storage;

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
+(nullable NSTextStorage*) restrictedTextStorage: (NSTextStorage*) storage
                            forTextView: (NSTextView*) view;

//
// Renumbering sections
//
+(nullable NSString*) textForLineWithStorage: (NSTextStorage*) storage
                         lineNumber: (int) line;
+(void) replaceLineWithStorage: (NSTextStorage*) storage
                    lineNumber: (int) lineNumber
                      withLine: (NSString*) line;

//
// Internal
//
+(nullable IFSyntaxData*) dataForStorage:(NSTextStorage*) storage;

@end

NS_ASSUME_NONNULL_END
