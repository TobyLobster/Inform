//
//  IFDiffer.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>

typedef enum EFormOfEdit {
    DELETE_EDIT           = -1,
    PRESERVE_EDIT         =  0,
    PRESERVE_ACTUAL_EDIT  =  1,
    INSERT_EDIT           =  2
} EFormOfEdit;

// *******************************************************************************************
@interface IFDiffEdit : NSObject {
@public
    NSRange     fragment;
    EFormOfEdit formOfEdit;
}

-(instancetype) initWithRange: (NSRange) range
                         form: (EFormOfEdit) form;

@end

// *******************************************************************************************
@interface IFDiffer : NSObject

@property (atomic) NSString*       ideal;
@property (atomic) NSString*       actual;
@property (atomic) NSMutableArray* differences;


-(BOOL) diffIdeal: (NSString*) theIdeal
           actual: (NSString*) theActual;

@end
