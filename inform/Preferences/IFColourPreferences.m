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
#import "NSBundle+IFBundleExtensions.h"
#import "Inform-Swift.h"

@implementation IFColourPreferences {
    IBOutlet NSButton*      enableSyntaxColouringButton;

    // Styles
    IBOutlet NSPopUpButton* styleButton;
    IBOutlet NSButton*      newStyleButton;
    IBOutlet NSButton*      deleteStyleButton;

    // Colours
    IBOutlet NSColorWell* sourceColour;
    IBOutlet NSColorWell* extensionColor;
    IBOutlet NSColorWell* headingsColor;
    IBOutlet NSColorWell* mainTextColor;
    IBOutlet NSColorWell* commentsColor;
    IBOutlet NSColorWell* quotedTextColor;
    IBOutlet NSColorWell* textSubstitutionsColor;
    IBOutlet NSButton* restoreSettingsButton;

    IBOutlet NSTextView* previewView;

    // Text storage for preview
    NSTextStorage* previewStorage;

    // New theme sheet
    IBOutlet IFNewThemeWindow* sheet;

    // Data
    bool                    enableSyntaxColouring;
    NSString*               currentThemeName;
    IFColourTheme*          currentSet;
}


- (instancetype) init {
	self = [super initWithNibName: @"ColourPreferences"];

	if (self) {
        currentSet = [[IFColourTheme alloc] init];
        [currentSet updateSetFromAppPreferences];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(reflectCurrentPreferences)
													 name: IFPreferencesEditingDidChangeNotification
												   object: [IFPreferences sharedPreferences]];

		// Create the preview
		NSTextStorage* oldStorage = previewView.textStorage;
		previewStorage = [[NSTextStorage alloc] initWithString: oldStorage.string];
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

- (CGFloat) maxHeight {
    return CGFLOAT_MAX;
}

- (CGFloat) minHeight {
    return 322.0;
}

#pragma mark - Receiving data from/updating the interface

-(void) updateDependentUIElements {
    bool enabled = (enableSyntaxColouringButton.state == NSControlStateValueOn);

    sourceColour.enabled = enabled;
    extensionColor.enabled = enabled;
    headingsColor.enabled = enabled;
    mainTextColor.enabled = enabled;
    commentsColor.enabled = enabled;
    quotedTextColor.enabled = enabled;
    textSubstitutionsColor.enabled = enabled;

    // Enable button
    restoreSettingsButton.enabled = !currentSet.equalToDefault;

    deleteStyleButton.enabled = (currentSet.flags.intValue & 1) == 1;
}

- (IBAction) newStyle: (id) sender {
    if (!self->sheet) {
        [NSBundle customLoadNib: @"NewThemeWindow"
                          owner: (id) self];
    }

    self->sheet.themeName = @"Custom";
    NSWindow * window = [PreferenceController sharedPreferenceController].window;
    [window beginSheet:self->sheet completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK) {
            NSString * name = self->sheet.themeName;
            IFPreferences* prefs = [IFPreferences sharedPreferences];

            // Try to add the theme
            IFColourTheme* newTheme = [self->currentSet createDuplicateSet];
            newTheme.themeName = name;

            // HACK: Set as deletable
            newTheme.flags = @(newTheme.flags.intValue | 1);

            if (![prefs addTheme: newTheme]) {
                [IFUtility runAlertWarningWindow: window
                                           title: [IFUtility localizedString:@"Name already used"]
                                         message: @"%@", [IFUtility localizedString:@"The name you have chosen is already used. Try another name."]];
            } else {
                // Select theme
                [prefs setCurrentTheme: newTheme.themeName];

                // Update from the preferences based on the new theme
                [self reflectCurrentPreferences];
            }

        }
    }];
    //[NSApp runModalForWindow: [self.sheet]];
}

- (IBAction) deleteStyle: (id) sender {
    // Ask for confirmation
    [IFUtility runAlertYesNoWindow: nil
                             title: [IFUtility localizedString: @"Are you sure?"]
                               yes: [IFUtility localizedString: @"Delete"]
                                no: [IFUtility localizedString: @"Cancel"]
                     modalDelegate: self
                    didEndSelector: @selector(confirmDidEnd:returnCode:contextInfo:)
                       contextInfo: nil
                  destructiveIndex: 0
                           message: @"%@", [IFUtility localizedString: @"Do you want to delete the current theme?"]];
}

- (void) confirmDidEnd:(NSWindow *)sheet returnCode:(NSModalResponse)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        IFPreferences* prefs = [IFPreferences sharedPreferences];
        if ([prefs removeTheme: prefs.currentThemeName]) {
            [prefs setCurrentTheme: @"Light Mode"];
        }
    }
}


- (IBAction) differentThemeChosen: (id) sender {
    NSMenuItem* selectedItem = styleButton.selectedItem;

    if (selectedItem != nil) {
        // Set the new name
        currentThemeName = selectedItem.title;

        // Get the theme from the preferences
        IFPreferences* prefs = [IFPreferences sharedPreferences];
        [prefs setCurrentTheme: currentThemeName];

        // Update from the preferences based on the new theme
        [self reflectCurrentPreferences];
    }
}

- (IBAction) styleSetHasChanged: (id) sender {
    // Update currentSet from preference pane
    {
        if (sender == enableSyntaxColouringButton)        enableSyntaxColouring = (enableSyntaxColouringButton.state==NSControlStateValueOn);

        if (sender == sourceColour)                 currentSet.sourcePaper.colour       = sourceColour.color;
        if (sender == extensionColor)               currentSet.extensionPaper.colour    = extensionColor.color;

        if (sender == headingsColor)                [currentSet optionOfType: IFSHOptionHeadings].colour = headingsColor.color;
        if (sender == mainTextColor)                [currentSet optionOfType: IFSHOptionMainText].colour = mainTextColor.color;
        if (sender == commentsColor)                [currentSet optionOfType: IFSHOptionComments].colour = commentsColor.color;
        if (sender == quotedTextColor)              [currentSet optionOfType: IFSHOptionQuotedText].colour = quotedTextColor.color;
        if (sender == textSubstitutionsColor)       [currentSet optionOfType: IFSHOptionTextSubstitutions].colour = textSubstitutionsColor.color;
    }

    // Update dependent UI elements
    if( sender == enableSyntaxColouringButton ) {
        [self updateDependentUIElements];
    }

    // Update application's preferences from currentSet
    [currentSet updateAppPreferencesFromSetWithEnable: enableSyntaxColouring];
}

- (void) reflectCurrentPreferences {
    // Get current theme settings from preferences
    IFPreferences* prefs = [IFPreferences sharedPreferences];
    currentThemeName = prefs.currentThemeName;
    NSArray* names = prefs.themeNames;
    [styleButton removeAllItems];
    [styleButton addItemsWithTitles: names];
    [styleButton selectItemWithTitle: prefs.currentThemeName];

    enableSyntaxColouring = prefs.enableSyntaxColouring;

    // Update currentSet based on application's current preferences
    [currentSet updateSetFromAppPreferences];

    // Update preference pane UI elements from currentSet

    enableSyntaxColouringButton.state = enableSyntaxColouring ? NSControlStateValueOn : NSControlStateValueOff;
    sourceColour.color = currentSet.sourcePaper.colour;
    extensionColor.color = currentSet.extensionPaper.colour;

    IFSyntaxColouringOption* option = (currentSet.options)[IFSHOptionHeadings];
    headingsColor.color = option.colour;

    option = (currentSet.options)[IFSHOptionMainText];
    mainTextColor.color = option.colour;

    option = (currentSet.options)[IFSHOptionComments];
    commentsColor.color = option.colour;

    option = (currentSet.options)[IFSHOptionQuotedText];
    quotedTextColor.color = option.colour;

    option = (currentSet.options)[IFSHOptionTextSubstitutions];
    textSubstitutionsColor.color = option.colour;

    // Update dependent elements
    [self updateDependentUIElements];

    // Update paper colour on preview
    previewView.backgroundColor = currentSet.sourcePaper.colour;

    // Rehighlight the preview views
	[IFSyntaxManager preferencesChanged: previewStorage];
	[IFSyntaxManager highlightAll: previewStorage
                  forceUpdateTabs: true];
}

- (IBAction) restoreDefaultSettings:(id) sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Restore"]];
    [alert addButtonWithTitle: [IFUtility localizedString: @"Cancel"]];
    alert.messageText = [IFUtility localizedString: @"Reset the current colours back to their original values?"];
    alert.informativeText = [IFUtility localizedString: @"This action cannot be undone."];
    alert.alertStyle = NSAlertStyleWarning;

    if ([alert runModal] == NSAlertFirstButtonReturn ) {
        [currentSet resetSettings];

        enableSyntaxColouring = true;

        [[IFPreferences sharedPreferences] startBatchEditing];
        [currentSet updateAppPreferencesFromSetWithEnable: true];
        [[IFPreferences sharedPreferences] endBatchEditing];

        [self reflectCurrentPreferences];
    }
}

@end
