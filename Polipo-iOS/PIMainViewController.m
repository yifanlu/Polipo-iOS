//
//  PIMainViewController.m
//  Polipo-iOS
//
//  Created by Yifan Lu on 8/4/13.
//  Copyright (c) 2013 Yifan Lu. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "PIMainViewController.h"
#import "PIPolipo.h"

@interface PIMainViewController ()

@property (nonatomic) bool isWorking;
@property (nonatomic, strong) PIPolipo *polipo;
#ifdef NO_AUDIO_BACKGROUNDING
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
#else
@property (nonatomic, strong) AVPlayer *bgPlayer;
#endif

- (void)createProfile;
- (void)createSignedProfile;
- (void)enableBackground;
- (void)disableBackground;

@end

@implementation PIMainViewController

@synthesize activityIndicator, startProxySwitch, statusLabel, logTextView;
@synthesize isWorking = _isWorking, polipo = _polipo;
#ifdef NO_AUDIO_BACKGROUNDING
@synthesize backgroundTask;
#else
@synthesize bgPlayer;
#endif

#pragma mark View Delegate methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setPolipo:[[PIPolipo alloc] initWithDelegate:self]];
}

- (void)enableBackground
{
#ifdef DEBUG
    NSLog(@"Enable backgrounding");
#endif
#ifdef NO_AUDIO_BACKGROUNDING
    [self setBackgroundTask:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        NSLog(@"Background handler about to expire.");
        [[UIApplication sharedApplication] endBackgroundTask:[self backgroundTask]];
        [self setBackgroundTask:UIBackgroundTaskInvalid];
    }]];
#else
    // Set AVAudioSession
    NSError *sessionError = nil;
    [[AVAudioSession sharedInstance] setDelegate:self];
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&sessionError];
#else
    NSLog(@"Warning: iOS 6 is required for background audio hiding.");
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
#endif
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"silence" withExtension:@"mp3"]];
    
    [self setBgPlayer:[[AVPlayer alloc] initWithPlayerItem:item]];
    [[self bgPlayer] setActionAtItemEnd:AVPlayerActionAtItemEndNone];
    [[self bgPlayer] play];
#endif
}

- (void)disableBackground
{
#ifdef DEBUG
    NSLog(@"Disable backgrounding");
#endif
#ifdef NO_AUDIO_BACKGROUNDING
    if ([self backgroundTask] != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:[self backgroundTask]];
        [self setBackgroundTask:UIBackgroundTaskInvalid];
    }
#else
    [self setBgPlayer:nil];
#endif
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Main view methods

- (bool)isWorking
{
    return _isWorking;
}

- (void)setIsWorking:(bool)isWorking
{
    _isWorking = isWorking;
    if (isWorking)
    {
        [[self activityIndicator] startAnimating];
        [[self startProxySwitch] setEnabled:false];
    }
    else
    {
        [[self activityIndicator] stopAnimating];
        [[self startProxySwitch] setEnabled:true];
    }
}

#pragma mark Actions

- (IBAction)toggleProxy:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^ {
        if ([sender isOn])
        {
            [[self polipo] start];
        }
        else
        {
            [[self polipo] stop];
        }
    });
}

- (void)createProfile
{
    // prepare profile
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [paths objectAtIndex:0];
    NSURL *wwwDirectory = [documentsDirectory URLByAppendingPathComponent:@"www" isDirectory:YES];
    NSString *configfile = [[NSBundle mainBundle] pathForResource: @"polipo" ofType: @"mobileconfig"];
    NSMutableDictionary* prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:configfile];
    id payloadContent = [prefs valueForKey:@"PayloadContent"];
    id payload = [payloadContent firstObject];
    payloadContent = [payload valueForKey:@"PayloadContent"];
    payload = [payloadContent firstObject];
    id defaults = [payload valueForKey:@"DefaultsData"];
    id apns = [defaults valueForKey:@"apns"];
    id apn = [apns firstObject];
    
    // create profile
    NSString *apnstr = [[NSUserDefaults standardUserDefaults] stringForKey:@"apn"];
    if (!apnstr)
    {
        apnstr = [NSString string];
    }
    [apn setObject:apnstr forKey:@"apn"];
    [apn setObject:[[self polipo] listenAddress] forKey:@"proxy"];
    [apn setObject:[NSString stringWithFormat:@"%04d", (int)[[self polipo] listenPort]] forKey:@"proxyPort"];
    [prefs writeToURL:[wwwDirectory URLByAppendingPathComponent:@"polipo.mobileconfig"] atomically:NO];
}

- (void)createSignedProfile
{
    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectory = [paths objectAtIndex:0];
    NSURL *wwwDirectory = [documentsDirectory URLByAppendingPathComponent:@"www" isDirectory:YES];
    NSURL *configfile = [[NSBundle mainBundle] URLForResource: @"polipo-signed" withExtension: @"mobileconfig"];
    NSURL *webpath = [wwwDirectory URLByAppendingPathComponent:@"polipo.mobileconfig"];
    
    [[NSFileManager defaultManager] removeItemAtURL:webpath error:nil];
    [[NSFileManager defaultManager] copyItemAtURL:configfile toURL:webpath error:nil];
}

- (IBAction)installProfile:(id)sender
{
    // open link to profile
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%d/%@", [[self polipo] listenAddress], (int) [[self polipo] listenPort], @"polipo.mobileconfig"]]];
}

#pragma mark Polipo Delegate methods

- (void)polipoWillStart:(PIPolipo *)polipo
{
    [self setIsWorking:true];
    [[self statusLabel] setText:@"Starting..."];
    if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending)
    {
        [self createProfile];
    }
    else
    {
        [self createSignedProfile];
    }
}

- (void)polipoWillStop:(PIPolipo *)polipo
{
    [self setIsWorking:true];
    [[self statusLabel] setText:@"Stopping..."];
    [self disableBackground];
}

- (void)polipoDidStart:(PIPolipo *)polipo
{
    [self setIsWorking:false];
    [[self startProxySwitch] setOn:[polipo isRunning]];
    [[self installProfileButton] setEnabled:true];
    [[self statusLabel] setText:[NSString stringWithFormat:@"Listening on %@:%d", [[self polipo] listenAddress], (int)[[self polipo] listenPort]]];
    
    [self enableBackground];
}

- (void)polipoDidStop:(PIPolipo *)polipo
{
    [self setIsWorking:false];
    [[self startProxySwitch] setOn:[polipo isRunning]];
    [[self installProfileButton] setEnabled:false];
    [[self statusLabel] setText:@"Stopped"];
}

- (void)polipoDidTunnelStop:(PIPolipo *)polipo
{
}

- (void)polipoDidFailWithError:(NSString *)error polipo:(PIPolipo *)polipo
{
    [self setIsWorking:false];
    [[self startProxySwitch] setOn:[polipo isRunning]];
    [[self installProfileButton] setEnabled:false];
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Error" message:error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [message show];
    [[self statusLabel] setText:@"Error"];
    [self disableBackground];
}

- (void)polipoLogMessage:(NSString *)message
{
    [[self logTextView] setText:[NSString stringWithFormat:@"%@%@", [[self logTextView] text], message]];
    NSRange range = NSMakeRange([[[self logTextView] text] length] - 1, 1);
    [[self logTextView] scrollRangeToVisible:range];
#if DEBUG
    NSLog(@"%@", message);
#endif
}

@end
