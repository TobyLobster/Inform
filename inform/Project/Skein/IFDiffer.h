//
//  IFDiffer.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, EFormOfEdit) {
    DELETE_EDIT           = -1,
    PRESERVE_EDIT         =  0,
    PRESERVE_ACTUAL_EDIT  =  1,
    INSERT_EDIT           =  2
};

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

@property (atomic, nullable) NSString*       ideal;
@property (atomic, nullable) NSString*       actual;
@property (atomic) NSMutableArray<IFDiffEdit*>* differences;


-(BOOL) diffIdeal: (nullable NSString*) theIdeal
           actual: (nullable NSString*) theActual;

@end

NS_ASSUME_NONNULL_END
