//
//  RACCommand.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RACSubject.h"


// A command is a value that allows more customization of its behavior.
// It sends `next` events when the command executes. `next` is sent the value
// passed into `-execute:`.
@interface RACCommand : RACSubject

// Whether or not this command can currently execute. If the command was created
// with a can execute subscribable, this will be the latest value sent on that
// subscribable. Otherwise this will always be YES. It is both KVO- and
// KVC-compliant. Users can binding a subscribable to this property if needed.
@property (readonly) BOOL canExecute;

// Creates a new command that can always be executed and has no execution block.
+ (instancetype)command;

// Creates a new command with the given execution block. `canExecute` will
// always be YES.
+ (instancetype)commandWithBlock:(void (^)(id sender))block;

// Creates a new command with the given execution block. `subscribable` should
// be a subscribable that sends NSNumber-wrapped BOOLs. The `canExecute`
// property will be set to the boolValue of the latest value received from the
// subscribable.
+ (instancetype)commandWithCanExecuteSubscribable:(id<RACSubscribable>)subscribable block:(void (^)(id sender))block;

// Initializes a new command with the given execution block and can execute
// subscribable. Both can be nil.
- (id)initWithCanExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable block:(void (^)(id sender))block;

// If `canExecute` is YES, executes the receiver's block with the given sender
// and returns YES. Otherwise, returns NO.
- (BOOL)execute:(id)sender;

@end
