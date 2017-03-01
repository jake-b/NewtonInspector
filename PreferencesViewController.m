//
//  PreferencesViewController.m
//  NewtonInspector
//
//  Created by Jake Bordens on 3/1/17.
//  Copyright © 2017 allaboutjake. All rights reserved.
//

#import "PreferencesViewController.h"

@implementation PreferencesViewController
@synthesize deviceTextField;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)viewWillAppear {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    mode = [defaults objectForKey:@"mode"];
    if (mode == nil) mode = @"auto";
    [self updateRadio];
}
- (IBAction)radioButtonChanged:(NSButton*)sender {
    mode = sender.identifier;
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:mode forKey:@"mode"];
    [defaults synchronize];
    
    [self updateRadio];
}

- (void) updateRadio {
    for (NSView* v in self.view.subviews) {
        if ([v.identifier isEqualToString:mode]) {
            [(NSButton*)v setState:NSOnState];
            break;
        }
    }

    if ([mode isEqualToString:@"auto"]) {
        deviceTextField.enabled = NO;
        [deviceTextField setStringValue:@"(auto)"];
    } else if ([mode isEqualToString:@"pipe"]) {
        deviceTextField.enabled = NO;
        [deviceTextField setStringValue:@"(named pipe)"];
    } else if ([mode isEqualToString:@"dev"]) {
        deviceTextField.enabled = YES;
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSString* device = [defaults objectForKey:@"device"];
        if (device == nil) device = @"/dev/";
        [deviceTextField setStringValue:device];
        [deviceTextField becomeFirstResponder];
        [deviceTextField.currentEditor moveToEndOfLine:nil];
    }
}

- (IBAction)close:(id)sender {
    if ([mode isEqualToString:@"dev"]) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:deviceTextField.stringValue forKey:@"device"];
        [defaults synchronize];
    }
    [self.view.window close];
}

@end
