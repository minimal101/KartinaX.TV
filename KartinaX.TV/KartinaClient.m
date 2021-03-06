//
//  KartinaManager.m
//  KartinaX.TV
//
//  Created by mk on 09.03.13.
//  Copyright (c) 2013 Maxim Kalina. All rights reserved.
//

#import "KartinaClient.h"
#import "Login.h"
#import "ChannelList.h"
#import "ChannelStream.h"
#import <RestKit/RestKit.h>
#import "KartinaClientDelegate.h"
#import "EPGDataItem.h"
#import "EPGData.h"
#import "Utils.h"
#import "KartinaSession.h"
#import "TMCache.h"
#import "Logout.h"
#import "SetSetting.h"
#import "VODList.h"
#import "VODItemDetails.h"
#import "VODStream.h"
#import "VODGenre.h"

@implementation KartinaClient

static KartinaClient *instance = nil;    // static instance variable

RKObjectManager *objectManager;
NSString *const baseURL = @"http://iptv.kartina.tv/api/json/";


+ (KartinaClient *)sharedInstance {

    if (instance == nil) {
        instance = (KartinaClient *) [[super allocWithZone:NULL] init];

        objectManager = [RKObjectManager managerWithBaseURL:[NSURL URLWithString:baseURL]];

        RKLogConfigureByName("RestKit/Network*", RKLogLevelCritical);
        RKLogConfigureByName("RestKit/ObjectMapping", RKLogLevelCritical);

        RKResponseDescriptor *loginResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[Login objectMapping]
                                                        pathPattern:@"login"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *channelListResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[ChannelList objectMapping]
                                                        pathPattern:@"channel_list"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *channelStreamResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[ChannelStream objectMapping]
                                                        pathPattern:@"get_url"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *epg3ResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[EPGDataItem objectMapping]
                                                        pathPattern:@"epg3" keyPath:@"epg3" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *logoutResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[Logout objectMapping]
                                                        pathPattern:@"logout"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *setSettingResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[SetSetting objectMapping]
                                                        pathPattern:@"settings_set"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *vodListResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[VODList objectMapping]
                                                        pathPattern:@"vod_list"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];

        RKResponseDescriptor *vodFavListResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[VODList objectMapping]
                                                        pathPattern:@"vod_favlist"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];

        RKResponseDescriptor *vodItemDetailsResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[VODItemDetails objectMapping]
                                                        pathPattern:@"vod_info"
                                                            keyPath:@"film" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *vodStreamResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[VODStream objectMapping]
                                                        pathPattern:@"vod_geturl"
                                                            keyPath:nil statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];
        RKResponseDescriptor *vodGenresResponseDescriptor =
                [RKResponseDescriptor responseDescriptorWithMapping:[VODGenre objectMapping]
                                                        pathPattern:@"vod_genres"
                                                            keyPath:@"genres" statusCodes:RKStatusCodeIndexSetForClass(RKStatusCodeClassSuccessful)];

        [objectManager addResponseDescriptor:loginResponseDescriptor];
        [objectManager addResponseDescriptor:channelListResponseDescriptor];
        [objectManager addResponseDescriptor:channelStreamResponseDescriptor];
        [objectManager addResponseDescriptor:epg3ResponseDescriptor];
        [objectManager addResponseDescriptor:logoutResponseDescriptor];
        [objectManager addResponseDescriptor:setSettingResponseDescriptor];
        [objectManager addResponseDescriptor:vodListResponseDescriptor];
        [objectManager addResponseDescriptor:vodFavListResponseDescriptor];
        [objectManager addResponseDescriptor:vodItemDetailsResponseDescriptor];
        [objectManager addResponseDescriptor:vodStreamResponseDescriptor];
        [objectManager addResponseDescriptor:vodGenresResponseDescriptor];
    }
    return instance;
}

- (void)loginWithUsername:(NSString *)username AndPassword:(NSString *)pass {

    if (username == nil || pass == nil) {
        [self.delegate onLoginFail:[self customError:@"User credentials missing." code:0]];
        return;
    }

    NSDictionary *params = @{
            @"login" : username,
            @"pass" : pass,
            @"device" : @"all",
            @"settings" : @"all",
    };

    [objectManager getObjectsAtPath:@"login"
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {

                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No login data returned." code:-1];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one login item returned." code:-2];
                                } else {

                                    Login *login = [results objectAtIndex:0];
                                    if ([login hasError])
                                        error = [self customError:login.errorMessage codeAsNumber:login.errorCode];
                                    else
                                        [self.delegate onLoginSuccess:login];
                                }

                                if (error)
                                    [self.delegate onLoginFail:error];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLoginFail:error];
                            }
    ];

}

- (void)loadChannelList {

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:2];
    NSString *protectedCode = [KartinaSession protectedCode];
    if (protectedCode != nil) {
        [params setObject:@"all" forKey:@"show"];
        [params setObject:protectedCode forKey:@"protect_code"];
    }

    [objectManager getObjectsAtPath:@"channel_list"
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {

                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No channels data returned." code:-3];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one channel list returned." code:-4];
                                } else {
                                    ChannelList *list = [results objectAtIndex:0];
                                    if ([list hasError])
                                        error = [self customError:list.errorMessage codeAsNumber:list.errorCode];
                                    else {
                                        [list enhanceChannelList];
                                        [self.delegate onLoadChannelListSuccess:list];
                                    }

                                }
                                if (error)
                                    [self.delegate onLoadChannelListFail:error];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLoadChannelListFail:error];
                            }
    ];

}

- (void)loadChannelStream:(NSNumber *)channelId gmt:(NSNumber *)unixTime protectedChannel:(BOOL)protectedChannel {

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:3];
    [params setObject:channelId forKey:@"cid"];
    if (unixTime != nil) {
        [params setObject:unixTime forKey:@"gmt"];
    }
    if (protectedChannel == YES) {
        NSString *protectedCode = [KartinaSession protectedCode];
        if (protectedCode != nil)
            [params setObject:protectedCode forKey:@"protect_code"];
    }

    [objectManager getObjectsAtPath:@"get_url"
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No channel url returned." code:-5];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one channel url returned." code:-6];
                                } else {
                                    ChannelStream *stream = [results objectAtIndex:0];
                                    if ([stream hasError]) {
                                        error = [self customError:stream.errorMessage codeAsNumber:stream.errorCode];
                                    } else if ([stream.url isEqualToString:@"protected"]) {
                                        error = [self customError:@"Protected channel requested." code:-7];
                                    } else {
                                        stream.channelId = channelId;
                                        [self.delegate onLoadChannelStreamSuccess:stream];
                                    }
                                }

                                if (error)
                                    [self.delegate onLoadChannelStreamFail:error];


                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLoadChannelStreamFail:error];
                            }
    ];
}

- (void)loadEPG:(NSDate *)date {

    NSNumber *unixTime = [Utils dateDDMMYYAsUnixTimestamp:date];

    EPGData *data = [[TMCache sharedCache] objectForKey:unixTime.stringValue];
    if (data != nil) {
        [self.delegate onLoadEpgDataSuccess:data];
        return;
    }

    [objectManager getObjectsAtPath:@"epg3"
                         parameters:@{@"dtime" : unixTime, @"period" : @"24"}
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {

                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil) {
                                    error = [self customError:@"No EPG data found." code:-8];
                                } else {
                                    EPGData *data = [[EPGData alloc] init];
                                    data.date = date;
                                    data.items = results;
                                    [data enhanceShowInformation];
                                    [self.delegate onLoadEpgDataSuccess:data];

                                    // put into cache only if items available
                                    if (data.items.count > 0) {
                                        [[TMCache sharedCache] setObject:data forKey:unixTime.stringValue block:nil];
                                    }
                                }

                                if (error)
                                    [self.delegate onLoadEpgDataFail:error];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLoadEpgDataFail:error];
                            }
    ];
}

- (void)setSettingValue:(NSString *)value forKey:(NSString *)key {
    NSDictionary *params = @{
            @"var" : key,
            @"val" : value,
    };

    [objectManager getObjectsAtPath:@"settings_set"
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {

                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No data returned." code:-1];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one item returned." code:-2];
                                } else {

                                    SetSetting *setResult = [results objectAtIndex:0];
                                    if ([setResult hasError])
                                        error = [self customError:setResult.errorMessage codeAsNumber:setResult.errorCode];
                                    else
                                        [self.delegate onSetSettingSuccess:setResult];
                                }

                                if (error)
                                    [self.delegate onSetSettingFail:error];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onSetSettingFail:error];
                            }
    ];
}

- (void)logout {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [objectManager getObjectsAtPath:@"logout"
                         parameters:nil
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                [self.delegate onLogoutSuccess];
                                dispatch_semaphore_signal(semaphore);
                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLogoutFail:error];
                            }
    ];

    // wait for a second
    NSTimeInterval TMCacheTestBlockTimeout = 1.0;
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t) (TMCacheTestBlockTimeout * NSEC_PER_SEC));
    dispatch_semaphore_wait(semaphore, timeout);
}

- (void)trimEPGCache {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit)
                                          fromDate:[[NSDate alloc] init]];
    [components setDay:([components day] - 7)];
    NSDate *lastWeek = [cal dateFromComponents:components];
    [[TMCache sharedCache] trimToDate:lastWeek];
}

- (void)loadVODList:(NSString *)type page:(NSNumber *)page query:(NSString *)query
              genre:(NSString *)genre itemsPerPage:(NSNumber *)itemsPerPage {

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:5];
    NSString *urlPath;

    if (![type isEqualToString:@"favorite"]) {
        urlPath = @"vod_list";
        [params setObject:type forKey:@"type"];
        [params setObject:page forKey:@"page"];
        if ([type isEqualToString:@"text"]) {
            if (query != nil && query.length > 0) {
                [params setObject:query forKey:@"query"];
            } else {
                return;
            }
        }
        if (genre != nil)
            [params setObject:genre forKey:@"genre"];

        [params setObject:itemsPerPage forKey:@"nums"];
    } else {
        urlPath = @"vod_favlist";
    }

    [objectManager getObjectsAtPath:urlPath
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {

                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No data returned." code:-1];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one item returned." code:-2];
                                } else {

                                    VODList *vodList = results[0];
                                    if ([vodList hasError])
                                        error = [self customError:vodList.errorMessage codeAsNumber:vodList.errorCode];
                                    else
                                        [self.delegate onLoadVODListSuccess:vodList];
                                }
                                if (error)
                                    [self.delegate onLoadVODListFail:error];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLoadVODListFail:error];
                            }
    ];

}

- (void)loadVODItemDetails:(NSString *)id {

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:5];
    [params setObject:id forKey:@"id"];

    [objectManager getObjectsAtPath:@"vod_info"
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {

                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No data returned." code:-1];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one item returned." code:-2];
                                } else {

                                    VODItemDetails *details = results[0];
                                    if ([details hasError])
                                        error = [self customError:details.errorMessage codeAsNumber:details.errorCode];
                                    else
                                        [self.delegate onLoadVODItemDetailsSuccess:details];
                                }

                                if (error)
                                    [self.delegate onLoadVODItemDetailsFail:error];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onLoadVODItemDetailsFail:error];
                            }
    ];
}

- (void)loadVODStream:(NSNumber *)fileId {

    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:3];
    [params setObject:fileId forKey:@"fileid"];

    [objectManager getObjectsAtPath:@"vod_geturl"
                         parameters:params
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                NSError *error;
                                NSArray *results = mappingResult.array;
                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No data returned." code:-1];
                                } else if (results.count > 1) {
                                    error = [self customError:@"More than one item returned." code:-2];
                                } else {
                                    VODStream *stream = [results objectAtIndex:0];
                                    if ([stream hasError]) {
                                        error = [self customError:stream.errorMessage codeAsNumber:stream.errorCode];
                                    } else if ([stream.url isEqualToString:@"protected"]) {
                                        error = [self customError:@"Protected vod requested." code:-7];
                                    } else {
                                        [self.delegate onVODStreamSuccess:stream];
                                    }
                                }

                                if (error)
                                    [self.delegate onVODStreamFail:error];


                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onVODStreamFail:error];
                            }
    ];

}

- (void)loadVODGenres {

    [objectManager getObjectsAtPath:@"vod_genres"
                         parameters:nil
                            success:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
                                NSError *error;
                                NSArray *results = mappingResult.array;

                                if (results == nil || results.count == 0) {
                                    error = [self customError:@"No data returned." code:-1];
                                }


                                if (error)
                                    [self.delegate onVODGenresLoadFail:error];
                                else
                                    [self.delegate onVODGenresLoadSucces:results];

                            }
                            failure:^(RKObjectRequestOperation *operation, NSError *error) {
                                [self.delegate onVODGenresLoadFail:error];
                            }
    ];


}


- (NSError *)customError:(NSString *)message codeAsNumber:(NSNumber *)code {
    return [self customError:message code:code.intValue];
}

- (NSError *)customError:(NSString *)message code:(NSInteger)code {

    NSLog(@"message: '%@', localized: %@", message, NSLocalizedString(message, message));
    return [NSError errorWithDomain:@"net.javaforge.osx.kartina"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : NSLocalizedString(message, message)}];
}

@end
