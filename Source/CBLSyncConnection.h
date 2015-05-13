//
//  CBLSyncConnection.h
//  Couchbase Lite
//
//  Created by Jens Alfke on 4/1/15.
//  Copyright (c) 2015 Couchbase. All rights reserved.
//

#import "BLIPConnection.h"
#import <CouchbaseLite/CBLDatabase.h>


typedef NS_ENUM(unsigned, SyncState) {
    kSyncStopped,
    kSyncConnecting,
    kSyncIdle,
    kSyncActive,
};


@interface CBLSyncConnection : NSObject <BLIPConnectionDelegate>

- (instancetype) initWithDatabase: (CBLDatabase*)db
                       connection: (BLIPConnection*)connection
                            queue: (dispatch_queue_t)queue;

- (void) push: (BOOL)push pull: (BOOL)pull continuously: (BOOL)continuously;

- (void) setPushFilter: (CBLFilterBlock)filter params: (NSDictionary*)params;
- (void) setPullFilter: (NSString*)filterName params: (NSDictionary*)params;

- (void) close;

@property (copy) NSString* remoteCheckpointDocID;

@property (readonly) dispatch_queue_t syncQueue;
@property (readonly) NSURL* peerURL;

// The below properties are observable, but the changes happen on the syncQueue

@property (readonly) SyncState state;
@property (readonly) NSError* error;

@property (readonly) NSProgress* pullProgress;
@property (readonly, copy) NSArray* nestedPullProgress;

@property (readonly) NSProgress* pushProgress;
@property (readonly, copy) NSArray* nestedPushProgress;

@end


extern NSString* const kSyncNestedProgressKey;
