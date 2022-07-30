//
//  IFNewThemeWindow.m
//  Inform
//
//  Created by Toby Nelson on 15/05/2022.
//

#import <Foundation/Foundation.h>
#import "IFNewThemeWindow.h"

@implementation IFNewThemeWindow {
    IBOutlet NSButton*      okButton;
    IBOutlet NSButton*      cancelButton;
    IBOutlet NSTextField*   nameField;

    NSString *              _themeName;
}

- (instancetype) init {
    self = [super init];

    if (self) {
    }
    return self;
}

-(NSString *) themeName {
    return _themeName;
}

-(void) setThemeName:(NSString *)theName {
    _themeName = theName;
    [nameField setStringValue: theName];
}

-(IBAction) okButtonClicked:(id) sender {
    self.themeName = [nameField stringValue];
    [NSApp endSheet:self returnCode: NSModalResponseOK];
}

-(IBAction) cancelButtonClicked:(id) sender {
    self.themeName = @"";
    [NSApp endSheet: self returnCode: NSModalResponseAbort];
}

@end
