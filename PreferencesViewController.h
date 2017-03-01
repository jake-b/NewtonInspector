//
//  PreferencesViewController.h
//  NewtonInspector
//
//  Created by Jake Bordens on 3/1/17.
//  Copyright © 2017 allaboutjake. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PreferencesViewController : NSViewController {
    NSTextField *deviceTextField;
    NSString* mode;
}

@property (assign) IBOutlet NSTextField *deviceTextField;

- (IBAction)close:(id)sender;

@end
