//
//  ChannelServiceFactory.m
//  keyboard
//
//  Created by everettjf on 2019/7/21.
//  Copyright © 2019 everettjf. All rights reserved.
//

#import "ChannelServiceFactory.h"
#import "HttpServerManager.h"

#pragma mark -- HTTP


@interface HTTPChannelService : NSObject<ChannelService>
@property (nonatomic, weak) id<ChannelServiceDelegate> callback;
@end
@implementation HTTPChannelService

- (void)setDelegate:(nonnull id<ChannelServiceDelegate>)delegate {
    self.callback = delegate;
}

- (void)start {
    __weak typeof(self) ws = self;
    rekb::HttpServerManager::instance().onStatus = ^(const std::string &type,const std::string &data) {
        if(ws && ws.callback) {
            [ws.callback onStatus:[NSString stringWithUTF8String:type.c_str()] content:[NSString stringWithUTF8String:data.c_str()]];
        }
    };
    rekb::HttpServerManager::instance().onMessage = ^(const std::string &type,const std::string &data) {
        if(ws && ws.callback) {
            [ws.callback onMessage:[NSString stringWithUTF8String:type.c_str()] content:[NSString stringWithUTF8String:data.c_str()]];
        }
    };

    rekb::HttpServerManager::instance().start();
}

- (void)close {
    rekb::HttpServerManager::instance().close();
}

@end



@implementation ChannelServiceFactory

+ (id<ChannelService>)createChannel:(NSString*)channelType {
    return [[HTTPChannelService alloc] init];
}

@end
