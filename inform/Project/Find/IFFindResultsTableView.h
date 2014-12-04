//
//  IFFindResultsTableView.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>


@protocol IFFindClickableTableViewDelegate <NSObject>

- (void)tableView:(NSTableView *)tableView didClickRow:(NSInteger)row;

@end

@interface IFFindResultsTableView : NSTableView {

IBOutlet id<IFFindClickableTableViewDelegate> extendedDelegate;

}
@property (nonatomic, weak) id<IFFindClickableTableViewDelegate> extendedDelegate;

@end