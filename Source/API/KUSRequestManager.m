//
//  KUSRequestManager.m
//  Kustomer
//
//  Created by Daniel Amitay on 8/13/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSRequestManager.h"

#import <SDWebImage/SDWebImageDownloader.h>
#import <UIKit/UIKit.h>

#import "KUSLog.h"
#import "KUSUserSession.h"
#import "Kustomer_Private.h"

NSString *const kKustomerTrackingTokenHeaderKey = @"x-kustomer-tracking-token";

typedef void (^KUSTrackingTokenCompletion)(NSError *error, NSString *trackingToken);

@interface KUSRequestManager () <KUSObjectDataSourceListener> {
    __weak KUSUserSession *_userSession;

    NSDictionary<NSString *, NSString *> *_genericHTTPHeaderValues;
}

@property (nonatomic, strong, readonly) NSString *baseUrlString;
@property (nonatomic, strong, readonly) NSURLSession *urlSession;
@property (nonatomic, strong, readonly) dispatch_queue_t queue;

@property (nonatomic, strong, null_resettable) NSMutableArray<KUSTrackingTokenCompletion> *pendingTrackingTokenCompletions;

@end

@implementation KUSRequestManager

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;

        _baseUrlString = [NSString stringWithFormat:@"https://%@.api.%@",
                          _userSession.orgName, [Kustomer hostDomain]];
        _genericHTTPHeaderValues = @{
            @"X-Kustomer": @"kustomer",                         // CORS Header
            @"Accept-Language": KUSAcceptLanguageHeaderValue(), // Accept-Language Header
            @"User-Agent": KUSUserAgentHeaderValue(),           // User-Agent Header
            @"x-kustomer-client": @"customer-ios",              // Kustomer client Header
            @"x-kustomer-version":  [NSString stringWithFormat:@"%@%@",@"release-v",[Kustomer sdkVersion]], // Kustomer version Header
        };

        _queue = dispatch_queue_create("com.kustomer.request-manager", nil);

        NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.underlyingQueue = _queue;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        [configuration setTimeoutIntervalForRequest:15.0];
        _urlSession = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:operationQueue];

        [_userSession.trackingTokenDataSource addListener:self];
        
        [[SDWebImageDownloader sharedDownloader] setRequestModifier:[self _sdWebImageDownloaderRequestModifier]];
    }
    return self;
}

#pragma mark - URL methods

- (NSURL *)URLForEndpoint:(NSString *)endpoint
{
    NSString *endpointUrlString = [NSString stringWithFormat:@"%@%@", self.baseUrlString, endpoint];
    return [NSURL URLWithString:endpointUrlString];
}

- (NSDictionary<NSString *, NSString *> *)genericHTTPHeaderValues
{
    return _genericHTTPHeaderValues;
}

#pragma mark - Request methods

- (void)getEndpoint:(NSString *)endpoint
      authenticated:(BOOL)authenticated
         completion:(KUSRequestCompletion)completion
{
    [self performRequestType:KUSRequestTypeGet
                    endpoint:endpoint
                      params:nil
               authenticated:authenticated
                  completion:completion];
}

- (void)performRequestType:(KUSRequestType)type
                  endpoint:(NSString *)endpoint
                    params:(NSDictionary<NSString *, id> *)params
             authenticated:(BOOL)authenticated
                completion:(KUSRequestCompletion)completion
{
    [self performRequestType:type
                         URL:[self URLForEndpoint:endpoint]
                      params:params
               authenticated:authenticated
                  completion:completion];
}

- (void)performRequestType:(KUSRequestType)type
                       URL:(NSURL *)URL
                    params:(NSDictionary<NSString *, id> *)params
             authenticated:(BOOL)authenticated
                completion:(KUSRequestCompletion)completion
{
    [self performRequestType:type
                         URL:URL
                      params:params
               authenticated:authenticated
           additionalHeaders:nil
                  completion:completion];
}

- (void)performRequestType:(KUSRequestType)type
                       URL:(NSURL *)URL
                    params:(NSDictionary<NSString *, id> *)params
             authenticated:(BOOL)authenticated
         additionalHeaders:(NSDictionary *)additionalHeaders
                completion:(KUSRequestCompletion)completion
{
    [self performRequestType:type
                         URL:URL
                      params:params
                    bodyData:nil
               authenticated:authenticated
           additionalHeaders:additionalHeaders
                  completion:^(NSError *error, NSDictionary *response, NSHTTPURLResponse *httpResponse) {
                      if (completion) {
                          completion(error, response);
                      }
                  }];
}

- (void)performRequestType:(KUSRequestType)type
                       URL:(NSURL *)URL
                    params:(NSDictionary<NSString *, id> *)params
                  bodyData:(NSData *)bodyData
             authenticated:(BOOL)authenticated
         additionalHeaders:(NSDictionary *)additionalHeaders
                completion:(void(^)(NSError *error, NSDictionary *response, NSHTTPURLResponse *httpResponse))completion
{
    void (^safeComplete)(NSError *, NSDictionary *, NSHTTPURLResponse *) = ^void(NSError *error, NSDictionary *response, NSHTTPURLResponse *httpResponse) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    completion(error, nil, httpResponse);
                } else {
                    completion(nil, response, httpResponse);
                }
            });
        }
    };

    void (^performRequestWithTrackingToken)(NSString *) = ^void(NSString *trackingToken) {
        KUSLogRequest(@"Performing request: %@ %@%@%@", KUSRequestTypeToString(type),
                      URL.path, URL.query.length ? @"?" : @"", URL.query ?: @"");

        NSURL *finalURL = (type == KUSRequestTypeGet ? KUSURLFromURLAndQueryParams(URL, params) : URL);
        NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:finalURL];
        [urlRequest setHTTPMethod:KUSRequestTypeToString(type)];

        for (NSString *key in _genericHTTPHeaderValues) {
            [urlRequest setValue:_genericHTTPHeaderValues[key] forHTTPHeaderField:key];
        }

        for (NSString *headerField in additionalHeaders) {
            [urlRequest setValue:additionalHeaders[headerField] forHTTPHeaderField:headerField];
        }

        if (type != KUSRequestTypeGet) {
            if (bodyData) {
                NSString *contentLength = [NSString stringWithFormat:@"%lu", (unsigned long)bodyData.length];
                [urlRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
                [urlRequest setHTTPBody:bodyData];
            } else {
                KUSAttachJSONBodyToRequest(urlRequest, params);
            }
        }

        if (authenticated && trackingToken) {
            [urlRequest setValue:trackingToken forHTTPHeaderField:kKustomerTrackingTokenHeaderKey];
        }

        void (^responseBlock)(NSData *, NSURLResponse *, NSError *) = ^void(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                safeComplete(error, nil, (NSHTTPURLResponse *)response);
                return;
            }
            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];

            NSArray<NSDictionary *> *kErrors = [json objectForKey:@"errors"];
            if ([kErrors isKindOfClass:[NSArray class]] && [kErrors.firstObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *kError = kErrors.firstObject;
                NSError *error = [NSError errorWithDomain:@"com.kustomer.error"
                                                     code:0
                                                 userInfo:kError];
                safeComplete(error, nil, (NSHTTPURLResponse *)response);
            } else {
                safeComplete(jsonError, json, (NSHTTPURLResponse *)response);
            }
        };
        NSURLSessionDataTask *dataTask = [_urlSession dataTaskWithRequest:urlRequest completionHandler:responseBlock];
        [dataTask resume];
    };

    if (authenticated) {
        [self _dispenseTrackingToken:^(NSError *error, NSString *trackingToken) {
            if (error) {
                safeComplete(error, nil, nil);
            } else {
                performRequestWithTrackingToken(trackingToken);
            }
        }];
    } else {
        dispatch_async(self.queue, ^{
            performRequestWithTrackingToken(nil);
        });
    }
}

#pragma mark - Internal methods

- (void)_dispenseTrackingToken:(KUSTrackingTokenCompletion)callback
{
    NSString *trackingToken = _userSession.trackingTokenDataSource.currentTrackingToken;
    if (trackingToken) {
        dispatch_async(self.queue, ^{
            callback(nil, trackingToken);
        });
    } else {
        [self.pendingTrackingTokenCompletions addObject:callback];
        [_userSession.trackingTokenDataSource fetch];
    }
}

- (void)_firePendingTokenCompletionsWithToken:(NSString *)token error:(NSError *)error
{
    NSArray<KUSTrackingTokenCompletion> *completions = [_pendingTrackingTokenCompletions copy];
    _pendingTrackingTokenCompletions = nil;

    if (completions.count) {
        dispatch_async(self.queue, ^{
            for (KUSTrackingTokenCompletion completion in completions) {
                completion(error, token);
            }
        });
    }
}

- (SDWebImageDownloaderRequestModifier * _Nonnull) _sdWebImageDownloaderRequestModifier {
    return [SDWebImageDownloaderRequestModifier requestModifierWithBlock:^NSURLRequest * _Nullable(NSURLRequest * _Nonnull request) {
        
        BOOL isKustomer = [request.URL.absoluteString hasPrefix:self->_baseUrlString];
        if (isKustomer) {
            
            NSMutableURLRequest *mutableRequest = [request mutableCopy];
            
            [_genericHTTPHeaderValues enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull value, BOOL * _Nonnull stop) {
                [mutableRequest setValue:value forHTTPHeaderField:key];
            }];
            
            // Tracking token
            NSString *trackingToken = _userSession.trackingTokenDataSource.currentTrackingToken;
            if (trackingToken) {
                [mutableRequest setValue:trackingToken forHTTPHeaderField:kKustomerTrackingTokenHeaderKey];
            }
            return [mutableRequest copy];
        }
        return request;
    }];
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    if (dataSource == _userSession.trackingTokenDataSource) {
        NSString *trackingToken = _userSession.trackingTokenDataSource.currentTrackingToken;
        [self _firePendingTokenCompletionsWithToken:trackingToken error:nil];
    }
}

- (void)objectDataSource:(KUSObjectDataSource *)dataSource didReceiveError:(NSError *)error
{
    [self _firePendingTokenCompletionsWithToken:nil error:error];
}

#pragma mark - Lazy-loaded methods

- (NSMutableArray<KUSTrackingTokenCompletion> *)pendingTrackingTokenCompletions
{
    if (_pendingTrackingTokenCompletions == nil) {
        _pendingTrackingTokenCompletions = [[NSMutableArray alloc] init];
    }
    return _pendingTrackingTokenCompletions;
}

#pragma mark - Helper methods

static NSString *KUSRequestTypeToString(KUSRequestType type)
{
    switch (type) {
        case KUSRequestTypeGet:
            return @"GET";
        case KUSRequestTypePost:
            return @"POST";
        case KUSRequestTypePatch:
            return @"PATCH";
        case KUSRequestTypePut:
            return @"PUT";
        case KUSRequestTypeDelete:
            return @"DELETE";
    }
}

static NSURL *KUSURLFromURLAndQueryParams(NSURL *URL, NSDictionary<NSString *, id> *params)
{
    if (params.count < 1) {
        return URL;
    }

    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *queryItems = [[NSMutableArray alloc] initWithCapacity:params.count];
    for (NSString *key in params) {
        id value = params[key];
        NSString *valueString = nil;
        if ([value isKindOfClass:[NSString class]]) {
            valueString = (NSString *)value;
        } else {
            valueString = [NSString stringWithFormat:@"%@", value];
        }
        NSURLQueryItem *queryItem = [NSURLQueryItem queryItemWithName:key value:valueString];
        [queryItems addObject:queryItem];
    }
    urlComponents.queryItems = queryItems;
    return urlComponents.URL;
}

static void KUSAttachJSONBodyToRequest(NSMutableURLRequest *mutableURLRequest, NSDictionary<NSString *, id> *params)
{
    if (params) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:NULL];
        [mutableURLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *contentLength = [NSString stringWithFormat:@"%lu", (unsigned long)jsonData.length];
        [mutableURLRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
        [mutableURLRequest setHTTPBody:jsonData];
    }
}

static NSString *KUSAcceptLanguageHeaderValue()
{
    // See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
    NSMutableArray<NSString *> *acceptLanguagesComponents = [[NSMutableArray alloc] init];
    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        float q = 1.0f - (idx * 0.1f);
        [acceptLanguagesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
        *stop = q <= 0.5f;
    }];
    return [acceptLanguagesComponents componentsJoinedByString:@", "];
}

static NSString *KUSUserAgentHeaderValue()
{
    // See http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    NSDictionary<NSString *, id> *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    return [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)",
            bundleInfo[(__bridge NSString *)kCFBundleExecutableKey] ?: bundleInfo[(__bridge NSString *)kCFBundleIdentifierKey],
            bundleInfo[@"CFBundleShortVersionString"] ?: bundleInfo[(__bridge NSString *)kCFBundleVersionKey],
            [[UIDevice currentDevice] model],
            [[UIDevice currentDevice] systemVersion],
            [[UIScreen mainScreen] scale]];
}

@end
