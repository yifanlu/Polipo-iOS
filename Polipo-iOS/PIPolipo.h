//
//  PIPolipo.h
//  Polipo-iOS
//
//  Created by Yifan Lu on 8/4/13.
//  Copyright (c) 2013 Yifan Lu. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdio.h>

extern int polipoInit(const char *config);
extern int polipoListenInit();
extern void polipoExit();
extern void polipoSetLog(FILE *file);
extern int polipoGetListenerSocket();
extern int polipoDoEvents();
extern int polipoClearCache();
extern void polipoRelease();
extern int httptunnel_client (int port, const char *hostname, int host_port);
extern int httptunnel_setdebug (int loglevel, FILE *logfile);

@class PIPolipo;

@protocol PIPolipoDelegate

@required

- (void)polipoWillStart:(PIPolipo *)polipo;
- (void)polipoWillStop:(PIPolipo *)polipo;
- (void)polipoDidStart:(PIPolipo *)polipo;
- (void)polipoDidStop:(PIPolipo *)polipo;
- (void)polipoDidTunnelStop:(PIPolipo *)polipo;
- (void)polipoDidFailWithError:(NSString *)error polipo:(PIPolipo *)polipo;
- (void)polipoLogMessage:(NSString *)message;

@end

@interface PIPolipo : NSObject

@property (nonatomic, assign) id delegate;
@property (atomic) bool isRunning;
@property (readonly) NSInteger logLevel;
@property (readonly) NSString *proxyName;
@property (readonly) NSString *listenAddress;
@property (readonly) NSInteger listenPort;
@property (readonly) NSString *tunnelAddress;
@property (readonly) bool tunnelAlways;

- (id)initWithDelegate:(id)delegate;
- (void)start;
- (void)stop;

@end
