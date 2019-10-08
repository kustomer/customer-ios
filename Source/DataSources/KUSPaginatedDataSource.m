//
//  KUSPaginatedDataSource.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/22/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSPaginatedDataSource.h"
#import "KUSPaginatedDataSource_Private.h"

#import "KUSPaginatedResponse.h"

@interface KUSPaginatedDataSource () {
    NSMutableArray<KUSModel *> *_fetchedModels;
    NSMutableDictionary<NSString *, KUSModel *> *_fetchedModelsById;

    KUSPaginatedResponse *_mostRecentPaginatedResponse;
    KUSPaginatedResponse *_lastPaginatedResponse;
}

@property (nonatomic, weak, readwrite) KUSUserSession *userSession;
@property (nonatomic, strong, readwrite) NSHashTable<id<KUSPaginatedDataSourceListener>> *listeners;

@property (nonatomic, readwrite) BOOL isFetching;
@property (nonatomic, readwrite) BOOL didFetch;
@property (nonatomic, readwrite) BOOL didFetchAll;
@property (nonatomic, strong, readwrite) NSError *error;

@property (nonatomic, strong, nullable) NSObject *requestMarker;

@end

@implementation KUSPaginatedDataSource

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;

        _listeners = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];

        _fetchedModels = [[NSMutableArray alloc] init];
        _fetchedModelsById = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Public methods

- (NSUInteger)count
{
    return [_fetchedModels count];
}

- (NSArray<__kindof KUSModel *> *)allObjects
{
    return [_fetchedModels copy];
}

- (__kindof KUSModel *)objectWithId:(NSString *)oid
{
    return [_fetchedModelsById objectForKey:oid];
}

- (__kindof KUSModel *)objectAtIndex:(NSUInteger)index
{
    return [_fetchedModels objectAtIndex:index];
}

- (NSUInteger)indexOfObject:(__kindof KUSModel *)object
{
    return [self _indexOfObjectId:object.oid];
}

- (__kindof KUSModel *)firstObject
{
    return [_fetchedModels firstObject];
}

- (NSUInteger)_indexOfObjectId:(NSString *)objectId
{
    if (objectId == nil) {
        return NSNotFound;
    }
    KUSModel *internalObject = [self objectWithId:objectId];
    if (internalObject == nil) {
        return NSNotFound;
    }
    return [_fetchedModels indexOfObjectIdenticalTo:internalObject];
}

- (NSString *)_customerId
{
    for (int i = 0; i < self.count; i++) {
        if (self.allObjects[i].customerId) {
            return self.allObjects[i].customerId;
        }
    }
    return nil;
}

#pragma mark - Listener methods

- (void)addListener:(id<KUSPaginatedDataSourceListener>)listener
{
    [self.listeners addObject:listener];
}

- (void)removeListener:(id<KUSPaginatedDataSourceListener>)listener
{
    [self.listeners removeObject:listener];
}

#pragma mark - Fetch methods

- (void)fetchLatest
{
    NSURL *URL = [self firstURL];
    if (_mostRecentPaginatedResponse.firstPath) {
        URL = [self.userSession.requestManager URLForEndpoint:_mostRecentPaginatedResponse.firstPath];
    }
    if (URL == nil) {
        return;
    }
    if (self.isFetching) {
        return;
    }
    self.isFetching = YES;
    self.error = nil;

    NSObject *requestMarker = [[NSObject alloc] init];
    self.requestMarker = requestMarker;

    __weak KUSPaginatedDataSource *weakSelf = self;
    Class modelClass = [self modelClass];

    [self.userSession.requestManager
     performRequestType:KUSRequestTypeGet
     URL:URL
     params:nil
     authenticated:YES
     completion:^(NSError *error, NSDictionary *json) {
         dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
             KUSPaginatedResponse *response = [[KUSPaginatedResponse alloc] initWithJSON:json modelClass:modelClass];
             dispatch_async(dispatch_get_main_queue(), ^{
                 __strong KUSPaginatedDataSource *strongSelf = weakSelf;
                 // Check to make sure that the request marker did not change
                 if (strongSelf == nil || strongSelf.requestMarker != requestMarker) {
                     return;
                 }
                 strongSelf.requestMarker = nil;
                 [strongSelf _prependResponse:response error:error];
             });
         });
     }];
}

- (void)fetchNext
{
    NSURL *URL;
    if (_lastPaginatedResponse) {
        URL = [self.userSession.requestManager URLForEndpoint:_lastPaginatedResponse.nextPath];
    } else if (_mostRecentPaginatedResponse) {
        URL = [self.userSession.requestManager URLForEndpoint:_mostRecentPaginatedResponse.nextPath];
    }
    if (URL == nil) {
        return;
    }
    if (self.isFetching) {
        return;
    }
    self.isFetching = YES;
    self.error = nil;

    NSObject *requestMarker = [[NSObject alloc] init];
    self.requestMarker = requestMarker;

    __weak KUSPaginatedDataSource *weakSelf = self;
    Class modelClass = [self modelClass];

    [self.userSession.requestManager
     performRequestType:KUSRequestTypeGet
     URL:URL
     params:nil
     authenticated:YES
     completion:^(NSError *error, NSDictionary *json) {
         dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
             KUSPaginatedResponse *response = [[KUSPaginatedResponse alloc] initWithJSON:json modelClass:modelClass];
             dispatch_async(dispatch_get_main_queue(), ^{
                 __strong KUSPaginatedDataSource *strongSelf = weakSelf;
                 // Check to make sure that the request marker did not change
                 if (strongSelf == nil || strongSelf.requestMarker != requestMarker) {
                     return;
                 }
                 strongSelf.requestMarker = nil;
                 [strongSelf _appendResponse:response error:error];
             });
         });
     }];
}

- (void)cancel
{
    self.isFetching = NO;
    self.requestMarker = nil;
}

#pragma mark - Subclass methods

- (NSURL *)firstURL
{
    return nil;
}

- (Class)modelClass
{
    return [KUSModel class];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return @[
        [NSSortDescriptor sortDescriptorWithKey:@"oid" ascending:NO]
    ];
}

#pragma mark - Internal methods

- (void)_appendResponse:(KUSPaginatedResponse *)response error:(NSError *)error
{
    if (error || response == nil) {
        self.isFetching = NO;
        self.error = error ?: [NSError new];
        [self notifyAnnouncersDidError:self.error];
        return;
    }

    _lastPaginatedResponse = response;
    _mostRecentPaginatedResponse = response;

    self.isFetching = NO;
    self.didFetch = YES;
    self.didFetchAll = (self.didFetchAll || response.nextPath == nil);

    [self upsertObjects:response.objects];

    [self notifyAnnouncersDidLoad];
}

- (void)_prependResponse:(KUSPaginatedResponse *)response error:(NSError *)error
{
    if (error || response == nil) {
        self.isFetching = NO;
        self.error = error ?: [NSError new];
        [self notifyAnnouncersDidError:self.error];
        return;
    }

    _mostRecentPaginatedResponse = response;

    self.isFetching = NO;
    self.didFetch = YES;
    self.didFetchAll = (self.didFetchAll || response.nextPath == nil);

    [self upsertObjects:response.objects];

    [self notifyAnnouncersDidLoad];
}

- (void)sortObjects
{
    [_fetchedModels sortUsingDescriptors:[self sortDescriptors]];
}

- (void)removeObjects:(NSArray<KUSModel *> *)objects
{
    if (objects.count == 0) {
        return;
    }

    BOOL didChange = NO;
    for (KUSModel *object in objects) {
        NSUInteger indexOfObject = [self indexOfObject:object];
        if (indexOfObject != NSNotFound) {
            didChange = YES;
            [_fetchedModels removeObjectAtIndex:indexOfObject];
            [_fetchedModelsById removeObjectForKey:object.oid];
        }
    }

    if (didChange) {
        [self notifyAnnouncersDidChangeContent];
    }
}

- (void)upsertObjects:(NSArray<KUSModel *> *)objects
{
    if (objects.count == 0) {
        return;
    }

    BOOL didChange = NO;
    for (KUSModel *object in objects) {
        NSUInteger indexOfObject = [self indexOfObject:object];
        if (indexOfObject != NSNotFound) {
            KUSModel *currentObject = [self objectWithId:object.oid];
            if (![object isEqual:currentObject]) {
                didChange = YES;
            }
            [_fetchedModels replaceObjectAtIndex:indexOfObject withObject:object];
            [_fetchedModelsById setObject:object forKey:object.oid];
        } else {
            didChange = YES;
            [_fetchedModels addObject:object];
            [_fetchedModelsById setObject:object forKey:object.oid];
        }
    }

    [self sortObjects];

    if (didChange) {
        [self notifyAnnouncersDidChangeContent];
    }
}

#pragma mark - Internal listener methods

- (void)notifyAnnouncersDidChangeContent
{
    for (id<KUSPaginatedDataSourceListener> listener in [self.listeners copy]) {
        if ([listener respondsToSelector:@selector(paginatedDataSourceDidChangeContent:)]) {
            [listener paginatedDataSourceDidChangeContent:self];
        }
    }
}

- (void)notifyAnnouncersDidError:(NSError *)error
{
    for (id<KUSPaginatedDataSourceListener> listener in [self.listeners copy]) {
        if ([listener respondsToSelector:@selector(paginatedDataSource:didReceiveError:)]) {
            [listener paginatedDataSource:self didReceiveError:error];
        }
    }
}

- (void)notifyAnnouncersDidLoad
{
    for (id<KUSPaginatedDataSourceListener> listener in [self.listeners copy]) {
        if ([listener respondsToSelector:@selector(paginatedDataSourceDidLoad:)]) {
            [listener paginatedDataSourceDidLoad:self];
        }
    }
}

@end
