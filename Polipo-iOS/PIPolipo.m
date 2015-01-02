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
@property (nonatomic, strong) NSThread *tunnelThread;
@property bool polipoInitialized;
@property int tunnelClientPort;

@end

@implementation PIPolipo

@synthesize delegate = _delegate, isRunning = _isRunning, logPipe = _logPipe, proxyThread = _proxyThread, tunnelThread = _tunnelThread, polipoInitialized, tunnelClientPort;
@synthesize logLevel, proxyName, listenAddress, listenPort;

pthread_t proxyPthread;
pthread_t tunnelPthread;

#pragma mark Setup polipo

- (NSString*)configFromSettings
{
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [paths objectAtIndex:0];
    NSString *wwwDirectory = [[documentsDirectory URLByAppendingPathComponent:@"www" isDirectory:YES] path];
    [[NSFileManager defaultManager] createDirectoryAtPath:wwwDirectory withIntermediateDirectories:YES attributes:nil error:nil]; // create documents root if not existing
    
    NSString *config = [NSString stringWithFormat:
                        @"allowedClients = 127.0.0.1\n"
                        @"logFile =\n"
                        @"logLevel = 0x%02X\n"
                        @"maxIdleMilliseconds = 5000\n"
                        @"proxyAddress = %@\n"
                        @"proxyName = %@\n"
                        @"proxyPort = %04u\n"
                        @"serverIdleTimeout = 45s\n"
                        @"serverTimeout = 1m30s\n"
                        @"diskCacheRoot = \n"
                        @"disableIndexing = false\n"
                        @"localDocumentRoot = \"%@\"\n"
                        @"parentProxy = localhost:%04u\n"
                        @"onlyForwardHttps = %s\n",
                        (int) [self proxyLogLevel],
                        [self listenAddress],
                        [self proxyName],
                        (int) [self listenPort],
                        wwwDirectory,
                        [self tunnelClientPort],
                        [self tunnelAlways] ? "false" : "true"
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
    
    // assign tunnel port
    // TODO: better way of assigning
    tunnelClientPort = 4444;
    
    // get config
    NSString *tmpPath = NSTemporaryDirectory();
    NSString *path = [tmpPath stringByAppendingPathComponent:@"polipo.config"];
    NSString *conf = [self configFromSettings];
    [conf writeToFile:path atomically:YES encoding:NSASCIIStringEncoding error:NULL];
    
    // set up logging
    FILE *log_file = fdopen([[[self logPipe] fileHandleForWriting] fileDescriptor], "w");
    polipoSetLog(log_file);
    httptunnel_setdebug((int)[self tunnelLogLevel], log_file);
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
    // we use pthread instead of NSThread because we need pthread_kill()
    pthread_create(&proxyPthread, NULL, runPolipo, (void *)CFBridgingRetain(self));
    pthread_create(&tunnelPthread, NULL, runTunnel, (void *)CFBridgingRetain(self));
#ifndef DO_NOT_DETACH
    pthread_detach(proxyPthread);
    pthread_detach(tunnelPthread);
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
    pthread_kill(proxyPthread, SIGINT);
    pthread_kill(tunnelPthread, SIGINT);
#ifdef DO_NOT_DETACH
    pthread_join(proxyPthread, NULL);
    pthread_join(tunnelPthread, NULL);
#endif
}

#pragma mark Properties

- (NSInteger)proxyLogLevel
{
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"proxyLogLevel"];
    if (val)
    {
        return val;
    }
    else
    {
        return 1;
    }
}

- (NSInteger)tunnelLogLevel
{
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"tunnelLogLevel"];
    if (val)
    {
        return val;
    }
    else
    {
        return 1;
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

- (NSString *)tunnelAddress
{
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:@"tunnelAddress"];
    if (val)
    {
        return val;
    }
    else
    {
        return @"0.0.0.0";
    }
}

- (NSInteger)tunnelPort
{
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:@"tunnelPort"];
    if (val)
    {
        return val;
    }
    else
    {
        return 0;
    }
}

- (bool)tunnelAlways
{
    bool val = [[NSUserDefaults standardUserDefaults] boolForKey:@"tunnelAlways"];
    if (val)
    {
        return val;
    }
    else
    {
        return NO;
    }
}

#pragma mark Polipo run thread

void *runPolipo(void *args)
{
    PIPolipo *self = (PIPolipo *)CFBridgingRelease(args);
    polipoDoEvents();
    close(polipoGetListenerSocket());
    [self setIsRunning:false];
    dispatch_async(dispatch_get_main_queue(),
                   ^ {
                       [[self delegate] polipoDidStop:self];
                   });
    [self setProxyThread:nil];
    return NULL;
}

void *runTunnel(void *args)
{
    PIPolipo *self = (PIPolipo *)CFBridgingRelease(args);
    httptunnel_client([self tunnelClientPort], [[self tunnelAddress] UTF8String], (int)[self tunnelPort]);
    dispatch_async(dispatch_get_main_queue(),
                   ^ {
                       [[self delegate] polipoDidTunnelStop:self];
                   });
    [self setTunnelThread:nil];
    return NULL;
}

@end
