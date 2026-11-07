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

@property (atomic) NSNumber*                                  flags;
@property (atomic, copy, nullable) NSString*                  themeName;          // nil until it's set
@property (atomic, copy, nullable) IFSyntaxColouringOption*   sourcePaper;        // likewise
@property (atomic, copy, nullable) IFSyntaxColouringOption*   extensionPaper;     // likewise

/// Array of IFSyntaxColouringOptions
@property (atomic, strong) NSMutableArray<IFSyntaxColouringOption*>* options;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (void) updateAppPreferencesFromSetWithEnable: (BOOL) enable;
- (void) updateSetFromAppPreferences;
- (IFSyntaxColouringOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
@property (NS_NONATOMIC_IOSONLY, getter=isEqualToDefault, readonly) BOOL equalToDefault;
-(void) resetSettings;
-(IFColourTheme*) createDuplicateSet;

@end

NS_ASSUME_NONNULL_END
