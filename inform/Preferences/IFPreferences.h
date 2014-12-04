//
//  IFPreferences.h
//  Inform
//
//  Created by Andrew Hunter on 02/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFInspector.h"

// Notifications
extern NSString* IFPreferencesAuthorDidChangeNotification;
extern NSString* IFPreferencesEditingDidChangeNotification;
extern NSString* IFPreferencesAdvancedDidChangeNotification;
extern NSString* IFPreferencesAppFontSizeDidChangeNotification;	// Change to app font size
extern NSString* IFPreferencesSkeinDidChangeNotification;

extern NSString* IFPreferencesDefault;
typedef enum IFAppFontSize {
    IFAppFontSizeMinus100,
    IFAppFontSizeMinus75,
    IFAppFontSizeMinus50,
    IFAppFontSizeMinus25,
    IFAppFontSizeNormal,
    IFAppFontSizePlus25,
    IFAppFontSizePlus50,
    IFAppFontSizePlus75,
    IFAppFontSizePlus100,
} IFAppFontSize;

// Types
typedef enum IFRelativeFontSize {
    IFFontSizeMinus30,
    IFFontSizeMinus20,
    IFFontSizeMinus10,
    IFFontSizeNormal,
    IFFontSizePlus10,
    IFFontSizePlus20,
    IFFontSizePlus30,
} IFRelativeFontSize;

typedef enum IFSyntaxHighlightingOptionType {
    IFSHOptionHeadings,
    IFSHOptionMainText,
    IFSHOptionComments,
    IFSHOptionQuotedText,
    IFSHOptionTextSubstitutions,
    
    IFSHOptionCount
} IFSyntaxHighlightingOptionType;

typedef enum IFFontStyle {
    IFFontStyleRegular,
    IFFontStyleItalic,
    IFFontStyleBold,
    IFFontStyleBoldItalic,
} IFFontStyle;

@class IFEditingPreferencesSet;

//
// General preferences class
//
// Inform's application preferences are stored here
//
@interface IFPreferences : NSObject {
	// The preferences dictionary
	NSMutableDictionary* preferences;
	
	// Notification flag
    BOOL batchEditingPreferences;
    BOOL batchEditingDirty;
    NSMutableArray* batchNotificationTypes;
    NSString* notificationString;
	
	// Caches
	NSMutableDictionary* cacheFontSet;		// Maps 'font types' to fonts
	NSMutableArray* cacheFontStyles;		// Maps styles to fonts
	NSMutableArray* cacheColourSet;			// Choice of colours
	NSMutableArray* cacheColours;			// Maps styles to colours
	NSMutableArray* cacheUnderlines;		// Maps styles to underlines
	
	NSMutableArray* styles;					// The array of actual styles (array of attribute dictionaries)
    
    IFEditingPreferencesSet* defaultEditingPreferences;
}

// Constructing the object
+ (IFPreferences*) sharedPreferences;										// The shared preference object

// Preferences
- (void) preferencesHaveChanged;											// Generates a notification that preferences have changed

-(void) startBatchEditing;
-(void) endBatchEditing;

// Editing preferences
- (NSString*) sourceFontFamily;
- (float) sourceFontSize;
- (float) appFontSizeMultiplier;
- (IFAppFontSize) appFontSizeMultiplierEnum;
- (float) tabWidth;

- (void) setSourceFontFamily: (NSString*) fontFamily;
- (void) setSourceFontSize: (float) pointSize;
- (void) setAppFontSizeMultiplierEnum: (IFAppFontSize) appFontSize;
- (void) setTabWidth: (float) newTabWidth;

-(IFFontStyle) sourceFontStyleForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceFontStyle: (IFFontStyle) style
             forOptionType: (IFSyntaxHighlightingOptionType) optionType;

-(IFRelativeFontSize) sourceRelativeFontSizeForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceRelativeFontSize: (IFRelativeFontSize) size
                    forOptionType: (IFSyntaxHighlightingOptionType) optionType;

-(NSColor*) sourceColourForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceColour: (NSColor*) colour
          forOptionType: (IFSyntaxHighlightingOptionType) optionType;

-(BOOL) sourceUnderlineForOptionType:(IFSyntaxHighlightingOptionType) optionType;
-(void) setSourceUnderline: (BOOL) underline
             forOptionType: (IFSyntaxHighlightingOptionType) optionType;

- (void) recalculateStyles;													// Regenerate the array of attribute dictionaries that make up the styles
- (NSArray*) styles;														// Retrieves an array of attribute dictionaries that describe how the styles should be displayed

// Intelligence preferences
- (BOOL) enableSyntaxHighlighting;											// YES if source code should be displayed with syntax highlighting
- (BOOL) indentWrappedLines;												// ... and indentation
- (BOOL) elasticTabs;														// ... and elastic tabs
- (BOOL) indentAfterNewline;												// ... which is used to generate indentation
- (BOOL) autoNumberSections;												// ... which is used to auto-type section numbers
- (NSString*) freshGameAuthorName;											// The default author to use for new Inform 7 games

- (void) setEnableSyntaxHighlighting: (BOOL) value;
- (void) setIndentWrappedLines: (BOOL) value;
- (void) setElasticTabs: (BOOL) value;
- (void) setIndentAfterNewline: (BOOL) value;
- (void) setAutoNumberSections: (BOOL) value;
- (void) setFreshGameAuthorName: (NSString*) value;

-(NSColor*) sourcePaperColour;
-(void) setSourcePaperColour: (NSColor*) colour;
-(NSColor*) extensionPaperColour;
-(void) setExtensionPaperColour: (NSColor*) colour;

// Advanced preferences
- (BOOL) runBuildSh;														// YES if we should run the build.sh shell script to rebuild Inform 7
- (BOOL) showDebuggingLogs;													// YES if we should show the Inform 7 debugging logs + generated Inform 6 source code
- (BOOL) showConsoleDuringBuilds;                                           // YES if we want to see the console output during a build
- (BOOL) publicLibraryDebug;                                                // YES if we want to debug the public library
- (BOOL) cleanProjectOnClose;												// YES if we should clean the project when we close it (or when saving)
- (BOOL) alsoCleanIndexFiles;												// YES if we should additionally clean out the index files
- (NSString*) glulxInterpreter;												// The preferred glulx interpreter

- (void) setRunBuildSh: (BOOL) value;
- (void) setShowDebuggingLogs: (BOOL) value;
- (void) setShowConsoleDuringBuilds: (BOOL) value;
- (void) setPublicLibraryDebug: (BOOL) value;
- (void) setCleanProjectOnClose: (BOOL) value;
- (void) setAlsoCleanIndexFiles: (BOOL) value;
- (void) setGlulxInterpreter: (NSString*) value;

// Position of preferences window
-(NSPoint) preferencesTopLeftPosition;
-(void) setPreferencesTopLeftPosition:(NSPoint) point;

@end
