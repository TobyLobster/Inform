//
//  IFEditingPreferencesSet.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFPreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFSyntaxHighlightingOption : NSObject

@property (nonatomic) IFFontStyle          fontStyle;
@property (nonatomic) bool                 underline;
@property (nonatomic) IFRelativeFontSize   relativeFontSize;

-(instancetype) init NS_DESIGNATED_INITIALIZER;

@end

NS_SWIFT_UI_ACTOR
@interface IFEditingPreferencesSet : NSObject

@property (nonatomic) bool                 enableSyntaxHighlighting;
@property (nonatomic, copy) NSString*      fontFamily;
@property (nonatomic) int                  fontSize;

/// One option for each type, in order
@property (nonatomic, copy) NSArray<IFSyntaxHighlightingOption*>* options;

@property (nonatomic) CGFloat              tabWidth;
@property (nonatomic) bool                 autoIndentAfterNewline;
@property (nonatomic) bool                 autoSpaceTableColumns;
@property (nonatomic) bool                 autoNumberSections;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
/// Copies the set to the editing preferences given
- (void) updatePreferences: (IFPreferences*) preferences;
/// Copies the editing preferences given to the set
- (void) updateSetFromPreferences: (IFPreferences*) preferences NS_SWIFT_NAME(updateSet(from:));
- (IFSyntaxHighlightingOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
-(BOOL) isEqualToPreferenceSet:(IFEditingPreferencesSet*) set;
-(void) resetSettings;

@end

NS_ASSUME_NONNULL_END
