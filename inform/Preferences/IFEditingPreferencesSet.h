//
//  IFEditingPreferencesSet.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFPreferences.h"

@interface IFSyntaxHighlightingOption : NSObject

@property (atomic, strong) NSColor*     colour;
@property (atomic) IFFontStyle          fontStyle;
@property (atomic) bool                 underline;
@property (atomic) IFRelativeFontSize   relativeFontSize;

-(instancetype) init NS_DESIGNATED_INITIALIZER;

@end

@interface IFEditingPreferencesSet : NSObject

@property (atomic, strong) NSString*    fontFamily;
@property (atomic) int                  fontSize;
@property (atomic, strong) NSColor*     sourcePaperColor;
@property (atomic, strong) NSColor*     extensionPaperColor;
@property (atomic) bool                 enableSyntaxHighlighting;
@property (atomic, strong) NSMutableArray<IFSyntaxHighlightingOption*>*      options;            // Array of IFSyntaxHighlightingOptions
@property (atomic) CGFloat              tabWidth;
@property (atomic) bool                 indentWrappedLines;
@property (atomic) bool                 autoIndentAfterNewline;
@property (atomic) bool                 autoSpaceTableColumns;
@property (atomic) bool                 autoNumberSections;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (void) updateAppPreferencesFromSet;
- (void) updateSetFromAppPreferences;
- (IFSyntaxHighlightingOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
-(BOOL) isEqualToEditingPreferenceSet:(IFEditingPreferencesSet*) set;
-(BOOL) isEqual:(id)object;

@end
