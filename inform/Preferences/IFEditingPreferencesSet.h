//
//  IFEditingPreferencesSet.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFPreferences.h"

@interface IFSyntaxHighlightingOption : NSObject

@property (atomic) IFFontStyle          fontStyle;
@property (atomic) bool                 underline;
@property (atomic) IFRelativeFontSize   relativeFontSize;

-(instancetype) init NS_DESIGNATED_INITIALIZER;

@end

@interface IFEditingPreferencesSet : NSObject

@property (atomic) bool                 enableSyntaxHighlighting;
@property (atomic, copy) NSString*      fontFamily;
@property (atomic) int                  fontSize;

/// Array of IFSyntaxHighlightingOptions
@property (atomic, strong) NSMutableArray<IFSyntaxHighlightingOption*>* options;

@property (atomic) CGFloat              tabWidth;
@property (atomic) bool                 autoIndentAfterNewline;
@property (atomic) bool                 autoSpaceTableColumns;
@property (atomic) bool                 autoNumberSections;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (void) updateAppPreferencesFromSet;
- (void) updateSetFromAppPreferences;
- (IFSyntaxHighlightingOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
-(BOOL) isEqualToPreferenceSet:(IFEditingPreferencesSet*) set;
-(BOOL) isEqual:(id)object;
-(void) resetSettings;

@end
