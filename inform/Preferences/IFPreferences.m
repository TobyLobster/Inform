//
//  IFPreferences.m
//  Inform
//
//  Created by Andrew Hunter on 02/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFPreferences.h"
#import "IFEditingPreferencesSet.h"
#import "IFColourTheme.h"
#import "IFProjectPane.h"

NSString* const IFPreferencesAuthorDidChangeNotification      = @"IFPreferencesAuthorDidChangeNotification";
NSString* const IFPreferencesEditingDidChangeNotification     = @"IFPreferencesEditingDidChangeNotification";
NSString* const IFPreferencesAdvancedDidChangeNotification    = @"IFPreferencesAdvancedDidChangeNotification";
NSString* const IFPreferencesAppFontSizeDidChangeNotification = @"IFPreferencesAppFontSizeDidChangeNotification";
NSString* const IFPreferencesSkeinDidChangeNotification       = @"IFPreferencesSkeinDidChangeNotification";

NSString* const IFPreferencesDefault                  = @"IFApplicationPreferences";

static NSString* const IFPreferencesHeadings          = @"Headings";
static NSString* const IFPreferencesMainText          = @"MainText";
static NSString* const IFPreferencesComments          = @"Comments";
static NSString* const IFPreferencesQuotedText        = @"QuotedText";
static NSString* const IFPreferencesTextSubstitutions = @"TextSubstitutions";





@implementation IFSyntaxColouringOption

-(instancetype)init
{
    self = [self initWithColour:[NSColor blackColor]];
    return self;
}

-(instancetype) initWithColour:(NSColor*) defaultColour {
    self = [super init];
    if( self ) {
        assert(defaultColour != nil);
        self.colour           = [defaultColour copy];
        self.defaultColour    = [defaultColour copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    assert(self.colour != nil);
    assert(self.defaultColour != nil);

    [encoder encodeObject: (NSColor*) self.colour forKey: @"colour"];
    [encoder encodeObject: (NSColor*) self.defaultColour forKey: @"defaultColour"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self init]; // Call the designated initialiser first

    self.colour = [[decoder decodeObjectOfClass:[NSColor class] forKey: @"colour"] copy];
    assert(self.colour != nil);
    self.defaultColour = [[decoder decodeObjectOfClass:[NSColor class] forKey: @"defaultColour"] copy];
    assert(self.defaultColour != nil);

    return self;
}

+(BOOL) supportsSecureCoding {
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    IFSyntaxColouringOption* result = [[[self class] alloc] init];
    if (result) {
        [result setColour: [self.colour copy]];
        [result setDefaultColour: [self.defaultColour copy]];
    }
    return result;
}

@end




@implementation IFPreferences {
    /// The preferences dictionary
    NSMutableDictionary* preferences;

    // Notification flag
    BOOL batchEditingPreferences;
    BOOL batchEditingDirty;
    NSMutableArray* batchNotificationTypes;
    NSString* notificationString;

    // Caches
    /// Maps 'font types' to fonts
    NSMutableDictionary* cacheFontSet;
    /// Maps styles to fonts
    NSMutableArray* cacheFontStyles;
    /// Choice of colours
    NSMutableArray* cacheColourSet;
    /// Maps styles to colours
    NSMutableArray* cacheColours;
    /// Maps styles to underlines
    NSMutableArray* cacheUnderlines;

    /// The array of actual styles (array of attribute dictionaries)
    NSMutableArray* styles;

    // Themes
    NSMutableArray* themes;

    // Defaults
    IFEditingPreferencesSet* defaultEditingPreferences;
}

#pragma mark - Constructing the object

+ (void) initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults: @{IFPreferencesDefault: @{}}];
}

+ (IFPreferences*) sharedPreferences {
	static IFPreferences* sharedPrefs = nil;
	
	if (!sharedPrefs) {
		sharedPrefs = [[IFPreferences alloc] init];
	}
	
	return sharedPrefs;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		preferences = [[[NSUserDefaults standardUserDefaults] objectForKey: IFPreferencesDefault] mutableCopy];
		
		if (!preferences || ![preferences isKindOfClass: [NSMutableDictionary class]]) {
			preferences = [[NSMutableDictionary alloc] init];
		}
		
        batchEditingPreferences = NO;
        batchNotificationTypes = [[NSMutableArray alloc] init];

        defaultEditingPreferences = [[IFEditingPreferencesSet alloc] init];

        NSArray * result = [self getPreferenceThemes];
        if (result != nil) {
            themes = [[NSMutableArray alloc] initWithArray: result];
        } else {
            themes = [[NSMutableArray alloc] init];
        }

		[self recalculateStyles];
	}
	
	return self;
}

- (void) dealloc {
    defaultEditingPreferences = nil;
    preferences = nil;

    styles = nil;
    cacheFontSet = nil;
    cacheFontStyles = nil;
    cacheColourSet = nil;
    cacheColours = nil;
    cacheUnderlines = nil;
}

#pragma mark - Preference change notifications

- (void) preferencesHaveChanged {
    if ( !batchEditingPreferences ) {
        // Update the user defaults
        [[NSUserDefaults standardUserDefaults] setObject: [preferences copy]
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

#pragma mark -  batch editing of preferences

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

#pragma mark - Helper methods

-(NSObject*) getPreference: (NSString*) key
                   default: (NSObject*) defaultValue {
    NSObject * result = preferences[key];
    if( result != nil ) {
        return result;
    }
    return defaultValue;
}

-(void) setPreference: (NSString*) key
                value: (NSObject*)value
         notification: (NSString*) notification {
    if( ![preferences[key] isEqualTo: value] )
    {
        preferences[key] = value;

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
            notification: (NSString*) notification {
    [self setPreference:key
                  value:@(value)
           notification: notification];
}

-(int) getPreferenceInt: (NSString*) key
                default: (int) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: @(defaultValue)];
    return [number intValue];
}


-(void) setPreferenceFloat: (NSString*) key
                     value: (float) value
              notification: (NSString*) notification {
    [self setPreference: key
                  value: @(value)
           notification: notification];
}

-(void) setPreferenceDouble: (NSString*) key
                      value: (double) value
               notification: (NSString*) notification {
    [self setPreference: key
                  value: @(value)
           notification: (NSString*) notification];
}

-(int) getPreferenceFloat: (NSString*) key
                  default: (float) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: @(defaultValue)];
    return [number floatValue];
}

-(int) getPreferenceDouble: (NSString*) key
                  default: (double) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: @(defaultValue)];
    return [number doubleValue];
}


-(void) setPreferenceColour: (NSString*) key
                      value: (NSColor*) value
               notification: (NSString*) notification {
    NSData *theData = [NSKeyedArchiver archivedDataWithRootObject: value
                                            requiringSecureCoding: YES
                                                            error: NULL];
    [self setPreference: key
                  value: theData
           notification: notification];
}

-(NSColor*) getPreferenceColour: (NSString*) key
                        default: (NSColor*) defaultValue {
    NSData *theData = (NSData *) [self getPreference: key
                                             default: nil];
    if (theData != nil) {
        NSColor *col = [NSKeyedUnarchiver unarchivedObjectOfClass: [NSColor class] fromData: theData error: NULL];
        if (!col) {
            col = [NSUnarchiver unarchiveObjectWithData: theData];
        }
        return col;
    }
    return defaultValue;
}


-(void) setPreferenceThemesWithNotification:(NSString*) notification {
    NSArray *non_mutable_array = [themes copy];
    NSData *theData = [NSKeyedArchiver archivedDataWithRootObject: non_mutable_array
                                            requiringSecureCoding: YES
                                                            error: NULL];
    [self setPreference: @"themes"
                  value: theData
           notification: notification];
}

-(NSArray*) removeIllegalEntries: (NSArray*) array {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for(int i = 0; i < array.count; i++) {
        IFColourTheme* theme = array[i];
        if (theme == nil) {
            continue;
        }
        if ((theme.themeName == nil) ||
            (theme.sourcePaper == nil) ||
            (theme.extensionPaper == nil) ||
            (theme.flags == nil) ||
            (theme.options == nil)) {
                continue;
        }

        if (theme.options.count < IFSHOptionCount) {
            continue;
        }

        [result addObject: theme];
    }
    return result;
}

-(NSArray*) getPreferenceThemes {
    NSData *theData = (NSData *) [self getPreference: @"themes"
                                             default: nil];
    if (theData != nil) {
        @try {
            NSError * error;

            //NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:theData error:&error];
            //[unarchiver setRequiresSecureCoding:NO];
            //NSArray* array = [unarchiver decodeObjectForKey: @"themes"];

            NSSet *classesSet = [NSSet setWithObjects:
                                 [NSString class],
                                 [NSColor class],
                                 [IFColourTheme class],
                                 [IFSyntaxColouringOption class],
                                 [NSArray class],
                                 [NSMutableArray class],
                                 [NSNumber class],
                                 [NSMutableData class],
                                 [NSDictionary class],
                                 [NSDate class],
                                 [NSValue class],
                                 [NSNull class],
                                 nil];
            NSArray*array = [NSKeyedUnarchiver unarchivedObjectOfClasses: classesSet
                                                                fromData: theData
                                                                   error: &error];
            array = [self removeIllegalEntries: array];
            return array;
        }
        @catch (NSException *exception) {
            NSLog(@"Exception %@", [exception reason]);
        }
    }
    return nil;
}

-(int) getThemeIndex: (NSString*) name {
    for(int i = 0; i < themes.count; i++) {
        IFColourTheme* theme = themes[i];
        if (name == theme.themeName) {
            return i;
        }
    }
    return -1;
}

-(IFColourTheme*) getCurrentTheme {
    if (themes.count == 0) {
        [self resetDefaultThemes];
    }
    assert(themes.count > 0);

    int i = [self getThemeIndex: [self getCurrentThemeName]];
    if (i < 0) {
        i = 0;
    }
    return themes[i];
}

-(bool) setCurrentTheme: (NSString*) name {
    // if name doesn't exist, fail
    int result = [self getThemeIndex: name];
    if (result < 0) {
        return false;
    }

    [self setCurrentThemeName: name];

    notificationString = IFPreferencesEditingDidChangeNotification;
    [self preferencesHaveChanged];
    return true;
}

-(NSArray*) getThemeNames {
    NSMutableArray* array = [[NSMutableArray alloc] init];

    for(int i = 0; i < themes.count; i++) {
        [array addObject: [themes[i] themeName]];
    }
    return array;
}


-(bool) addTheme: (IFColourTheme*) theme {
    // If theme name already exists, fail
    if ([self getThemeIndex: theme.themeName] >= 0) {
        return false;
    }

    [themes addObject:theme];

    notificationString = IFPreferencesEditingDidChangeNotification;
    [self preferencesHaveChanged];
    return true;
}

-(bool) removeTheme: (NSString*) themeName {
    int index = [self getThemeIndex: themeName];
    if (index < 0) {
        return false;
    }

    [themes removeObjectAtIndex:index];
    notificationString = IFPreferencesEditingDidChangeNotification;
    [self preferencesHaveChanged];
    return true;
}

-(void) setPreferenceBool: (NSString*) key
                    value: (BOOL) value
             notification: (NSString*) notification {
    [self setPreference: key
                  value: @(value)
           notification: notification];
}

-(BOOL) getPreferenceBool: (NSString*) key
                  default: (BOOL) defaultValue {
    NSNumber* number = (NSNumber*)[self getPreference: key
                                              default: @(defaultValue)];
    return [number boolValue];
}

#pragma mark - Editing preferences

- (void) resetDefaultThemes {
    themes = [[NSMutableArray alloc] init];

    // Create light theme
    IFColourTheme* light = [[IFColourTheme alloc] init];
    light.themeName           = @"Light";
    light.sourcePaper         = [[IFSyntaxColouringOption alloc] initWithColour:[NSColor whiteColor]];
    light.extensionPaper      = [[IFSyntaxColouringOption alloc] initWithColour:[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 0.9 alpha: 1.0]];
    light.flags               = [[NSNumber alloc] initWithInt:0];
    [light.options[IFSHOptionHeadings]           setColour: [NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0]];
    [light.options[IFSHOptionMainText]           setColour: [NSColor colorWithDeviceRed: 0.0 green: 0.0 blue: 0.0 alpha: 1.0]];
    [light.options[IFSHOptionComments]           setColour: [NSColor colorWithDeviceRed: 0.14 green: 0.43 blue: 0.14 alpha: 1.0]];
    [light.options[IFSHOptionQuotedText]         setColour: [NSColor colorWithDeviceRed: 0.0 green: 0.3 blue: 0.6 alpha: 1.0]];
    [light.options[IFSHOptionTextSubstitutions]  setColour: [NSColor colorWithDeviceRed: 0.3 green: 0.3 blue: 1.0 alpha: 1.0]];

    for(int i = 0; i < light.options.count; i++) {
        light.options[i].defaultColour = [light.options[i].colour copy];
    }

    //for(int i = 0; i < light.options.count; i++) {
    //    NSLog(@"resetDefaultThemes light new option %d is %@", i, light.options[i].defaultColour);
    //}

    [themes addObject: light];

    // Create dark theme
    IFColourTheme* dark = [[IFColourTheme alloc] init];
    dark.themeName           = @"Dark";
    dark.sourcePaper         = [[IFSyntaxColouringOption alloc] initWithColour:[NSColor blackColor]];
    dark.extensionPaper      = [[IFSyntaxColouringOption alloc] initWithColour:[NSColor colorWithDeviceRed: 0.2 green: 0.2 blue: 0.2 alpha: 1.0]];
    dark.flags               = [[NSNumber alloc] initWithInt:0];
    [dark.options[IFSHOptionHeadings]           setColour: [NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0]];
    [dark.options[IFSHOptionMainText]           setColour: [NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 1.0]];
    [dark.options[IFSHOptionComments]           setColour: [NSColor colorWithDeviceRed: 0.14 green: 0.43 blue: 0.14 alpha: 1.0]];
    [dark.options[IFSHOptionQuotedText]         setColour: [NSColor colorWithDeviceRed: 0.0 green: 0.3 blue: 0.6 alpha: 1.0]];
    [dark.options[IFSHOptionTextSubstitutions]  setColour: [NSColor colorWithDeviceRed: 0.3 green: 0.3 blue: 1.0 alpha: 1.0]];
    for(int i = 0; i < dark.options.count; i++) {
        dark.options[i].defaultColour = [dark.options[i].colour copy];
    }
    [themes addObject: dark];

    //for(int i = 0; i < dark.options.count; i++) {
    //    NSLog(@"resetDefaultThemes dark new option %d is %@", i, dark.options[i].defaultColour);
    //}

    [self setPreferenceThemesWithNotification:IFPreferencesEditingDidChangeNotification];
}


-(NSString*) getCurrentThemeName {
    return [self getPreferenceString: @"currentThemeName"
                             default: @"Light"];
}

-(void) setCurrentThemeName: (NSString*) value {
    [self setPreferenceString: @"currentThemeName"
                        value: value
                 notification: IFPreferencesEditingDidChangeNotification];
}



-(NSString*) sourceFontFamily {
    return [self getPreferenceString: @"sourceFontFamily"
                             default: defaultEditingPreferences.fontFamily];
}

-(void) setSourceFontFamily: (NSString*) value {
    [self setPreferenceString: @"sourceFontFamily"
                        value: value
                 notification: IFPreferencesEditingDidChangeNotification];
}

- (CGFloat) sourceFontSize {
    return [self getPreferenceDouble: @"sourceFontSize" default: defaultEditingPreferences.fontSize];
}

- (void) setSourceFontSize: (CGFloat) pointSize {
    [self setPreferenceDouble: @"sourceFontSize"
                        value: pointSize
                 notification: IFPreferencesEditingDidChangeNotification];
}

- (CGFloat) appFontSizeMultiplier {
    IFAppFontSize appFontSize = [self appFontSizeMultiplierEnum];
    switch ( appFontSize ) {
        case IFAppFontSizeMinus100: return 1.0/2.0;
        case IFAppFontSizeMinus75:  return 1.0/1.75;
        case IFAppFontSizeMinus50:  return 1.0/1.5;
        case IFAppFontSizeMinus25:  return 1.0/1.25;
        case IFAppFontSizeNormal:   return 1.0;
        case IFAppFontSizePlus25:   return 1.25;
        case IFAppFontSizePlus50:   return 1.5;
        case IFAppFontSizePlus75:   return 1.75;
        case IFAppFontSizePlus100:  return 2.0;
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

- (CGFloat) tabWidth {
    return [self getPreferenceDouble: @"tabWidth" default: defaultEditingPreferences.tabWidth];
}

- (void) setTabWidth: (CGFloat) newTabWidth {
    [self setPreferenceDouble: @"tabWidth"
                       value: newTabWidth
                notification: IFPreferencesEditingDidChangeNotification];
}

-(IFFontStyle) sourceFontStyleForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceFontStyle%d", (int) optionType];
    IFSyntaxHighlightingOption * option = (defaultEditingPreferences.options)[(int) optionType];
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
    IFSyntaxHighlightingOption * option = (defaultEditingPreferences.options)[(int) optionType];
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


-(void) setSourcePaper: (IFSyntaxColouringOption*) option {
    IFColourTheme * theme = [self getCurrentTheme];
    theme.sourcePaper = [option copy];
    [self setPreferenceThemesWithNotification:IFPreferencesEditingDidChangeNotification];
}

-(void) setExtensionPaper: (IFSyntaxColouringOption*) option {
    IFColourTheme * theme = [self getCurrentTheme];
    theme.extensionPaper = [option copy];
    [self setPreferenceThemesWithNotification:IFPreferencesEditingDidChangeNotification];
}

-(IFSyntaxColouringOption*) getSourcePaper {
    IFColourTheme * theme = [self getCurrentTheme];
    return theme.sourcePaper;
}

-(IFSyntaxColouringOption*) getExtensionPaper {
    IFColourTheme * theme = [self getCurrentTheme];
    return theme.extensionPaper;
}


-(IFSyntaxColouringOption*) sourcePaperForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    IFColourTheme * theme = [self getCurrentTheme];

    IFSyntaxColouringOption * option = (theme.options)[(int) optionType];
    return option;
}

-(void) setSourceColour: (NSColor*) colour
          forOptionType: (IFSyntaxHighlightingOptionType) optionType {
    IFColourTheme * theme = [self getCurrentTheme];
    IFSyntaxColouringOption * option = (theme.options)[(int) optionType];
    option.colour = colour;

    [self setPreferenceThemesWithNotification:IFPreferencesEditingDidChangeNotification];
}

-(BOOL) sourceUnderlineForOptionType:(IFSyntaxHighlightingOptionType) optionType {
    NSString * key = [NSString stringWithFormat:@"sourceUnderline%d", (int) optionType];
    IFSyntaxHighlightingOption * option = (defaultEditingPreferences.options)[(int) optionType];
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

- (BOOL) enableSyntaxColouring {
    return [self getPreferenceBool: @"enableSyntaxColouring"
                           default: true];
}

- (void) setEnableSyntaxColouring: (BOOL) value {
    [self setPreferenceBool: @"enableSyntaxColouring"
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
					size: (CGFloat) size {
	NSFont* result = [NSFont fontWithName: name
									 size: size];
	
	if (result == nil) {
		result = [NSFont systemFontOfSize: size];
		NSLog(@"Warning: could not find font '%@'", name);
	}
	
	return result;
}

- (NSFont*) fontWithFamily: (NSString*) family
					traits: (NSFontTraitMask) traits
					weight: (int) weight
					  size: (CGFloat) size {
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

    CGFloat fontSize = [self sourceFontSize];
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
	NSInteger x;
	
	// Deallocate the caches if they're currently allocated
	cacheColourSet	= nil;

	styles			= [[NSMutableArray alloc] init];
	
    // Cache of fonts we will use
    cacheFontSet = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                     [self fontForOption: IFSHOptionHeadings],          IFPreferencesHeadings,
                     [self fontForOption: IFSHOptionMainText],          IFPreferencesMainText,
                     [self fontForOption: IFSHOptionComments],          IFPreferencesComments,
                     [self fontForOption: IFSHOptionQuotedText],        IFPreferencesQuotedText,
                     [self fontForOption: IFSHOptionTextSubstitutions], IFPreferencesTextSubstitutions,
                     nil];

	// Map font styles to syntax styles
	cacheFontStyles = [[NSMutableArray alloc] init];
	cacheColours = [[NSMutableArray alloc] init];
    cacheUnderlines = [[NSMutableArray alloc] init];
	
	// Default is just the base font
	NSFont* baseFont = cacheFontSet[IFPreferencesMainText];
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
    cacheFontStyles[IFSyntaxProperty] = cacheFontSet[IFPreferencesQuotedText];
    cacheFontStyles[IFSyntaxAssembly] = cacheFontSet[IFPreferencesQuotedText];
    cacheFontStyles[IFSyntaxEscapeCharacter] = cacheFontSet[IFPreferencesQuotedText];

    // Inform 7
    cacheFontStyles[IFSyntaxTitle] = cacheFontSet[IFPreferencesHeadings];
    cacheFontStyles[IFSyntaxHeading] = cacheFontSet[IFPreferencesHeadings];
    cacheFontStyles[IFSyntaxNaturalInform] = cacheFontSet[IFPreferencesMainText];
    cacheFontStyles[IFSyntaxComment] = cacheFontSet[IFPreferencesComments];
    cacheFontStyles[IFSyntaxGameText] = cacheFontSet[IFPreferencesQuotedText];
    cacheFontStyles[IFSyntaxSubstitution] = cacheFontSet[IFPreferencesTextSubstitutions];

    //
    // Set colours for each style
    //

    // Inform 6
    cacheColours[IFSyntaxString] = [NSColor colorWithDeviceRed: 0.53 green: 0.08 blue: 0.08 alpha: 1.0];
    cacheColours[IFSyntaxDirective] = [NSColor colorWithDeviceRed: 0.20 green: 0.08 blue: 0.53 alpha: 1.0];
    cacheColours[IFSyntaxProperty] = [NSColor colorWithDeviceRed: 0.08 green: 0.08 blue: 0.53 alpha: 1.0];
    cacheColours[IFSyntaxFunction] = [NSColor colorWithDeviceRed: 0.08 green: 0.53 blue: 0.53 alpha: 1.0];
    cacheColours[IFSyntaxCode] = [NSColor colorWithDeviceRed: 0.46 green: 0.06 blue: 0.31 alpha: 1.0];
    cacheColours[IFSyntaxAssembly] = [NSColor colorWithDeviceRed: 0.46 green: 0.31 blue: 0.31 alpha: 1.0];
    cacheColours[IFSyntaxCodeAlpha] = [NSColor colorWithDeviceRed: 0.4  green: 0.4  blue: 0.3  alpha: 1.0];
    cacheColours[IFSyntaxEscapeCharacter] = [NSColor colorWithDeviceRed: 0.4  green: 0.4  blue: 0.3  alpha: 1.0];

    // Inform 7
    cacheColours[IFSyntaxTitle] = [[self sourcePaperForOptionType: IFSHOptionHeadings] colour];
    cacheColours[IFSyntaxHeading] = [[self sourcePaperForOptionType: IFSHOptionHeadings] colour];
    cacheColours[IFSyntaxNaturalInform] = [[self sourcePaperForOptionType: IFSHOptionMainText] colour];
    cacheColours[IFSyntaxComment] = [[self sourcePaperForOptionType: IFSHOptionComments] colour];
    cacheColours[IFSyntaxGameText] = [[self sourcePaperForOptionType: IFSHOptionQuotedText] colour];
    cacheColours[IFSyntaxSubstitution] = [[self sourcePaperForOptionType: IFSHOptionTextSubstitutions] colour];

    //
    // Set underscore for each style
    //
    // Inform 7
    cacheUnderlines[IFSyntaxTitle] = [self sourceUnderlineForOptionType: IFSHOptionHeadings] ? @YES : @NO;
    cacheUnderlines[IFSyntaxHeading] = [self sourceUnderlineForOptionType: IFSHOptionHeadings] ? @YES : @NO;
    cacheUnderlines[IFSyntaxNaturalInform] = [self sourceUnderlineForOptionType: IFSHOptionMainText] ? @YES : @NO;
    cacheUnderlines[IFSyntaxComment] = [self sourceUnderlineForOptionType: IFSHOptionComments] ? @YES : @NO;
    cacheUnderlines[IFSyntaxGameText] = [self sourceUnderlineForOptionType: IFSHOptionQuotedText] ? @YES : @NO;
    cacheUnderlines[IFSyntaxSubstitution] = [self sourceUnderlineForOptionType: IFSHOptionTextSubstitutions] ? @YES : @NO;
    
	// Finally... build the actual set of styles
	styles = [[NSMutableArray alloc] init];
	
    NSNumber* underline = @(NSUnderlineStyleSingle);
    NSNumber* noUnderline = @(NSUnderlineStyleNone);
    NSNumber* currentUnderline = nil;
    
	for (x=0; x<256; x++) {
        if( [cacheUnderlines[x] isEqualTo: @YES] ) {
            currentUnderline = underline;
        }
        else {
            currentUnderline = noUnderline;
        }
        [styles addObject: @{NSFontAttributeName: cacheFontStyles[x],
            NSForegroundColorAttributeName: cacheColours[x],
            NSUnderlineStyleAttributeName: currentUnderline}];
	}
}

- (NSArray*) styles {
	return [styles copy];
}

#pragma mark - Author's name

- (NSString*) longUserName {
	NSString* longuserName = NSFullUserName();
	if ([longuserName length] == 0 || longuserName == nil) longuserName = NSUserName();
	if ([longuserName length] == 0 || longuserName == nil) longuserName = @"Unknown Author";

	return longuserName;
}

- (NSString*) freshGameAuthorName {
	NSString* value = preferences[@"newGameAuthorName"];
	
	value = [value stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	
	if (value == nil || [value isEqualToString: @""]) {
		// Use the current OS X user name
		return [self longUserName];
	} else {
		// Use the specified value
		return [value copy];
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

#pragma mark - Advanced preferences

- (BOOL) runBuildSh {
    return [self getPreferenceBool: @"runBuildSh"
                           default: NO];
}

- (BOOL) alwaysCompile {
    return [self getPreferenceBool: @"alwaysCompile"
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
	NSString* value = preferences[@"glulxInterpreter"];
	
	if (value) {
		return [value copy];
	} else {
		// Work out the default client to use
		NSString*		clientName = @"glulxe";
		NSDictionary*	configSettings = [[NSBundle mainBundle] infoDictionary][@"InformConfiguration"];
		if (!configSettings) {
			configSettings = [[NSBundle mainBundle] infoDictionary][@"InformConfiguration"];
		}
		if (configSettings) {
			clientName = (NSString*)configSettings[@"GlulxInterpreter"];
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

- (void) setAlwaysCompile: (BOOL) value {
    [self setPreferenceBool: @"alwaysCompile"
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
    
    result.x = [self getPreferenceDouble: @"PreferencesWindowX"
                                 default: 50.0f];
    result.y = [self getPreferenceDouble: @"PreferencesWindowY"
                                 default: 50.0f];
    return result;
}

-(void) setPreferencesTopLeftPosition:(NSPoint) point {
    [self setPreferenceDouble: @"PreferencesWindowX"
                        value: point.x
                 notification: nil];
    [self setPreferenceDouble: @"PreferencesWindowY"
                        value: point.y
                 notification: nil];
}

@end
