//
//  IFPreferences.m
//  Inform
//
//  Created by Andrew Hunter on 02/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFPreferences.h"
#import "IFEditingPreferencesSet.h"
#import "IFProjectPane.h"

NSString* IFPreferencesAuthorDidChangeNotification      = @"IFPreferencesAuthorDidChangeNotification";
NSString* IFPreferencesEditingDidChangeNotification     = @"IFPreferencesEditingDidChangeNotification";
NSString* IFPreferencesAdvancedDidChangeNotification    = @"IFPreferencesAdvancedDidChangeNotification";
NSString* IFPreferencesAppFontSizeDidChangeNotification = @"IFPreferencesAppFontSizeDidChangeNotification";
NSString* IFPreferencesSkeinDidChangeNotification       = @"IFPreferencesSkeinDidChangeNotification";

NSString* IFPreferencesDefault                  = @"IFApplicationPreferences";

static NSString* IFPreferencesHeadings          = @"Headings";
static NSString* IFPreferencesMainText          = @"MainText";
static NSString* IFPreferencesComments          = @"Comments";
static NSString* IFPreferencesQuotedText        = @"QuotedText";
static NSString* IFPreferencesTextSubstitutions = @"TextSubstitutions";

@implementation IFPreferences

// = Constructing the object =

+ (void) initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
		[NSDictionary dictionary], IFPreferencesDefault,
		nil]];
}

+ (IFPreferences*) sharedPreferences {
	static IFPreferences* sharedPrefs = nil;
	
	if (!sharedPrefs) {
		sharedPrefs = [[IFPreferences alloc] init];
	}
	
	return sharedPrefs;
}

- (id) init {
	self = [super init];
	
	if (self) {
		preferences = [[[NSUserDefaults standardUserDefaults] objectForKey: IFPreferencesDefault] mutableCopy];
		
		if (!preferences || ![preferences isKindOfClass: [NSMutableDictionary class]]) {
			preferences = [[NSMutableDictionary alloc] init];
		}
		
        batchEditingPreferences = NO;
        batchNotificationTypes = [[NSMutableArray alloc] init];
        defaultEditingPreferences = [[IFEditingPreferencesSet alloc] init];

		[self recalculateStyles];
	}
	
	return self;
}

- (void) dealloc {
    [defaultEditingPreferences release];    defaultEditingPreferences = nil;
	[preferences release];					preferences = nil;

	[styles release];						styles = nil;
	[cacheFontSet release];					cacheFontSet = nil;
	[cacheFontStyles release];				cacheFontStyles = nil;
	[cacheColourSet release];				cacheColourSet = nil;
	[cacheColours release];					cacheColours = nil;
    [cacheUnderlines release];              cacheUnderlines = nil;
	
	[super dealloc];
}

// = Preference change notifications =

- (void) preferencesHaveChanged {
    if ( !batchEditingPreferences ) {
        // Update the user defaults
        [[NSUserDefaults standardUserDefaults] setObject: [[preferences copy] autorelease]
                                                  forKey: IFPreferencesDefault];
        [self recalculateStyles];

        // Send a notification
        if( notificationString != nil ) {
            [[NSNotificationCenter defaultCenter] postNotificationName: notificationString
                                                                object: self];
        }
    }
    else {
        if( notificationString != nil ) {
            [batchNotificationTypes addObject: notificationString];
        }
    }
    notificationString = nil;
}

// = batch editing of preferences =
-(void) startBatchEditing {
    NSAssert(batchEditingPreferences == NO, @"error updating preferences (start batch)");
    batchEditingPreferences = YES;
    [batchNotificationTypes removeAllObjects];
}

-(void) endBatchEditing {
    NSAssert(batchEditingPreferences == YES, @"error updating preferences (end batch)");
    batchEditingPreferences = NO;
    for(NSString*notification in batchNotificationTypes) {
        notificationString = notification;
        [self preferencesHaveChanged];
    }
    notificationString = nil;
}

// = Helper methods =

-(NSObject*) getPreference: (NSString*) key
                   default: (NSObject*) defaultValue {
    NSObject * result = [preferences objectForKey: key];
    if( result != nil ) {
        return result;
    }
    return defaultValue;
}

-(void) setPreference: (NSString*) key
                value: (NSObject*)value
         notification: (NSString*) notification {
    if( ![[preferences objectForKey:key] isEqualTo: value] )
    {
        [preferences setObject: value
                        forKey: key];

        notificationString = notification;
        [self preferencesHaveChanged];
    }
}

-(void) setPreferenceString: (NSString*) key
                      value: (NSString*) value
               notification: (NSString*) notification {
    [self setPreference: key
                  value: value
           notification: notification];
}

-(NSString*) getPreferenceString: (NSString*) key
                         default: (NSString*) defaultValue {
    return (NSString*) [self getPreference: key
                                   default: defaultValue];
}

-(void) setPreferenceInt: (NSString*) key
                   value: (int) value
            notification: notification {
    [self setPreference:key
                  value:[NSNumber numberWithInt: value]
           notification: notification];
}

-(int) getPreferenceInt: (NSString*) key
                default: (int) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: [NSNumber numberWithInt:defaultValue]];
    return [number intValue];
}


-(void) setPreferenceFloat: (NSString*) key
                     value: (float) value
              notification: notification {
    [self setPreference: key
                  value: [NSNumber numberWithFloat: value]
           notification: notification];
}

-(int) getPreferenceFloat: (NSString*) key
                  default: (float) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: [NSNumber numberWithFloat: defaultValue]];
    return [number intValue];
}

-(void) setPreferenceColour: (NSString*) key
                      value: (NSColor*) value
               notification: notification {
    NSData *theData = [NSArchiver archivedDataWithRootObject: value];
    [self setPreference: key
                  value: theData
           notification: notification];
}

-(NSColor*) getPreferenceColour: (NSString*) key
                        default: (NSColor*) defaultValue {
    NSData *theData = (NSData *) [self getPreference: key
                                             default: nil];
    if (theData != nil) {
        return (NSColor *)[NSUnarchiver unarchiveObjectWithData:theData];
    }
    return defaultValue;
}

-(void) setPreferenceBool: (NSString*) key
                    value: (BOOL) value
             notification: notification {
    [self setPreference: key
                  value: [NSNumber numberWithBool: value]
           notification: notification];
}

-(BOOL) getPreferenceBool: (NSString*) key
                  default: (BOOL) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: [NSNumber numberWithBool:defaultValue]];
    return [number boolValue];
}

// = Editing preferences =

-(NSString*) sourceFontFamily {
    return [self getPreferenceString: @"sourceFontFamily"
                             default: defaultEditingPreferences.fontFamily];
}

-(void) setSourceFontFamily: (NSString*) value {
    [self setPreferenceString: @"sourceFontFamily"
                        value: value
                 notification: IFPreferencesEditingDidChangeNotification];
}

- (float) sourceFontSize {
    return [self getPreferenceFloat: @"sourceFontSize" default: defaultEditingPreferences.fontSize];
}

- (void) setSourceFontSize: (float) pointSize {
    [self setPreferenceFloat: @"sourceFontSize"
                       value: pointSize
                notification: IFPreferencesEditingDidChangeNotification];
}

- (float) appFontSizeMultiplier {
    IFAppFontSize appFontSize = [self appFontSizeMultiplierEnum];
    switch ( appFontSize ) {
        case IFAppFontSizeMinus100: return 1.0f/2.0f;
        case IFAppFontSizeMinus75:  return 1.0f/1.75f;
        case IFAppFontSizeMinus50:  return 1.0f/1.5f;
        case IFAppFontSizeMinus25:  return 1.0f/1.25f;
        case IFAppFontSizeNormal:   return 1.0f;
        case IFAppFontSizePlus25:   return 1.25f;
        case IFAppFontSizePlus50:   return 1.5f;
        case IFAppFontSizePlus75:   return 1.75f;
        case IFAppFontSizePlus100:  return 2.0f;
    }
}

- (IFAppFontSize) appFontSizeMultiplierEnum {
    return [self getPreferenceInt: @"appFontSizeMultiplierFineEnum" default: IFAppFontSizeNormal];
}

- (void) setAppFontSizeMultiplierEnum: (IFAppFontSize) appFontSize {
    [self setPreferenceInt: @"appFontSizeMultiplierFineEnum"
                    value: (int) appFontSize
            notification: IFPreferencesAppFontSizeDidChangeNotification];
}

- (float) tabWidth {
    return [self getPreferenceFloat: @"tabWidth" default: defaultEditingPreferences.tabWidth];
}

- (void) setTabWidth: (float) newTabWidth {
    [self setPreferenceFloat: @"tabWidth"
                       value: newTabWidth
                notification: IFPreferencesEditingDidChangeNotification];
}

-(IFFontStyle) sourceFontStyleForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceFontStyle%d", (int) optionType];
    IFSyntaxHighlightingOption * option = [defaultEditingPreferences.options objectAtIndex:(int) optionType];
    IFFontStyle result = [self getPreferenceInt: key
                                        default: (int) [option fontStyle]];
    return result;
}

-(void) setSourceFontStyle: (IFFontStyle) style
             forOptionType: (IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceFontStyle%d", (int) optionType];
    [self setPreferenceInt: key
                     value: (int) style
              notification: IFPreferencesEditingDidChangeNotification];
}

-(IFRelativeFontSize) sourceRelativeFontSizeForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceRelativeFontSize%d", (int) optionType];
    IFSyntaxHighlightingOption * option = [defaultEditingPreferences.options objectAtIndex:(int) optionType];
    return (IFRelativeFontSize) [self getPreferenceInt: key
                                               default: (int) [option relativeFontSize]];
}

-(void) setSourceRelativeFontSize: (IFRelativeFontSize) size
              forOptionType: (IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceRelativeFontSize%d", (int) optionType];
    [self setPreferenceInt: key
                     value: size
              notification: IFPreferencesEditingDidChangeNotification];
}

-(NSColor*) sourceColourForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceColour%d", (int) optionType];
    IFSyntaxHighlightingOption * option = [defaultEditingPreferences.options objectAtIndex:(int) optionType];
    return [self getPreferenceColour: key
                             default: [option colour]];
}

-(void) setSourceColour: (NSColor*) colour
          forOptionType: (IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceColour%d", (int) optionType];
    [self setPreferenceColour: key
                        value: colour
                 notification: IFPreferencesEditingDidChangeNotification];
}

-(NSColor*) sourcePaperColour {
    return [self getPreferenceColour: @"sourcePaperColour"
                             default: [defaultEditingPreferences sourcePaperColor]];
}

-(void) setSourcePaperColour: (NSColor*) colour {
    [self setPreferenceColour: @"sourcePaperColour"
                        value: colour
                 notification: IFPreferencesEditingDidChangeNotification];
}

-(NSColor*) extensionPaperColour {
    return [self getPreferenceColour: @"extensionPaperColour"
                             default: [defaultEditingPreferences sourcePaperColor]];
}

-(void) setExtensionPaperColour: (NSColor*) colour {
    [self setPreferenceColour: @"extensionPaperColour"
                        value: colour
                 notification: IFPreferencesEditingDidChangeNotification];
}

-(BOOL) sourceUnderlineForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceUnderline%d", (int) optionType];
    IFSyntaxHighlightingOption * option = [defaultEditingPreferences.options objectAtIndex:(int) optionType];
    return [self getPreferenceBool: key
                           default: [option underline]];
}

-(void) setSourceUnderline: (BOOL) underline
             forOptionType: (IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceUnderline%d", (int) optionType];
    [self setPreferenceBool: key
                      value: underline
               notification: IFPreferencesEditingDidChangeNotification];
}

- (BOOL) enableSyntaxHighlighting {
    return [self getPreferenceBool: @"enableSyntaxHighlighting"
                           default: defaultEditingPreferences.enableSyntaxHighlighting];
}

- (void) setEnableSyntaxHighlighting: (BOOL) value {
    [self setPreferenceBool: @"enableSyntaxHighlighting"
                      value: value
               notification: IFPreferencesEditingDidChangeNotification];
}

- (BOOL) indentWrappedLines {
	return [self getPreferenceBool:@"indentWrappedLines"
                           default:defaultEditingPreferences.indentWrappedLines];
}

- (void) setIndentWrappedLines: (BOOL) value {
    [self setPreferenceBool: @"indentWrappedLines"
                      value: value
               notification: IFPreferencesEditingDidChangeNotification];
}

- (BOOL) elasticTabs {
    return [self getPreferenceBool: @"elasticTabs"
                           default: defaultEditingPreferences.autoSpaceTableColumns];
}

- (void) setElasticTabs: (BOOL) value {
    [self setPreferenceBool: @"elasticTabs"
                      value: value
               notification: IFPreferencesEditingDidChangeNotification];
}

- (BOOL) indentAfterNewline {
    return [self getPreferenceBool: @"indentAfterNewline"
                           default: defaultEditingPreferences.autoIndentAfterNewline];
}

- (void) setIndentAfterNewline: (BOOL) value {
    [self setPreferenceBool: @"indentAfterNewline"
                      value: value
               notification: IFPreferencesEditingDidChangeNotification];
}

- (BOOL) autoNumberSections {
    return [self getPreferenceBool: @"autoNumberSections"
                           default: defaultEditingPreferences.autoNumberSections];
}

- (void) setAutoNumberSections: (BOOL) value {
    [self setPreferenceBool: @"autoNumberSections"
                      value: value
               notification: IFPreferencesEditingDidChangeNotification];
}



- (NSFont*) fontWithName: (NSString*) name
					size: (float) size {
	NSFont* result = [NSFont fontWithName: name
									 size: size];
	
	if (result == nil) {
		result = [NSFont systemFontOfSize: size];
		NSLog(@"Warning: could not find font '%@'", name);
	}
	
	return result;
}

- (NSFont*) fontWithFamily: (NSString*) family
					traits: (int) traits
					weight: (int) weight
					  size: (float) size {
	NSFont* font = [[NSFontManager sharedFontManager] fontWithFamily: family
															  traits: traits
															  weight: weight
																size: size];
	if (font == nil) {
		font = [[NSFontManager sharedFontManager] fontWithFamily: family
														  traits: (NSFontTraitMask) 0
														  weight: weight
															size: size];
	}
	
	if (font == nil) {
		font = [[NSFontManager sharedFontManager] fontWithFamily: family
														  traits: traits
														  weight: 5
															size: size];
	}
	
	if (font == nil) {
		font = [[NSFontManager sharedFontManager] fontWithFamily: family
														  traits: (NSFontTraitMask) 0
														  weight: 5
															size: size];
	}
	
	if (font == nil) {
		font = [NSFont systemFontOfSize: size];
	}
	
	return font;
}

- (NSFont*) fontForOption: (IFSyntaxHighlightingOptionType) optionType {
    IFFontStyle style = [self sourceFontStyleForOptionType: optionType];
    
    int mask = 0;
    if      ( style == IFFontStyleRegular )     mask = 0;
    else if ( style == IFFontStyleItalic )      mask = NSItalicFontMask;
    else if ( style == IFFontStyleBold )        mask = NSBoldFontMask;
    else if ( style == IFFontStyleBoldItalic )  mask = NSBoldFontMask | NSItalicFontMask;

    float fontSize = [self sourceFontSize];
    switch ([self sourceRelativeFontSizeForOptionType: optionType] ) {
        case IFFontSizeMinus30: fontSize *= 0.7f; break;
        case IFFontSizeMinus20: fontSize *= 0.8f; break;
        case IFFontSizeMinus10: fontSize *= 0.9f; break;
        case IFFontSizePlus10: fontSize  *= 1.1f; break;
        case IFFontSizePlus20: fontSize  *= 1.2f; break;
        case IFFontSizePlus30: fontSize  *= 1.3f; break;
        case IFFontSizeNormal:
        default:
            break;
    }

    NSFont* result = [self fontWithFamily: [self sourceFontFamily]
                                   traits: mask
                                   weight: ((style == IFFontStyleBold) || (style == IFFontStyleBoldItalic)) ? 9 : 5
                                     size: fontSize];
    return result;
}

- (void) recalculateStyles {
	int x;
	
	// Deallocate the caches if they're currently allocated
    [cacheFontSet release];
    [cacheFontStyles release];
    [cacheColourSet release];
    [cacheColours release];
    [cacheUnderlines release];
	cacheFontSet	= nil;
	cacheFontStyles	= nil;
	cacheColourSet	= nil;
	cacheColours	= nil;
    cacheUnderlines = nil;
	
    [styles release];
	styles			= [[NSMutableArray alloc] init];
	
    // Cache of fonts we will use
    cacheFontSet = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
                     [self fontForOption: IFSHOptionHeadings],          IFPreferencesHeadings,
                     [self fontForOption: IFSHOptionMainText],          IFPreferencesMainText,
                     [self fontForOption: IFSHOptionComments],          IFPreferencesComments,
                     [self fontForOption: IFSHOptionQuotedText],        IFPreferencesQuotedText,
                     [self fontForOption: IFSHOptionTextSubstitutions], IFPreferencesTextSubstitutions,
                     nil]
                    retain];

	// Map font styles to syntax styles
	cacheFontStyles = [[NSMutableArray alloc] init];
	cacheColours = [[NSMutableArray alloc] init];
    cacheUnderlines = [[NSMutableArray alloc] init];
	
	// Default is just the base font
	NSFont* baseFont = [cacheFontSet objectForKey: IFPreferencesMainText];
	NSColor* black = [NSColor blackColor];
	for (x=0; x<256; x++) {
		[cacheFontStyles addObject: baseFont];
		[cacheColours addObject: black];
        [cacheUnderlines addObject: @NO];
	}

    //
    // Set fonts for each style
    //

    // Inform 6
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxProperty        withObject: [cacheFontSet objectForKey: IFPreferencesQuotedText]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxAssembly        withObject: [cacheFontSet objectForKey: IFPreferencesQuotedText]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxEscapeCharacter withObject: [cacheFontSet objectForKey: IFPreferencesQuotedText]];

    // Inform 7
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxTitle           withObject: [cacheFontSet objectForKey: IFPreferencesHeadings]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxHeading         withObject: [cacheFontSet objectForKey: IFPreferencesHeadings]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxNaturalInform   withObject: [cacheFontSet objectForKey: IFPreferencesMainText]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxComment         withObject: [cacheFontSet objectForKey: IFPreferencesComments]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxGameText        withObject: [cacheFontSet objectForKey: IFPreferencesQuotedText]];
    [cacheFontStyles replaceObjectAtIndex: IFSyntaxSubstitution    withObject: [cacheFontSet objectForKey: IFPreferencesTextSubstitutions]];

    //
    // Set colours for each style
    //

    // Inform 6
    [cacheColours replaceObjectAtIndex: IFSyntaxString          withObject: [NSColor colorWithDeviceRed: 0.53 green: 0.08 blue: 0.08 alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxDirective       withObject: [NSColor colorWithDeviceRed: 0.20 green: 0.08 blue: 0.53 alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxProperty        withObject: [NSColor colorWithDeviceRed: 0.08 green: 0.08 blue: 0.53 alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxFunction        withObject: [NSColor colorWithDeviceRed: 0.08 green: 0.53 blue: 0.53 alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxCode            withObject: [NSColor colorWithDeviceRed: 0.46 green: 0.06 blue: 0.31 alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxAssembly        withObject: [NSColor colorWithDeviceRed: 0.46 green: 0.31 blue: 0.31 alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxCodeAlpha       withObject: [NSColor colorWithDeviceRed: 0.4  green: 0.4  blue: 0.3  alpha: 1.0]];
    [cacheColours replaceObjectAtIndex: IFSyntaxEscapeCharacter withObject: [NSColor colorWithDeviceRed: 0.4  green: 0.4  blue: 0.3  alpha: 1.0]];

    // Inform 7
    [cacheColours replaceObjectAtIndex: IFSyntaxTitle           withObject: [self sourceColourForOptionType: IFSHOptionHeadings]];
    [cacheColours replaceObjectAtIndex: IFSyntaxHeading         withObject: [self sourceColourForOptionType: IFSHOptionHeadings]];
    [cacheColours replaceObjectAtIndex: IFSyntaxNaturalInform   withObject: [self sourceColourForOptionType: IFSHOptionMainText]];
    [cacheColours replaceObjectAtIndex: IFSyntaxComment         withObject: [self sourceColourForOptionType: IFSHOptionComments]];
    [cacheColours replaceObjectAtIndex: IFSyntaxGameText        withObject: [self sourceColourForOptionType: IFSHOptionQuotedText]];
    [cacheColours replaceObjectAtIndex: IFSyntaxSubstitution    withObject: [self sourceColourForOptionType: IFSHOptionTextSubstitutions]];

    //
    // Set underscore for each style
    //
    // Inform 7
    [cacheUnderlines replaceObjectAtIndex: IFSyntaxTitle           withObject: [self sourceUnderlineForOptionType: IFSHOptionHeadings] ? @YES : @NO];
    [cacheUnderlines replaceObjectAtIndex: IFSyntaxHeading         withObject: [self sourceUnderlineForOptionType: IFSHOptionHeadings] ? @YES : @NO];
    [cacheUnderlines replaceObjectAtIndex: IFSyntaxNaturalInform   withObject: [self sourceUnderlineForOptionType: IFSHOptionMainText] ? @YES : @NO];
    [cacheUnderlines replaceObjectAtIndex: IFSyntaxComment         withObject: [self sourceUnderlineForOptionType: IFSHOptionComments] ? @YES : @NO];
    [cacheUnderlines replaceObjectAtIndex: IFSyntaxGameText        withObject: [self sourceUnderlineForOptionType: IFSHOptionQuotedText] ? @YES : @NO];
    [cacheUnderlines replaceObjectAtIndex: IFSyntaxSubstitution    withObject: [self sourceUnderlineForOptionType: IFSHOptionTextSubstitutions] ? @YES : @NO];
    
	// Finally... build the actual set of styles
	if (styles) [styles release];
	styles = [[NSMutableArray alloc] init];
	
    NSNumber* underline = [NSNumber numberWithInt:NSUnderlineStyleSingle];
    NSNumber* noUnderline = [NSNumber numberWithInt:NSUnderlineStyleNone];
    NSNumber* currentUnderline = nil;
    
	for (x=0; x<256; x++) {
        if( [[cacheUnderlines objectAtIndex:x] isEqualTo: @YES] ) {
            currentUnderline = underline;
        }
        else {
            currentUnderline = noUnderline;
        }
        [styles addObject: [NSDictionary dictionaryWithObjectsAndKeys:
            [cacheFontStyles objectAtIndex: x], NSFontAttributeName,
            [cacheColours objectAtIndex: x],    NSForegroundColorAttributeName,
            currentUnderline,                   NSUnderlineStyleAttributeName,
            nil]];
	}
}

- (NSArray*) styles {
	return styles;
}

// = Author's name =

- (NSString*) longUserName {
	NSString* longuserName = NSFullUserName();
	if ([longuserName length] == 0 || longuserName == nil) longuserName = NSUserName();
	if ([longuserName length] == 0 || longuserName == nil) longuserName = @"Unknown Author";

	return longuserName;
}

- (NSString*) freshGameAuthorName {
	NSString* value = [preferences objectForKey: @"newGameAuthorName"];
	
	value = [value stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	
	if (value == nil || [value isEqualToString: @""]) {
		// Use the current OS X user name
		return [self longUserName];
	} else {
		// Use the specified value
		return [[value copy] autorelease];
	}
}

- (void) setFreshGameAuthorName: (NSString*) value {
	if ([[value lowercaseString] isEqualToString: [[self longUserName] lowercaseString]]) {
		// Special case: if the user enters their own username, we go back to tracking that
		value = @"";
	}
    
    [self setPreferenceString: @"newGameAuthorName"
                        value: value
                 notification: IFPreferencesAuthorDidChangeNotification];
}

// = Advanced preferences =

- (BOOL) runBuildSh {
    return [self getPreferenceBool: @"runBuildSh"
                           default: NO];
}

- (BOOL) showDebuggingLogs {
    return [self getPreferenceBool: @"showDebuggingLogs"
                           default: NO];
}

- (BOOL) showConsoleDuringBuilds {
    return [self getPreferenceBool: @"showConsoleDuringBuilds"
                           default: NO];
}

- (BOOL) publicLibraryDebug {
    return [self getPreferenceBool: @"publicLibraryDebug"
                           default: NO];
}

- (BOOL) cleanProjectOnClose {
    return [self getPreferenceBool: @"cleanProjectOnClose"
                           default: YES];
}

- (BOOL) alsoCleanIndexFiles {
    return [self getPreferenceBool: @"alsoCleanIndexFiles"
                           default: NO];
}

- (NSString*) glulxInterpreter {
	NSString* value = [preferences objectForKey: @"glulxInterpreter"];
	
	if (value) {
		return [[value copy] autorelease];
	} else {
		// Work out the default client to use
		NSString*		clientName = @"glulxe";
		NSDictionary*	configSettings = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"InformConfiguration"];
		if (!configSettings) {
			configSettings = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"InformConfiguration"];
		}
		if (configSettings) {
			clientName = (NSString*)[configSettings objectForKey: @"GlulxInterpreter"];
		}
		if (!clientName) clientName = @"glulxe";
		
		return clientName;
	}
}

- (void) setCleanProjectOnClose: (BOOL) value {
    [self setPreferenceBool: @"cleanProjectOnClose"
                      value: value
               notification: IFPreferencesAdvancedDidChangeNotification];
}

- (void) setAlsoCleanIndexFiles: (BOOL) value {
    [self setPreferenceBool: @"alsoCleanIndexFiles"
                      value: value
               notification: IFPreferencesAdvancedDidChangeNotification];
}

- (void) setRunBuildSh: (BOOL) value {
    [self setPreferenceBool: @"runBuildSh"
                      value: value
               notification: IFPreferencesAdvancedDidChangeNotification];
}

- (void) setShowDebuggingLogs: (BOOL) value {
    [self setPreferenceBool: @"showDebuggingLogs"
                      value:value
               notification: IFPreferencesAdvancedDidChangeNotification];
}

- (void) setShowConsoleDuringBuilds: (BOOL) value {
    [self setPreferenceBool: @"showConsoleDuringBuilds"
                      value:value
               notification: IFPreferencesAdvancedDidChangeNotification];
}

- (void) setPublicLibraryDebug: (BOOL) value {
    [self setPreferenceBool: @"publicLibraryDebug"
                      value: value
               notification: IFPreferencesAdvancedDidChangeNotification];
}

- (void) setGlulxInterpreter: (NSString*) interpreter {
    [self setPreferenceString: @"glulxInterpreter"
                        value: interpreter
                 notification: IFPreferencesAdvancedDidChangeNotification];
}

// Position of preferences window
-(NSPoint) preferencesTopLeftPosition {
    NSPoint result;
    
    result.x = [self getPreferenceFloat: @"PreferencesWindowX"
                                default: 50.0f];
    result.y = [self getPreferenceFloat: @"PreferencesWindowY"
                                default: 50.0f];
    return result;
}

-(void) setPreferencesTopLeftPosition:(NSPoint) point {
    [self setPreferenceFloat: @"PreferencesWindowX"
                       value: point.x
                notification: nil];
    [self setPreferenceFloat: @"PreferencesWindowY"
                       value: point.y
                notification: nil];
}

@end
