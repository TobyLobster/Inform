//
//  IFColourTheme.h
//  Inform
//
//  Created by Toby Nelson in 2022
//

#import <Cocoa/Cocoa.h>

#import "IFPreferences.h"

@interface IFColourTheme : NSObject<NSSecureCoding>

@property (atomic) NSNumber*                        flags;
@property (atomic, copy) NSString*                  themeName;
@property (atomic, copy) IFSyntaxColouringOption*   sourcePaper;
@property (atomic, copy) IFSyntaxColouringOption*   extensionPaper;

/// Array of IFSyntaxColouringOptions
@property (atomic, strong) NSMutableArray<IFSyntaxColouringOption*>* options;

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (void) updateAppPreferencesFromSetWithEnable: (BOOL) enable;
- (void) updateSetFromAppPreferences;
- (IFSyntaxColouringOption*) optionOfType:(IFSyntaxHighlightingOptionType) type;
@property (NS_NONATOMIC_IOSONLY, getter=isEqualToDefault, readonly) BOOL equalToDefault;
-(BOOL) isEqual:(id)object;
-(void) resetSettings;
-(IFColourTheme*) createDuplicateSet;

@end
