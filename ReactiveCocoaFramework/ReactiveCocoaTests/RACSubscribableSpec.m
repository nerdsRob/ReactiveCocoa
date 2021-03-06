//
//  RACSubscribableSpc.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"

#import "EXTKeyPathCoding.h"
#import "RACSubscribable.h"
#import "RACSubscriber.h"
#import "RACSubject.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACUnit.h"
#import "RACTuple.h"
#import "RACScheduler.h"
#import "RACTestObject.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACPropertySubscribableExamples.h"
#import "RACAsyncSubject.h"

static NSString * const RACSubscribableMergeConcurrentCompletionExampleGroup = @"RACSubscribableMergeConcurrentCompletionExampleGroup";
static NSString * const RACSubscribableMaxConcurrent = @"RACSubscribableMaxConcurrent";
SharedExampleGroupsBegin(mergeConcurrentCompletionName);

sharedExamplesFor(RACSubscribableMergeConcurrentCompletionExampleGroup, ^(NSDictionary *data) {
	it(@"should complete only after the source and all its subscribables have completed", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];
		RACSubject *subject3 = [RACSubject subject];

		RACSubject *subscribablesSubject = [RACSubject subject];
		__block BOOL completed = NO;
		[[subscribablesSubject merge:[data[RACSubscribableMaxConcurrent] unsignedIntegerValue]] subscribeCompleted:^{
			completed = YES;
		}];

		[subscribablesSubject sendNext:subject1];
		[subject1 sendCompleted];

		expect(completed).to.beFalsy();

		[subscribablesSubject sendNext:subject2];
		[subscribablesSubject sendNext:subject3];

		[subscribablesSubject sendCompleted];

		expect(completed).to.beFalsy();

		[subject2 sendCompleted];

		expect(completed).to.beFalsy();

		[subject3 sendCompleted];

		expect(completed).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SpecBegin(RACSubscribable)

describe(@"subscribing", ^{
	__block RACSubscribable *subscribable = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should get next values", ^{
		__block id nextValueReceived = nil;
		[subscribable subscribeNext:^(id x) {
			nextValueReceived = x;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(nextValueReceived).to.equal(nextValueSent);
	});
	
	it(@"should get completed", ^{
		__block BOOL didGetCompleted = NO;
		[subscribable subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			
		} completed:^{
			didGetCompleted = YES;
		}];
		
		expect(didGetCompleted).to.beTruthy();
	});
	
	it(@"should not get an error", ^{
		__block BOOL didGetError = NO;
		[subscribable subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			didGetError = YES;
		} completed:^{
			
		}];
		
		expect(didGetError).to.beFalsy();
	});
	
	it(@"shouldn't get anything after dispose", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACDisposable *disposable = [subject subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];
		
		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];
		
		[disposable dispose];
		
		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});

	it(@"should support -takeUntil:", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];

		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];

		[cutOffSubject sendNext:[RACUnit defaultUnit]];

		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});
});

describe(@"querying", ^{
	__block RACSubscribable *subscribable = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendNext:@"other value"];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should support where", ^{
		__block BOOL didGetCallbacks = NO;
		[[subscribable where:^BOOL(id x) {
			return x == nextValueSent;
		}] subscribeNext:^(id x) {
			expect(x).to.equal(nextValueSent);
			didGetCallbacks = YES;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(didGetCallbacks).to.beTruthy();
	});
	
	it(@"should support select", ^{
		__block BOOL didGetCallbacks = NO;
		id transformedValue = @"other";
		[[subscribable select:^(id x) {			
			return transformedValue;
		}] subscribeNext:^(id x) {
			expect(x).to.equal(transformedValue);
			didGetCallbacks = YES;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(didGetCallbacks).to.beTruthy();
	});
	
	it(@"should support window", ^{
		RACSubscribable *subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@"1"];
			[subscriber sendNext:@"2"];
			[subscriber sendNext:@"3"];
			[subscriber sendNext:@"4"];
			[subscriber sendNext:@"5"];
			[subscriber sendCompleted];
			return nil;
		}];
		
		RACBehaviorSubject *windowOpen = [RACBehaviorSubject behaviorSubjectWithDefaultValue:@""];
		
		RACSubject *closeSubject = [RACSubject subject];
		__block NSUInteger valuesReceived = 0;
		
		RACSubscribable *window = [subscribable windowWithStart:windowOpen close:^(id<RACSubscribable> start) {
			return closeSubject;
		}];
				
		[window subscribeNext:^(id x) {			
			[x subscribeNext:^(id x) {
				valuesReceived++;
				NSLog(@"got: %@", x);
				
				if(valuesReceived % 2 == 0) {
					[closeSubject sendNext:x];
					[windowOpen sendNext:@""];
				}
			} error:^(NSError *error) {
				
			} completed:^{
				
			}];
		} error:^(NSError *error) {
			
		} completed:^{
			NSLog(@"completed");
		}];
	});
	
	it(@"should support take", ^{
		@autoreleasepool {
			RACSubscribable *subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
				[subscriber sendNext:@"1"];
				[subscriber sendNext:@"2"];
				[subscriber sendNext:@"3"];
				[subscriber sendNext:@"4"];
				[subscriber sendNext:@"5"];
				[subscriber sendCompleted];
				return nil;
			}];
			
			RACSubscriber *ob = [RACSubscriber subscriberWithNext:NULL error:NULL completed:NULL];
			
			@autoreleasepool {
				[subscribable subscribe:ob];
			}
			
			NSLog(@"d");
		}
	});
	
	it(@"should return first 'next' value with -firstOrDefault:success:error:", ^{
		RACSubscribable *subscribable = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendCompleted];
			return nil;
		}];

		expect(subscribable).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([subscribable firstOrDefault:@5 success:&success error:&error]).to.equal(@1);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return first default value with -firstOrDefault:success:error:", ^{
		RACSubscribable *subscribable = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendCompleted];
			return nil;
		}];

		expect(subscribable).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([subscribable firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return error with -firstOrDefault:success:error:", ^{
		NSError *testError = [NSError errorWithDomain:@"foo" code:100 userInfo:nil];
		RACSubscribable *subscribable = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendError:testError];
			return nil;
		}];

		expect(subscribable).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([subscribable firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(testError);
	});
});

describe(@"continuation", ^{
	it(@"shouldn't receive deferred errors", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACSubscribable *subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			if(numberOfSubscriptions > 2) {
				[subscriber sendCompleted];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[subscriber sendNext:@"1"];
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			[subscriber sendCompleted];
			return nil;
		}];
		
		__block BOOL gotNext = NO;
		__block BOOL gotError = NO;
		[[subscribable asMaybes] subscribeNext:^(id x) {
			gotNext = YES;
		} error:^(NSError *error) {
			gotError = YES;
		} completed:^{
			
		}];
		
		expect(gotNext).to.beTruthy();
		expect(gotError).to.beFalsy();
	});
	
	it(@"should repeat after completion", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACSubscribable *subscribable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			if(numberOfSubscriptions > 2) {
				[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[subscriber sendNext:@"1"];
			[subscriber sendCompleted];
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return nil;
		}];
		
		__block NSUInteger nextCount = 0;
		__block BOOL gotCompleted = NO;
		[[subscribable repeat] subscribeNext:^(id x) {
			nextCount++;
		} error:^(NSError *error) {
			
		} completed:^{
			gotCompleted = YES;
		}];
		
		expect(nextCount).to.beGreaterThan(1);
		expect(gotCompleted).to.beFalsy();
	});
});

describe(@"combineLatest", ^{
	__block id<RACSubscriber> subscriber1 = nil;
	__block id<RACSubscriber> subscriber2 = nil;
	__block RACSubscribable *subscribable1 = nil;
	__block RACSubscribable *subscribable2 = nil;
	__block RACSubscribable *combined = nil;
	
	beforeEach(^{
		subscribable1 = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			subscriber1 = subscriber;
			return nil;
		}],
		subscribable2 = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			subscriber2 = subscriber;
			return nil;
		}],
		combined = [RACSubscribable combineLatest:@[ subscribable1, subscribable2 ]];
	});
	
	it(@"should yield when all sources yield", ^{
		__block id result;
		
		[combined subscribeNext:^(id x) {
			result = x;
		}];
		
		[subscriber1 sendNext:@"1"];
		[subscriber2 sendNext:@"2"];
		
		expect(result).to.beKindOf([RACTuple class]);
		RACTuple *tuple = result;
		expect(tuple.first).to.equal(@"1");
		expect(tuple.second).to.equal(@"2");
	});
	
	it(@"should not yield when some sources have not yielded", ^{
		__block id result;
		
		[combined subscribeNext:^(id x) {
			result = x;
		}];
		
		[subscriber1 sendNext:@"1"];
		
		expect(result).to.beNil();
	});
	
	it(@"should yield multiple times when any sources yield multiple times", ^{
		NSMutableArray *results = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[results addObject:x];
		}];
		
		[subscriber1 sendNext:@"1"];
		[subscriber2 sendNext:@"2"];
		
		[subscriber1 sendNext:@"3"];
		[subscriber2 sendNext:@"4"];
		
		RACTuple *result1 = [results objectAtIndex:0];
		expect(result1.first).to.equal(@"1");
		expect(result1.second).to.equal(@"2");
		
		RACTuple *result2 = [results objectAtIndex:1];
		expect(result2.first).to.equal(@"3");
		expect(result2.second).to.equal(@"2");
		
		RACTuple *result3 = [results objectAtIndex:2];
		expect(result3.first).to.equal(@"3");
		expect(result3.second).to.equal(@"4");
	});
	
	it(@"should complete when all sources complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];
		
		[subscriber1 sendCompleted];
		[subscriber2 sendCompleted];
		
		expect(completed).to.beTruthy();
	});
	
	it(@"should not complete when some sources are not complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];
		
		[subscriber1 sendCompleted];
		
		expect(completed).to.beFalsy();
	});
	
	it(@"should error when a source errors", ^{
		__block BOOL gotError = NO;
		
		[combined subscribeError:^(NSError *error) {
			gotError = YES;
		}];
		
		[subscriber1 sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		
		expect(gotError).to.beTruthy();
	});
	
	it(@"should error multiple times when multiple sources error", ^{
		__block int errorCount = 0;
		
		[combined subscribeError:^(NSError *error) {
			errorCount++;
		}];
		
		[subscriber1 sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		[subscriber2 sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		
		expect(errorCount).to.equal(2);
	});
});

describe(@"distinctUntilChanged", ^{
	it(@"should only send values that are distinct from the previous value", ^{
		RACSubscribable *sub = [[RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@2];
			[subscriber sendNext:@1];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ @1, @2, @1 ];
		expect(values).to.equal(expected);
	});

	it(@"shouldn't consider nils to always be distinct", ^{
		RACSubscribable *sub = [[RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ @1, [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});

	it(@"should consider initial nil to be distinct", ^{
		RACSubscribable *sub = [[RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});
});

describe(@"RACAbleWithStart", ^{
	__block RACTestObject *testObject;

	beforeEach(^{
		testObject = [[RACTestObject alloc] init];
	});

	it(@"should work with object properties", ^{
		NSArray *expected = @[ @"hello", @"world" ];
		testObject.objectValue = expected[0];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACAbleWithStart(testObject, objectValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.objectValue = expected[1];

		expect(valuesReceived).to.equal(expected);
	});

	it(@"should work with non-object properties", ^{
		NSArray *expected = @[ @42, @43 ];
		testObject.integerValue = [expected[0] integerValue];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACAbleWithStart(testObject, integerValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.integerValue = [expected[1] integerValue];

		expect(valuesReceived).to.equal(expected);
	});
});

describe(@"-scanWithStart:combine:", ^{
	it(@"should send each step in the fold", ^{
		RACSubscribable *subscribable = [[RACSubscribable createSubscribable:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendNext:@4];
			[subscriber sendCompleted];
			return nil;
		}] scanWithStart:@0 combine:^(NSNumber *running, NSNumber *next) {
			return @(running.integerValue + next.integerValue);
		}];
		
		NSArray *values = subscribable.toArray;
		NSArray *expected = @[ @0, @1, @3, @6, @10 ];
		expect(values).to.equal(expected);
	});
});

describe(@"-toProperty:onObject:", ^{
	void (^setupBlock)(RACTestObject *, NSString *, RACSubject *) = ^(RACTestObject *testObject, NSString *keyPath, RACSubject *subject) {
		[subject toProperty:keyPath onObject:testObject];
	};

	itShouldBehaveLike(RACPropertySubscribableExamples, @{ RACPropertySubscribableExamplesSetupBlock: setupBlock });

	it(@"shouldn't send values to dealloc'd objects", ^{
		RACSubject *subject = [RACSubject subject];
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[subject toProperty:@keypath(testObject.objectValue) onObject:testObject];
			expect(testObject.objectValue).to.beNil();

			[subject sendNext:@1];
			expect(testObject.objectValue).to.equal(@1);

			[subject sendNext:@2];
			expect(testObject.objectValue).to.equal(@2);
		}

		// This shouldn't do anything.
		[subject sendNext:@3];
	});
});

describe(@"deallocation", ^{
	it(@"should dealloc subscribables if the subscribable does nothing", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACSubscribable *subscribable __attribute__((objc_precise_lifetime)) = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
				return nil;
			}];

			[subscribable rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
		}

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc subscribables if the subscribable immediately completes", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			__block BOOL done = NO;

			RACSubscribable *subscribable __attribute__((objc_precise_lifetime)) = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
				[subscriber sendCompleted];
				return nil;
			}];

			[subscribable rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];

			[subscribable subscribeCompleted:^{
				done = YES;
			}];

			expect(done).will.beTruthy();
		}
		
		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc an async subject if it completes immediately", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACAsyncSubject *subject __attribute__((objc_precise_lifetime)) = [RACAsyncSubject subject];
			[subject sendCompleted];

			[subject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];

			[subject subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(completed).will.beTruthy();

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc if the subscribable was created on a background queue", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[RACScheduler.backgroundScheduler schedule:^{
				RACSubscribable *subscribable __attribute__((objc_precise_lifetime)) = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
					[subscriber sendCompleted];
					return nil;
				}];

				[subscribable rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				[subscribable subscribeCompleted:^{
					completed = YES;
				}];
			}];
		}

		expect(completed).will.beTruthy();

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc if the subscribable was created on a background queue, never gets any subscribers, and the background queue gets delayed", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[RACScheduler.backgroundScheduler schedule:^{
				RACSubscribable *subscribable __attribute__((objc_precise_lifetime)) = [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
					return nil;
				}];

				[subscribable rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				[NSThread sleepForTimeInterval:1];

				expect(deallocd).to.beFalsy();
			}];
		}

		// The default test timeout is 1s so we'd race to see if the queue delay
		// or default timeout happens first. To avoid that, just bump the
		// timeout slightly for this test.
		NSTimeInterval originalTestTimeout = Expecta.asynchronousTestTimeout;
		Expecta.asynchronousTestTimeout = 1.1f;
		expect(deallocd).will.beTruthy();
		Expecta.asynchronousTestTimeout = originalTestTimeout;
	});
});

describe(@"+merge:", ^{
	__block RACSubject *sub1;
	__block RACSubject *sub2;
	__block RACSubscribable *merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [RACSubscribable merge:@[ sub1, sub2 ]];
	});

	it(@"should send all values from both subscribables", ^{
		NSMutableArray *values = [NSMutableArray array];
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub1 sendNext:@4];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send an error if one occurs", ^{
		__block NSError *errorReceived;
		[merged subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		NSError *error = [NSError errorWithDomain:@"" code:0 userInfo:nil];
		[sub1 sendError:error];

		expect(errorReceived).to.equal(error);
	});

	it(@"should complete only after both subscribables complete", ^{
		NSMutableArray *values = [NSMutableArray array];
		__block BOOL completed = NO;
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub2 sendCompleted];
		expect(completed).to.beFalsy();

		[sub1 sendNext:@4];
		[sub1 sendCompleted];
		expect(completed).to.beTruthy();

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});
});

describe(@"-merge:", ^{
	__block BOOL subscribedTo1 = NO;
	__block BOOL subscribedTo2 = NO;
	__block BOOL subscribedTo3 = NO;
	__block RACSubscribable *sub1;
	__block RACSubscribable *sub2;
	__block RACSubscribable *sub3;
	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;
	__block RACSubject *subscribablesSubject;
	__block NSMutableArray *values;
	
	beforeEach(^{
		subscribedTo1 = NO;
		subject1 = [RACSubject subject];
		sub1 = [RACSubscribable defer:^{
			subscribedTo1 = YES;
			return subject1;
		}];

		subscribedTo2 = NO;
		subject2 = [RACSubject subject];
		sub2 = [RACSubscribable defer:^{
			subscribedTo2 = YES;
			return subject2;
		}];

		subscribedTo3 = NO;
		subject3 = [RACSubject subject];
		sub3 = [RACSubscribable defer:^{
			subscribedTo3 = YES;
			return subject3;
		}];

		subscribablesSubject = [RACSubject subject];

		values = [NSMutableArray array];
	});

	describe(@"when its max is 0", ^{
		it(@"should merge all the subscribables concurrently", ^{
			[[subscribablesSubject merge:0] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribedTo1).to.beFalsy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subscribablesSubject sendNext:sub1];
			[subscribablesSubject sendNext:sub2];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendNext:@1];

			[subscribablesSubject sendNext:sub3];
			
			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beTruthy();

			[subject1 sendCompleted];

			[subject2 sendNext:@2];
			[subject2 sendCompleted];

			[subject3 sendNext:@3];
			[subject3 sendCompleted];

			NSArray *expected = @[ @1, @2, @3 ];
			expect(values).to.equal(expected);
		});

		itShouldBehaveLike(RACSubscribableMergeConcurrentCompletionExampleGroup, @{ RACSubscribableMaxConcurrent: @0 });
	});

	describe(@"when its max is > 0", ^{
		it(@"should merge only the given number at a time", ^{
			[[subscribablesSubject merge:1] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribedTo1).to.beFalsy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subscribablesSubject sendNext:sub1];
			[subscribablesSubject sendNext:sub2];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendNext:@1];

			[subscribablesSubject sendNext:sub3];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subscribablesSubject sendCompleted];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendCompleted];

			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beFalsy();

			[subject2 sendNext:@2];
			[subject2 sendCompleted];

			expect(subscribedTo3).to.beTruthy();

			[subject3 sendNext:@3];
			[subject3 sendCompleted];

			NSArray *expected = @[ @1, @2, @3 ];
			expect(values).to.equal(expected);
		});

		itShouldBehaveLike(RACSubscribableMergeConcurrentCompletionExampleGroup, @{ RACSubscribableMaxConcurrent: @1 });
	});
});

describe(@"-switch", ^{
	it(@"should send values from the most recent subscribable", ^{
		RACSubject *subject = [RACSubject subject];
		NSMutableArray *values = [NSMutableArray array];
		[[subject switch] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[subject sendNext:[RACSubscribable createSubscribable:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			return nil;
		}]];

		[subject sendNext:[RACSubscribable createSubscribable:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@3];
			[subscriber sendNext:@4];
			[subscriber sendCompleted];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should accept nil subscribables", ^{
		RACSubject *subject = [RACSubject subject];
		NSMutableArray *values = [NSMutableArray array];
		[[subject switch] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[subject sendNext:nil];

		[subject sendNext:[RACSubscribable createSubscribable:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendCompleted];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2 ];
		expect(values).to.equal(expected);
	});
});

describe(@"+interval:", ^{
	static const NSTimeInterval interval = 0.1;
	void (^expectItToWorkWithScheduler)(RACScheduler *) = ^(RACScheduler *scheduler) {
		__block volatile int32_t nextsReceived = 0;
		[scheduler schedule:^{
			__block NSTimeInterval lastTime = NSDate.timeIntervalSinceReferenceDate;
			[[[RACSubscribable interval:interval] take:3] subscribeNext:^(id _) {
				NSTimeInterval currentTime = NSDate.timeIntervalSinceReferenceDate;
				expect(currentTime - lastTime).beGreaterThanOrEqualTo(interval);

				OSAtomicAdd32Barrier(1, &nextsReceived);
			}];
		}];

		expect(nextsReceived).will.equal(3);
	};

	it(@"should fire repeatedly at every interval", ^{
		expectItToWorkWithScheduler(RACScheduler.mainQueueScheduler);
	});

	it(@"should work on a background scheduler", ^{
		expectItToWorkWithScheduler(RACScheduler.backgroundScheduler);
	});
});

describe(@"-sequenceNext:", ^{
	it(@"should continue onto returned subscribable", ^{
		RACSubject *subject = [RACSubject subject];

		__block id value = nil;
		[[subject sequenceNext:^{
			return [RACSubscribable return:@2];
		}] subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendNext:@1];

		// The value shouldn't change until the first subscribable completes.
		expect(value).to.beNil();

		[subject sendCompleted];

		expect(value).to.equal(@2);
	});

	it(@"should sequence even if no next value is sent", ^{
		RACSubject *subject = [RACSubject subject];

		__block id value = nil;
		[[subject sequenceNext:^{
			return [RACSubscribable return:RACUnit.defaultUnit];
		}] subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendCompleted];

		expect(value).to.equal(RACUnit.defaultUnit);
	});
});

SpecEnd
