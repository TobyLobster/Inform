//
//  IFComboBox.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/05/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

///
/// NSComboBox variant that reports 'enter' keypresses to its delegate
///
@interface IFComboBox : NSComboBox {

}

@end

@interface NSObject(IFComboBoxDelegate)

- (void) comboBoxEnterKeyPress: (IFComboBox*) sender;

@end
