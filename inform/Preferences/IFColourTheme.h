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
- (void) updateAppPreferencesFromSetWithEnable: (BOOL) enable;
- (void) updateSetFromAppPreferences;
- (IFSyntaxColouringOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
@property (nonatomic, getter=isEqualToDefault, readonly) BOOL equalToDefault;
-(void) resetSettings;
-(IFColourTheme*) createDuplicateSet;

@end

NS_ASSUME_NONNULL_END
