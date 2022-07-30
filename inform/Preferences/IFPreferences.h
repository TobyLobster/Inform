//
//  IFPreferences.h
//  Inform
//
//  Created by Andrew Hunter on 02/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Notifications
extern NSString* const IFPreferencesAuthorDidChangeNotification;
extern NSString* const IFPreferencesEditingDidChangeNotification;
extern NSString* const IFPreferencesAdvancedDidChangeNotification;
extern NSString* const IFPreferencesAppFontSizeDidChangeNotification;	// Change to app font size
extern NSString* const IFPreferencesSkeinDidChangeNotification;

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

@property (atomic, copy) NSColor*       colour;
@property (atomic, copy) NSColor*       defaultColour;

-(instancetype) initWithColour:(NSColor*) defaultColour NS_DESIGNATED_INITIALIZER;
- (id)copyWithZone:(NSZone *)zone;

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
+ (IFPreferences*) sharedPreferences;
@property (class, atomic, readonly, strong) IFPreferences *sharedPreferences;

// Preferences
/// Generates a notification that preferences have changed
- (void) preferencesHaveChanged;

-(void) startBatchEditing;
-(void) endBatchEditing;

// Editing preferences
@property (atomic, copy) NSString *sourceFontFamily;
@property (atomic) CGFloat sourceFontSize;
@property (atomic, readonly) CGFloat appFontSizeMultiplier;
@property (atomic) IFAppFontSize appFontSizeMultiplierEnum;
@property (atomic) CGFloat tabWidth;

-(IFColourTheme*) getCurrentTheme;
-(NSString*) getCurrentThemeName;
-(void) setCurrentThemeName: (NSString*) value;

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
-(NSArray*) getThemeNames;
-(bool) addTheme: (IFColourTheme*) theme;
-(bool) removeTheme: (NSString*) themeName;

-(void) setDarkMode: (bool) isDarkMode;

-(void) setSourcePaper: (IFSyntaxColouringOption*) option;
-(void) setExtensionPaper: (IFSyntaxColouringOption*) option;
-(IFSyntaxColouringOption*) getSourcePaper;
-(IFSyntaxColouringOption*) getExtensionPaper;

-(IFSyntaxColouringOption*) sourcePaperForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceColour: (NSColor*) colour
          forOptionType: (IFSyntaxHighlightingOptionType) optionType;

/// Regenerate the array of attribute dictionaries that make up the styles
- (void) recalculateStyles;
/// Retrieves an array of attribute dictionaries that describe how the styles should be displayed
@property (atomic, readonly, copy) NSArray *styles;

// Intelligence preferences
@property (atomic) BOOL enableSyntaxHighlighting;		// YES if source code should be displayed with syntax highlighting
@property (atomic) BOOL enableSyntaxColouring;          // YES if source code should be displayed with syntax colouring
@property (atomic) BOOL indentWrappedLines;				// ... and indentation (no longer used)
@property (atomic) BOOL elasticTabs;					// ... and elastic tabs
@property (atomic) BOOL indentAfterNewline;				// ... which is used to generate indentation
@property (atomic) BOOL autoNumberSections;				// ... which is used to auto-type section numbers
@property (atomic, copy) NSString *freshGameAuthorName;	// The default author to use for new Inform 7 games

// Advanced preferences
/// \c YES if we should run the build.sh shell script to rebuild Inform 7
@property (atomic) BOOL runBuildSh;
/// \c YES if we should always compile the source (no make-style dependency checking)
@property (atomic) BOOL alwaysCompile;
/// \c YES if we should show the Inform 7 debugging logs + generated Inform 6 source code
@property (atomic) BOOL showDebuggingLogs;
/// \c YES if we want to see the console output during a build
@property (atomic) BOOL showConsoleDuringBuilds;
/// \c YES if we want to debug the public library
@property (atomic) BOOL publicLibraryDebug;
/// \c YES if we should clean the project when we close it (or when saving)
@property (atomic) BOOL cleanProjectOnClose;
/// \c YES if we should additionally clean out the index files
@property (atomic) BOOL alsoCleanIndexFiles;
/// The preferred glulx interpreter
@property (atomic, copy) NSString *glulxInterpreter;


/// Position of preferences window
@property (atomic) NSPoint preferencesTopLeftPosition;

@end
