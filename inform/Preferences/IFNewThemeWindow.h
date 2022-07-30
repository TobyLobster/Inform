//
//  IFNewThemeWindow.h
//  Inform
//
//  Created by Toby Nelson on 15/05/2022.
//

#ifndef IFNewThemeWindow_h
#define IFNewThemeWindow_h

@interface IFNewThemeWindow : NSWindow

-(IBAction) okButtonClicked:(id) sender;
-(IBAction) cancelButtonClicked:(id) sender;

@property (atomic, copy) NSString*      themeName;

@end

#endif /* IFNewThemeWindow_h */
