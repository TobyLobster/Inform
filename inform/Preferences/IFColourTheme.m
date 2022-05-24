//
//  IFColourTheme.m
//  Inform
//
//  Created by Toby Nelson in 2022
//

#import "IFPreferences.h"
#import "IFColourTheme.h"

#import "IFSyntaxManager.h"
#import "IFNaturalHighlighter.h"

#import "IFPreferences.h"

@implementation IFColourTheme

-(instancetype) init {
    self = [super init];
    if( self ) {
        self.options = [[NSMutableArray alloc] init];
        self.flags = [[NSNumber alloc] initWithInt:0];

        [self.options insertObject: [[IFSyntaxColouringOption alloc] init] atIndex: IFSHOptionHeadings];
        [self.options insertObject: [[IFSyntaxColouringOption alloc] init] atIndex: IFSHOptionMainText];
        [self.options insertObject: [[IFSyntaxColouringOption alloc] init] atIndex: IFSHOptionComments];
        [self.options insertObject: [[IFSyntaxColouringOption alloc] init] atIndex: IFSHOptionQuotedText];
        [self.options insertObject: [[IFSyntaxColouringOption alloc] init] atIndex: IFSHOptionTextSubstitutions];

        [self resetSettings];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    assert(self.themeName != nil);
    assert(self.flags != nil);
    assert(self.options != nil);
    assert(self.sourcePaper != nil);
    assert(self.extensionPaper != nil);

    for(int i = 0; i < self.options.count; i++) {
        assert(self.options[i] != nil);
    }

    [encoder encodeObject: self.themeName           forKey: @"themeName"];
    [encoder encodeObject: self.flags               forKey: @"flags"];
    [encoder encodeObject: (IFSyntaxColouringOption*) self.sourcePaper    forKey: @"sourcePaper"];
    [encoder encodeObject: (IFSyntaxColouringOption*) self.extensionPaper forKey: @"extensionPaper"];
    [encoder encodeInt:(int) self.options.count forKey: @"optionsCount"];
    for(int i = 0; i < self.options.count; i++) {
        NSString* keyName = [NSString stringWithFormat: @"option%d", i];
        [encoder encodeObject: (IFSyntaxColouringOption*) self.options[i] forKey: keyName];
    }
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self init]; // Call the designated initialiser first

    self.themeName           = [decoder decodeObjectOfClass: [NSString class] forKey: @"themeName"];
    self.flags               = [decoder decodeObjectOfClass: [NSNumber class] forKey: @"flags"];
    self.sourcePaper         = [decoder decodeObjectOfClass: [IFSyntaxColouringOption class] forKey: @"sourcePaper"];
    self.extensionPaper      = [decoder decodeObjectOfClass: [IFSyntaxColouringOption class] forKey: @"extensionPaper"];

    self.options             = [[NSMutableArray alloc] init];
    int optionsCount = [decoder decodeIntForKey: @"optionsCount"];
    for(int i = 0; i < optionsCount; i++) {
        NSString* keyName = [NSString stringWithFormat: @"option%d", i];
        IFSyntaxColouringOption* option = [decoder decodeObjectOfClass:[IFSyntaxColouringOption class] forKey: keyName];
        [self.options addObject: option];
    }

    return self;
}

+(BOOL) supportsSecureCoding {
    return YES;
}

-(void) resetSettings {
    self.sourcePaper.colour = [self.sourcePaper.defaultColour copy];
    self.extensionPaper.colour = [self.extensionPaper.defaultColour copy];

    for(int i = 0; i < self.options.count; i++) {
        self.options[i].colour = [self.options[i].defaultColour copy];
    //    NSLog(@"resetSettings New option %d is %@", i, self.options[i].defaultColour);
    }
}

-(IFColourTheme*) createDuplicateSet {
    IFColourTheme* result = [[IFColourTheme alloc] init];

    result.themeName = [self.themeName copy];
    result.extensionPaper = [self.extensionPaper copy];
    result.sourcePaper = [self.sourcePaper copy];
    result.flags = [self.flags copy];

    [result.options removeAllObjects];
    for (int i = 0; i < [self.options count]; i++) {
        [result.options addObject: [((IFSyntaxColouringOption *) self.options[i]) copy]];
    }
    return result;
}


-(void) updateAppPreferencesFromSetWithEnable:(BOOL) enable {
	IFPreferences* prefs = [IFPreferences sharedPreferences];

    [prefs setSourcePaper:    self.sourcePaper];
    [prefs setExtensionPaper: self.extensionPaper];
    [prefs setEnableSyntaxColouring: enable];

    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxColouringOption* option = (self.options)[optionIndex];
        [prefs setSourceColour:           option.colour           forOptionType: optionIndex];
    }
}

-(void) updateSetFromAppPreferences {
	IFPreferences* prefs = [IFPreferences sharedPreferences];
    
    self.sourcePaper    = [[prefs getSourcePaper] copy];
    self.extensionPaper = [[prefs getExtensionPaper] copy];
    self.flags          = [[prefs getCurrentTheme].flags copy];

    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxColouringOption * destOption = (self.options)[optionIndex];
        IFSyntaxColouringOption * prefsOption = [prefs sourcePaperForOptionType: optionIndex];
        destOption.colour        = [prefsOption.colour copy];
        destOption.defaultColour = [prefsOption.defaultColour copy];
    }
}

- (IFSyntaxColouringOption*) optionOfType:(IFSyntaxHighlightingOptionType) type {
    return (self.options)[(NSInteger) type];
}

-(BOOL) isEqualToColor: (NSColor*) color1
                  with: (NSColor*) color2 {
    NSColor *rgb1 = [color1
                     colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    NSColor *rgb2 = [color2
                     colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
    return rgb1 && rgb2 && [rgb1 isEqual:rgb2];
}

-(BOOL) isEqualToTheme:(IFColourTheme*) set {
    if( ![self isEqualToColor: self.sourcePaper.colour
                         with: set.sourcePaper.colour] ) {
        return NO;
    }
    if( ![self isEqualToColor: self.sourcePaper.defaultColour
                         with: set.sourcePaper.defaultColour] ) {
        return NO;
    }
    if( ![self isEqualToColor: self.extensionPaper.colour
                         with: set.extensionPaper.colour] ) {
        return NO;
    }
    if( ![self isEqualToColor: self.extensionPaper.defaultColour
                         with: set.extensionPaper.defaultColour] ) {
        return NO;
    }
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxColouringOption * option1 = (self.options)[optionIndex];
        IFSyntaxColouringOption * option2 = (set.options)[optionIndex];

        if( ![self isEqualToColor: option1.colour
                             with: option2.colour] ) {
            return NO;
        }
        if( ![self isEqualToColor: option1.defaultColour
                             with: option2.defaultColour] ) {
            return NO;
        }
    }

    return YES;
}

-(BOOL) isEqualToDefault {
    if( ![self isEqualToColor: self.sourcePaper.colour
                         with: self.sourcePaper.defaultColour] ) {
        return NO;
    }
    if( ![self isEqualToColor: self.extensionPaper.colour
                         with: self.extensionPaper.defaultColour] ) {
        return NO;
    }
    for( int optionIndex = IFSHOptionHeadings; optionIndex < IFSHOptionCount; optionIndex++ ) {
        IFSyntaxColouringOption * option = (self.options)[optionIndex];

        if(![self isEqualToColor: option.colour
                            with: option.defaultColour]) {
            return NO;
        }
    }
    return YES;
}

-(BOOL) isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[IFColourTheme class]]) {
        return NO;
    }
    if (![self isEqualToTheme:(IFColourTheme *)object]) {
        return NO;
    }
    return YES;
}

@end
