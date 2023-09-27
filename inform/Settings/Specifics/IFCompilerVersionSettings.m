//
//  IFCompilerVersionSettings.m
//  Inform
//
//  Created by Toby Nelson on 05/01/2019.
//  Copyright 2019 Toby Nelson. All rights reserved.
//

#import "IFCompilerVersionSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"
#import "Inform-Swift.h"

@implementation IFCompilerVersionSettings {
    IBOutlet NSPopUpButton* compilerVersionBox;
    IBOutlet NSTextField* descriptionText;
}

- (IBAction)compilerVersionChanged:(id)sender {
    IFCompilerListEntry* selectedEntry = [self getSelectedListEntryFromDisplayName: compilerVersionBox.stringValue];
    if (selectedEntry != nil)
    {
        [self updateDescription:selectedEntry];
        [self setSettings];
    }
}

- (void) updateDescription:(IFCompilerListEntry *) selectedEntry {
    if (selectedEntry == nil)
    {
        descriptionText.stringValue = @"";
    }
    else
    {
        descriptionText.stringValue = selectedEntry.description;
    }
}

- (instancetype) init {
	return [self initWithNibName: @"CompilerVersionSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Compiler Version Settings"];
}

#pragma mark - Setting up

-(IFCompilerListEntry *) getSelectedListEntryFromDisplayName: (NSString*) displayName {
    NSArray *list = [CompilerList compilerList];
    for(IFCompilerListEntry * entry in list)
    {
        if ([entry.displayName isEqualToString:compilerVersionBox.title])
        {
            return entry;
        }
    }
    return nil;
}

- (IFCompilerListEntry*) getSelectedListEntryFromId:(NSString*) currentSelectedId {
    NSArray *list = [CompilerList compilerList];
    IFCompilerListEntry *selectedEntry = nil;
    for(IFCompilerListEntry * entry in list)
    {
        [compilerVersionBox addItemWithTitle:entry.displayName];
        if ([entry.id isEqualToString: currentSelectedId])
        {
            selectedEntry = entry;
        }
    }

    if (selectedEntry == nil)
    {
        if (list.count > 0)
        {
            selectedEntry = list[0];
        }
    }
    return selectedEntry;
}

- (void) updateFromCompilerSettings {
    [compilerVersionBox removeAllItems];

    IFCompilerSettings* settings = self.compilerSettings;
    IFCompilerListEntry *selectedEntry = [self getSelectedListEntryFromId: settings.compilerVersion];
    if (selectedEntry != nil)
    {
        [compilerVersionBox setTitle: selectedEntry.displayName];
    }
    else
    {
        [compilerVersionBox setTitle: @""];
    }
    [self updateDescription: selectedEntry];
}

- (void) setSettings {
    IFCompilerSettings* settings = self.compilerSettings;
    IFCompilerListEntry* currentEntry = [self getSelectedListEntryFromDisplayName:compilerVersionBox.title];
    if (currentEntry != nil)
    {
        settings.compilerVersion = currentEntry.id;
    }
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings only apply to Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return YES;
	else
		return NO;
}

@end
