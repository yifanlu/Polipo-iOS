//
//  PIMainViewController.m
//  Polipo-iOS
//
//  Created by Yifan Lu on 8/4/13.
//  Copyright (c) 2013 Yifan Lu. All rights reserved.
//

#import "PIMainViewController.h"
#import "PIPolipo.h"

@interface PIMainViewController ()

@property bool isWorking;
@property PIPolipo *polipo;

@end

@implementation PIMainViewController

@synthesize activityIndicator, startProxySwitch, statusLabel, logTextView;
@synthesize isWorking = _isWorking, polipo = _polipo;

#pragma mark View Delegate methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setPolipo:[[PIPolipo alloc] initWithDelegate:self]];
	// Do any additional setup after loading the view, typically from a nib.
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
    dispatch_async(dispatch_get_main_queue(),
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

- (IBAction)installProfile:(id)sender
{
    
}

#pragma mark Polipo Delegate methods

- (void)polipoWillStart:(PIPolipo *)polipo
{
    [self setIsWorking:true];
    [[self statusLabel] setText:@"Starting..."];
}

- (void)polipoWillStop:(PIPolipo *)polipo
{
    [self setIsWorking:true];
    [[self statusLabel] setText:@"Stopping..."];
}

- (void)polipoDidStart:(PIPolipo *)polipo
{
    [self setIsWorking:false];
    [[self startProxySwitch] setOn:[polipo isRunning]];
    [[self statusLabel] setText:[NSString stringWithFormat:@"Listening on %@:%d", [[self polipo] listenAddress], (int)[[self polipo] listenPort]]];
}

- (void)polipoDidStop:(PIPolipo *)polipo
{
    [self setIsWorking:false];
    [[self startProxySwitch] setOn:[polipo isRunning]];
    [[self statusLabel] setText:@"Stopped"];
}

- (void)polipoDidFailWithError:(NSString *)error polipo:(PIPolipo *)polipo
{
    [self setIsWorking:false];
    [[self startProxySwitch] setOn:[polipo isRunning]];
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Error" message:error delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [message show];
    [[self statusLabel] setText:@"Error"];
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
