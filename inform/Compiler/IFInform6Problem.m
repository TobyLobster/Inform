//
//  IFInform6Problem.m
//  Inform
//
//  Created by Andrew Hunter on 06/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFInform6Problem.h"


@implementation IFInform6Problem

- (NSURL*) urlForProblemWithErrorCode: (int) errorCode {
	return [NSURL URLWithString: @"inform:/ErrorI6.html"];
}

@end
