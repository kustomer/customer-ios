//
//  KUSPaginatedDataSource.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/22/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KUSUserSession;
@class KUSModel;
@protocol KUSPaginatedDataSourceListener;
@interface KUSPaginatedDataSource : NSObject

@property (nonatomic, readonly) BOOL isFetching;
@property (nonatomic, readonly) BOOL didFetch;
@property (nonatomic, readonly) BOOL didFetchAll;
@property (nonatomic, strong, readonly) NSError *error;

- (instancetype)initWithUserSession:(KUSUserSession *)userSession;
- (instancetype)init NS_UNAVAILABLE;

// Data methods
- (NSUInteger)count;
- (NSArray<__kindof KUSModel *> *)allObjects;
- (__kindof KUSModel *)objectWithId:(NSString *)oid;
- (__kindof KUSModel *)objectAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfObject:(__kindof KUSModel *)object;
- (__kindof KUSModel *)firstObject;
- (NSString *)_customerId;

// Listener methods
- (void)addListener:(id<KUSPaginatedDataSourceListener>)listener;
- (void)removeListener:(id<KUSPaginatedDataSourceListener>)listener;

// Request methods
- (void)fetchLatest;
- (void)fetchNext;
- (void)cancel;

@end

typedef NS_ENUM(NSUInteger, KUSPaginatedDataSourceChangeType) {
    KUSPaginatedDataSourceChangeInsert = 1,
    KUSPaginatedDataSourceChangeDelete = 2,
    KUSPaginatedDataSourceChangeMove = 3,
    KUSPaginatedDataSourceChangeUpdate = 4
};

@protocol KUSPaginatedDataSourceListener <NSObject>

@optional
- (void)paginatedDataSourceDidLoad:(KUSPaginatedDataSource *)dataSource;
- (void)paginatedDataSource:(KUSPaginatedDataSource *)dataSource didReceiveError:(NSError *)error;

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource;

@end
