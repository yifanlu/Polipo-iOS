//
//  PIMainViewController.h
//  Polipo-iOS
//
//  Created by Yifan Lu on 8/4/13.
//  Copyright (c) 2013 Yifan Lu. All rights reserved.
//

#import "PIPolipo.h"

@interface PIMainViewController : UIViewController <PIPolipoDelegate>

@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) IBOutlet UISwitch *startProxySwitch;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) IBOutlet UITextView *logTextView;
@property (strong, nonatomic) IBOutlet UIButton *installProfileButton;

- (IBAction)toggleProxy:(id)sender;
- (IBAction)installProfile:(id)sender;

@end
