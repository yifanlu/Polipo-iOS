//
//  PIPolipo.m
//  Polipo-iOS
//
//  Created by Yifan Lu on 8/4/13.
//  Copyright (c) 2013 Yifan Lu. All rights reserved.
//

#include <pthread.h>
#import "PIPolipo.h"

void *runPolipo(void *args);

@interface PIPolipo ()

- (NSString*)configFromSettings;

@property (nonatomic, strong) NSPipe *logPipe;
@property (nonatomic, strong) NSThread *proxyThread;
@property bool polipoInitialized;

@end

@implementation PIPolipo

@synthesize delegate = _delegate, isRunning = _isRunning, logPipe = _logPipe, proxyThread = _proxyThread, polipoInitialized;
@synthesize logLevel, proxyName, listenAddress, listenPort;

pthread_t thread;

#pragma mark Setup polipo

- (NSString*)configFromSettings
{
    NSString *config = [NSString stringWithFormat:
                        @"allowedClients = 127.0.0.1\n"
                        @"logFile =\n"
                        @"logLevel = 0x%02X\n"
                        @"maxIdleMilliseconds = 5000\n"
                        @"proxyAddress = %@\n"
                        @"proxyName = %@\n"
                        @"proxyPort = %04u\n"
                        @"serverIdleTimeout = 45s\n"
                        @"serverTimeout = 1m30s\n",
                        (int) [self logLevel],
                        [self listenAddress],
                        [self proxyName],
                        (int) [self listenPort]
                        ];
#ifdef DEBUG
    NSLog(@"Config:\n%@\n", config);
#endif
    return config;
}

#pragma mark Initialization

- (id)initWithDelegate:(id)delegate
{
    self = [super init];
    if (self)
    {
        [self setDelegate:delegate];
        [self setLogPipe:[[NSPipe alloc] init]];
    }
    return self;
}

- (void)dealloc
{
    if ([self isRunning])
    {
        [self stop];
    }
}

#pragma Start/stop

- (void)start
{
    dispatch_async(dispatch_get_main_queue(),
                   ^ {
                       [[self delegate] polipoWillStart:self];
                   });
    
    // get config
    NSString *tmpPath = NSTemporaryDirectory();
    NSString *path = [tmpPath stringByAppendingPathComponent:@"polipo.config"];
    NSString *conf = [self configFromSettings];
    [conf writeToFile:path atomically:YES encoding:NSASCIIStringEncoding error:NULL];
    
    // set up logging
    polipoSetLog(fdopen([[[self logPipe] fileHandleForWriting] fileDescriptor], "w"));
    NSFileHandle *handle = [[self logPipe] fileHandleForReading];
    [handle setReadabilityHandler:^(NSFileHandle *handle) {
        NSString *log = [[NSString alloc] initWithData:[handle availableData] encoding:NSASCIIStringEncoding];
        dispatch_async(dispatch_get_main_queue(),
                       ^ {
                           [[self delegate] polipoLogMessage:log];
                       });
    }];
    
    // init polipo
    if ((![self polipoInitialized] && polipoInit([path UTF8String]) < 0))
    {
        [self setIsRunning:false];
        dispatch_async(dispatch_get_main_queue(),
                       ^ {
                           [[self delegate] polipoDidFailWithError:@"Failed to initialize polipo." polipo:self];
                       });
        return;
    }
    [self setPolipoInitialized:true];
    if (polipoListenInit() < 0)
    {
        [self setIsRunning:false];
        dispatch_async(dispatch_get_main_queue(),
                       ^ {
                           [[self delegate] polipoDidFailWithError:@"Failed to create listener." polipo:self];
                       });
        return;
    }
    
    // run polipo
    [self setIsRunning:true];
    pthread_create(&thread, NULL, runPolipo, (void *)CFBridgingRetain(self));
#ifndef DO_NOT_DETACH
    pthread_detach(thread);
#endif
    
    dispatch_async(dispatch_get_main_queue(),
                   ^ {
                       [[self delegate] polipoDidStart:self];
                   });
}

- (void)stop
{
    dispatch_async(dispatch_get_main_queue(),
                   ^ {
                       [[self delegate] polipoWillStop:self];
                   });
    if (![self isRunning])
    {
        [self setIsRunning:false];
        dispatch_async(dispatch_get_main_queue(),
                       ^ {
                           [[self delegate] polipoDidFailWithError:@"Polipo is not running." polipo:self];
                       });
        return;
    }
    polipoExit();
    pthread_kill(thread, SIGINT);
#ifdef DO_NOT_DETACH
    pthread_join(thread, NULL);
#endif
}

#pragma mark Properties

- (NSInteger)logLevel
{
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"logLevel"];
    if (val)
    {
        return val;
    }
    else
    {
        return 0x07;
    }
}

- (NSString *)proxyName
{
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:@"proxyName"];
    if (val)
    {
        return val;
    }
    else
    {
        return @"polipo";
    }
}

- (NSString *)listenAddress
{
    return @"127.0.0.1";
}

- (NSInteger)listenPort
{
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"listenPort"];
    if (val)
    {
        return val;
    }
    else
    {
        return 8008;
    }
}

#pragma mark Polipo run thread

void *runPolipo(void *args)
{
    id self = CFBridgingRelease(args);
    while (polipoDoEvents() >= 0);
    close(polipoGetListenerSocket());
    [self setIsRunning:false];
    dispatch_async(dispatch_get_main_queue(),
                   ^ {
                       [[self delegate] polipoDidStop:self];
                   });
    [self setProxyThread:nil];
    return NULL;
}

@end
