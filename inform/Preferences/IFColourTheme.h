//
//  IFColourTheme.h
//  Inform
//
//  Created by Toby Nelson in 2022
//

#import <Cocoa/Cocoa.h>

#import "IFPreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFColourTheme : NSObject<NSSecureCoding>

@property (nonatomic, nullable) NSNumber*                     flags;              // nil if it couldn't be read
@property (nonatomic, copy, nullable) NSString*               themeName;          // nil until it's set
@property (nonatomic, copy, nullable) IFSyntaxColouringOption* sourcePaper;       // likewise
@property (nonatomic, copy, nullable) IFSyntaxColouringOption* extensionPaper;    // likewise

/// One option for each type, in order (fewer, or none, if they couldn't all be read)
@property (nonatomic, copy) NSArray<IFSyntaxColouringOption*>* options;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
/// Copies the theme's colours, and whether to colour syntax, to the current theme of the preferences given
- (void) updatePreferences: (IFPreferences*) preferences fromSetWithEnable: (BOOL) enable;
/// Copies the colours of the current theme of the preferences given, and its flags, to the theme
- (void) updateSetFromPreferences: (IFPreferences*) preferences;
- (IFSyntaxColouringOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
@property (nonatomic, getter=isEqualToDefault, readonly) BOOL equalToDefault;
-(void) resetSettings;
-(IFColourTheme*) createDuplicateSet;

@end

NS_ASSUME_NONNULL_END
