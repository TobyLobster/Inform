//
//  IFColourPreferences.m
//  Inform
//
//  Created by Toby Nelson in 2022
//

#import "IFColourPreferences.h"

#import "IFSyntaxManager.h"
#import "IFNaturalHighlighter.h"

#import "IFPreferences.h"
#import "IFUtility.h"

@implementation IFColourPreferences {
    IBOutlet NSButton* enableSyntaxHighlighting;

    // Text section
    IBOutlet NSColorWell* sourceColour;
    IBOutlet NSColorWell* extensionColor;

    // Syntax highlighting section
    IBOutlet NSButton* restoreSettingsButton;
    IBOutlet NSColorWell* headingsColor;
    IBOutlet NSColorWell* mainTextColor;
    IBOutlet NSColorWell* commentsColor;
    IBOutlet NSColorWell* quotedTextColor;
    IBOutlet NSColorWell* textSubstitutionsColor;

    IBOutlet NSTextView* previewView;

    // Text storage for previews
    NSTextStorage* previewStorage;

    IFEditingPreferencesSet* defaultSet;
    IFEditingPreferencesSet* currentSet;
}


- (instancetype) init {
	self = [super initWithNibName: @"ColourPreferences"];

	if (self) {
        defaultSet = [[IFEditingPreferencesSet alloc] init];
        currentSet = [[IFEditingPreferencesSet alloc] init];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesEditingDidChangeNotification
												   object: [IFPreferences sharedPreferences]];

		// Create the preview
		NSTextStorage* oldStorage = [previewView textStorage];
		previewStorage = [[NSTextStorage alloc] initWithString: [oldStorage string]];
		[IFSyntaxManager registerTextStorage: previewStorage
                                        name: @"Colour Preferences (preview)"
                                        type: IFHighlightTypeInform7
                                intelligence: nil
                                 undoManager: nil];

        [previewView.layoutManager replaceTextStorage: previewStorage];

		[self reflectCurrentPreferences];
     }

	return self;
}

-(void) dealloc {
    [IFSyntaxManager unregisterTextStorage:previewStorage];
}

#pragma mark - PreferencePane overrides

- (NSString*) preferenceName {
	return @"Colour";
}

- (NSImage*) toolbarImage {
    return [[NSBundle bundleForClass: [self class]] imageForResource: @"App/paintpalette"];
}

- (NSString*) tooltip {
	return [IFUtility localizedString: @"Color preferences tooltip"];
}

#pragma mark - Receiving data from/updating the interface

-(void) updateDependentUIElements {
    bool enabled = ([enableSyntaxHighlighting state] == NSControlStateValueOn);

    [headingsColor              setEnabled: enabled];
    [mainTextColor              setEnabled: enabled];
    [commentsColor              setEnabled: enabled];
    [quotedTextColor            setEnabled: enabled];
    [textSubstitutionsColor     setEnabled: enabled];

    // Enable button
    [restoreSettingsButton setEnabled: ![currentSet isEqualToColorPreferenceSet:defaultSet]];
}

- (IBAction) styleSetHasChanged: (id) sender {
    // Update currentSet from preference pane
    {
        // Syntax highlighting section
        if (sender == enableSyntaxHighlighting)     currentSet.enableSyntaxHighlighting = ([enableSyntaxHighlighting state]==NSControlStateValueOn);

        // Text section
        if (sender == sourceColour)                 currentSet.sourcePaperColor         = [sourceColour color];
        if (sender == extensionColor)               currentSet.extensionPaperColor      = [extensionColor color];

        if (sender == headingsColor)                [[currentSet optionOfType: IFSHOptionHeadings]          setColour:     [headingsColor color]];
        if (sender == mainTextColor)                [[currentSet optionOfType: IFSHOptionMainText]          setColour:     [mainTextColor color]];
        if (sender == commentsColor)                [[currentSet optionOfType: IFSHOptionComments]          setColour:     [commentsColor color]];
        if (sender == quotedTextColor)              [[currentSet optionOfType: IFSHOptionQuotedText]        setColour:     [quotedTextColor color]];
        if (sender == textSubstitutionsColor)       [[currentSet optionOfType: IFSHOptionTextSubstitutions] setColour:     [textSubstitutionsColor color]];
    }

    // Update dependent UI elements
    if( sender == enableSyntaxHighlighting ) {
        [self updateDependentUIElements];
    }

    // Update application's preferences from currentSet
    [currentSet updateAppPreferencesFromSet];
}

- (void) reflectCurrentPreferences {
    // Update currentSet based on application's current preferences
    [currentSet updateSetFromAppPreferences];

    // Update preference pane UI elements from currentSet

    // Syntax highlighting section
    [enableSyntaxHighlighting setState: currentSet.enableSyntaxHighlighting ? NSControlStateValueOn : NSControlStateValueOff];

    // Text section
    [sourceColour setColor:   currentSet.sourcePaperColor];
    [extensionColor setColor: currentSet.extensionPaperColor];

    IFSyntaxHighlightingOption* option = (currentSet.options)[IFSHOptionHeadings];
    [headingsColor          setColor: option.colour];

    option = (currentSet.options)[IFSHOptionMainText];
    [mainTextColor          setColor: option.colour];

    option = (currentSet.options)[IFSHOptionComments];
    [commentsColor          setColor: option.colour];

    option = (currentSet.options)[IFSHOptionQuotedText];
    [quotedTextColor        setColor: option.colour];

    option = (currentSet.options)[IFSHOptionTextSubstitutions];
    [textSubstitutionsColor setColor: option.colour];

    // Update dependent elements
    [self updateDependentUIElements];
    
    // Rehighlight the preview views
	[IFSyntaxManager preferencesChanged: previewStorage];
	[IFSyntaxManager highlightAll: previewStorage
                  forceUpdateTabs: true];
}

- (IBAction) restoreDefaultSettings:(id) sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Restore"]];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Cancel"]];
    [alert setMessageText:     [IFUtility localizedString: @"Reset the colour preferences?"]];
    [alert setInformativeText: [IFUtility localizedString: @"This action cannot be undone."]];
    [alert setAlertStyle:NSAlertStyleWarning];

    if ([alert runModal] == NSAlertFirstButtonReturn ) {
        //currentSet = [[IFEditingPreferencesSet alloc] init];
        [currentSet resetColourSettings];

        [[IFPreferences sharedPreferences] startBatchEditing];
        [currentSet updateAppPreferencesFromSet];
        [[IFPreferences sharedPreferences] endBatchEditing];

        [self reflectCurrentPreferences];
    }
}

@end
