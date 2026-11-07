//
//  IFPreferences.h
//  Inform
//
//  Created by Andrew Hunter on 02/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// Notifications
extern NSString* const IFPreferencesAuthorDidChangeNotification;
extern NSString* const IFPreferencesEditingDidChangeNotification;
extern NSString* const IFPreferencesAdvancedDidChangeNotification;
extern NSString* const IFPreferencesAppFontSizeDidChangeNotification;	// Change to app font size

extern NSString* const IFPreferencesDefault;
typedef NS_ENUM(int, IFAppFontSize) {
    IFAppFontSizeMinus100,
    IFAppFontSizeMinus75,
    IFAppFontSizeMinus50,
    IFAppFontSizeMinus25,
    IFAppFontSizeNormal,
    IFAppFontSizePlus25,
    IFAppFontSizePlus50,
    IFAppFontSizePlus75,
    IFAppFontSizePlus100,
};

// Types
typedef NS_ENUM(int, IFRelativeFontSize) {
    IFFontSizeMinus30,
    IFFontSizeMinus20,
    IFFontSizeMinus10,
    IFFontSizeNormal,
    IFFontSizePlus10,
    IFFontSizePlus20,
    IFFontSizePlus30,
};

typedef NS_ENUM(int, IFSyntaxHighlightingOptionType) {
    IFSHOptionHeadings NS_SWIFT_NAME(headings),
    IFSHOptionMainText NS_SWIFT_NAME(mainText),
    IFSHOptionComments NS_SWIFT_NAME(comments),
    IFSHOptionQuotedText NS_SWIFT_NAME(quotedText),
    IFSHOptionTextSubstitutions NS_SWIFT_NAME(textSubstitutions),
    
    IFSHOptionCount NS_SWIFT_NAME(count)
};

typedef NS_ENUM(UInt32, IFFontStyle) {
    IFFontStyleRegular,
    IFFontStyleItalic,
    IFFontStyleBold,
    IFFontStyleBoldItalic,
};

@interface IFSyntaxColouringOption : NSObject<NSSecureCoding, NSCopying>

@property (nonatomic, copy) NSColor*    colour;
@property (nonatomic, copy) NSColor*    defaultColour;

-(instancetype) initWithColour:(NSColor*) defaultColour NS_DESIGNATED_INITIALIZER;
- (id)copyWithZone:(nullable NSZone *)zone;

@end


@class IFEditingPreferencesSet;
@class IFColourTheme;

///
/// General preferences class
///
/// Inform's application preferences are stored here
///
@interface IFPreferences : NSObject

// Constructing the object
/// The shared preference object
@property (class, nonatomic, readonly, strong) IFPreferences *sharedPreferences;

/// Preferences kept in the standard user defaults, as the shared ones are
- (instancetype) init;
/// Preferences kept in the given user defaults, under \c IFPreferencesDefault (the tests give their own)
- (instancetype) initWithUserDefaults: (NSUserDefaults*) userDefaults NS_DESIGNATED_INITIALIZER;

// Preferences
/// Generates a notification that preferences have changed
- (void) preferencesHaveChanged;

-(void) startBatchEditing;
-(void) endBatchEditing;

// Editing preferences
@property (nonatomic, copy) NSString *sourceFontFamily;
@property (nonatomic) CGFloat sourceFontSize;
@property (nonatomic, readonly) CGFloat appFontSizeMultiplier;
@property (nonatomic) IFAppFontSize appFontSizeMultiplierEnum;
@property (nonatomic) CGFloat tabWidth;

-(IFColourTheme*) getCurrentTheme;
@property (nonatomic, copy) NSString *currentThemeName;

-(IFFontStyle) sourceFontStyleForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceFontStyle: (IFFontStyle) style
             forOptionType: (IFSyntaxHighlightingOptionType) optionType;

-(IFRelativeFontSize) sourceRelativeFontSizeForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceRelativeFontSize: (IFRelativeFontSize) size
                    forOptionType: (IFSyntaxHighlightingOptionType) optionType;

-(BOOL) sourceUnderlineForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceUnderline: (BOOL) underline
             forOptionType: (IFSyntaxHighlightingOptionType) optionType;

-(bool) setCurrentTheme: (NSString*) name;
@property (nonatomic, readonly, copy) NSArray<NSString*> *themeNames;
-(bool) addTheme: (IFColourTheme*) theme;
-(bool) removeTheme: (NSString*) themeName;

-(void) setDarkMode: (bool) isDarkMode;

@property (nonatomic, copy) IFSyntaxColouringOption *sourcePaper;
@property (nonatomic, copy) IFSyntaxColouringOption *extensionPaper;

-(IFSyntaxColouringOption*) sourcePaperForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceColour: (NSColor*) colour
          forOptionType: (IFSyntaxHighlightingOptionType) optionType;

@property (nonatomic) BOOL useExternalInformCoreDirectory;
@property (nonatomic, copy) NSString *externalInformCoreDirectory;

/// Regenerate the array of attribute dictionaries that make up the styles
- (void) recalculateStyles;
/// Retrieves an array of attribute dictionaries that describe how the styles should be displayed
@property (nonatomic, readonly, copy) NSArray<NSDictionary<NSAttributedStringKey, id>*> *styles;

// Intelligence preferences
@property (nonatomic) BOOL enableSyntaxHighlighting;		// YES if source code should be displayed with syntax highlighting
@property (nonatomic) BOOL enableSyntaxColouring;          // YES if source code should be displayed with syntax colouring
@property (nonatomic) BOOL elasticTabs;					// ... and elastic tabs
@property (nonatomic) BOOL indentAfterNewline;				// ... which is used to generate indentation
@property (nonatomic) BOOL autoNumberSections;				// ... which is used to auto-type section numbers
/// The default author to use for new Inform 7 games (nil goes back to the user's own name)
@property (nonatomic, copy, null_resettable) NSString *freshGameAuthorName;

// Advanced preferences
/// \c YES if we should run the build.sh shell script to rebuild Inform 7
@property (nonatomic) BOOL runBuildSh;
/// \c YES if we should always compile the source (no make-style dependency checking)
@property (nonatomic) BOOL alwaysCompile;
/// \c YES if we should show the Inform 7 debugging logs + generated Inform 6 source code
@property (nonatomic) BOOL showDebuggingLogs;
/// \c YES if we want to see the console output during a build
@property (nonatomic) BOOL showConsoleDuringBuilds;
/// \c YES if we want to debug the public library
@property (nonatomic) BOOL publicLibraryDebug;
/// \c YES if we should clean the project when we close it (or when saving)
@property (nonatomic) BOOL cleanProjectOnClose;
/// \c YES if we should additionally clean out the index files
@property (nonatomic) BOOL alsoCleanIndexFiles;
/// The preferred glulx interpreter
@property (nonatomic, copy) NSString *glulxInterpreter;


/// Position of preferences window
@property (nonatomic) NSPoint preferencesTopLeftPosition;

@end

NS_ASSUME_NONNULL_END
