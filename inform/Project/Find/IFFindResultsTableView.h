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

@interface IFFindResultsTableView : NSTableView

@property (nonatomic,strong) id<IFFindClickableTableViewDelegate> extendedDelegate;

@end
