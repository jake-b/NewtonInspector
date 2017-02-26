//
//  InspectorSplitViewController.m
//  NewtonInspector
//
//  Created by Jake Bordens on 5/1/15.
//  Copyright (c) 2015 allaboutjake. All rights reserved.
//
//
// Copyright (C) 2015 J. Bordens
// License: http://www.gnu.org/licenses/gpl.html GPL version 3 or higher
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//


#import "InspectorViewController.h"

@interface InspectorViewController ()

@end

@implementation InspectorViewController

@synthesize inspector = _inspector, inputTextView = _inputTextView, outputTextView = _outputTextView;
@synthesize font = _font;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.

}

- (void)awakeFromNib {
    self.font = [NSFont fontWithName:@"Monaco" size:12.0];
    if (self.font) {
        self.inputTextView.font = self.font;
        self.outputTextView.font = self.font;
        
        self.inputTextView.automaticQuoteSubstitutionEnabled = NO;
        self.inputTextView.automaticDashSubstitutionEnabled = NO;
        self.inputTextView.automaticTextReplacementEnabled = NO;
    }
}

- (void)dealloc {
    self.inspector = nil;
    self.outputTextView = nil;
    self.inputTextView = nil;
    self.font = nil;
    
    [super dealloc];
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem {
    
    BOOL enable = NO;
    if ([[toolbarItem itemIdentifier] isEqual:@"connect"] |
        [[toolbarItem itemIdentifier] isEqual:@"clear"]) {
        enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual:@"install"] ||
               [[toolbarItem itemIdentifier] isEqual:@"screenshot"] ||
               [[toolbarItem itemIdentifier] isEqual:@"watch"]) {
        enable = [self.inspector isConnected];
    }
    return enable;
}

- (IBAction)connectInspector:(id)sender {
    if (!self.inspector) {
        if (1) {
            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/dev" error:nil];
            NSArray *serialDevices = [files filteredArrayUsingPredicate: [NSPredicate predicateWithFormat:@"self BEGINSWITH[cd] 'cu.usbserial'"]];
            if ([serialDevices firstObject]) {
                NSString* device = [@"/dev" stringByAppendingPathComponent:[serialDevices firstObject]];
                NSLog(@"opening %@",device);
                self.inspector = [NewtonInspector inspectorWithDevicePath:device speed:38400];
            }
        } else {
            self.inspector = [NewtonInspector inspectorWithEinsteinNamedPipes];
        }
        self.inspector.delegate = self;
    } else {
        NSLog(@"Disconnecting Inspector");        
        [self.inspector disconnect];
    }
}

- (IBAction)inspectorConnected {
    for (NSToolbarItem* item in  self.view.window.toolbar.items) {
        if ([item.itemIdentifier isEqualToString:@"connect"]) {
            [item setImage:[NSImage imageNamed:@"box_opened.png"]];
            item.label = @"Disconnect";
        }
    }
    [self.view.window.toolbar validateVisibleItems];
}

- (IBAction)inspectorDisconnected {
    self.inspector = nil;
    
    for (NSToolbarItem* item in  self.view.window.toolbar.items) {
        if ([item.itemIdentifier isEqualToString:@"connect"]) {
            [item setImage:[NSImage imageNamed:@"box_closed.png"]];
            item.label = @"Connect";
        }
    }
    
    if (watchActive)
        [self stopWatchingPackageFile];
    
    [self.view.window.toolbar validateVisibleItems];    
}

- (void)installPackage:(NSURL*)thePackage delete:(BOOL)deleteFirst {
    if (deleteFirst) {
        NSString* sig = [NewtonInspector getPackageSignature:thePackage];
        [self.inspector deletePackage:sig];
    }
    [self.inspector installPackage:thePackage];
}

- (IBAction)installPackage:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];

    // Configure
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes: @[@"pkg", @"newtonpkg"]];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  thePackage = [[panel URLs] objectAtIndex:0];
            //TODO: delete preferences
            [self installPackage:thePackage delete:YES];
        }
        
    }];
}

- (IBAction)watchPackage:(id)sender {
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    if (watchActive) {
        [self stopWatchingPackageFile];
    } else {
        // Configure a new watch
        [panel setAllowsMultipleSelection:NO];
        [panel setAllowedFileTypes: @[@"pkg", @"newtonpkg"]];
        [panel setTitle:@"Watch Package File"];
        
        [panel beginWithCompletionHandler:^(NSInteger result){
            if (result == NSFileHandlingPanelOKButton) {

                NSURL*  thePackage = [[panel URLs] objectAtIndex:0];
                [self installPackage:thePackage delete:YES];
                watchActive = YES;
                [self watchPackageFile:[thePackage path]];
                
            }
        }];
    }
}

- (void) textFromInspector:(NSString*)text {
    if (text) {
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        if (self.font) {
            [attributes setObject:self.font forKey:NSFontAttributeName];

        }
        [attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:text attributes:attributes];
        [[self.outputTextView textStorage] appendAttributedString:attr];
        [self.outputTextView scrollRangeToVisible:NSMakeRange([[self.outputTextView string] length], 0)];
        [attr release];
    }
}

- (void) textFromInspector:(NSString*)text withColor:(NSColor*)color {
    NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
    if (self.font) {
        [attributes setObject:self.font forKey:NSFontAttributeName];
    }
    [attributes setObject:color forKey:NSForegroundColorAttributeName];
    NSAttributedString* attr = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    [[self.outputTextView textStorage] appendAttributedString:attr];
    [self.outputTextView scrollRangeToVisible:NSMakeRange([[self.outputTextView string] length], 0)];
    [attr release];
}



// From http://stackoverflow.com/questions/11682939/add-hotkey-to-nstextfield

- (BOOL)isCommandEnterEvent:(NSEvent *)e {
    NSUInteger flags = (e.modifierFlags & NSDeviceIndependentModifierFlagsMask);
    BOOL isCommand = (flags & NSCommandKeyMask) == NSCommandKeyMask;
    BOOL isEnter = (e.keyCode == 0x24); // VK_RETURN
    return (isCommand && isEnter);
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    
    if ((commandSelector == @selector(noop:)) &&
        [self isCommandEnterEvent:[NSApp currentEvent]]) {
        [self handleCommandEnter];
        return YES;
    }
    return NO;
    
#pragma clang diagnostic pop
 
}

- (void)handleCommandEnter {
    [self.inspector sendScript:[[self.inputTextView textStorage] string]];
}

- (IBAction)clearLog:(id)sender {
    [self.outputTextView setString:@""];
}

- (IBAction)takeScreenshot:(id)sender {
    [self.inspector sendScript:@"|Screenshot:ntk|()"];
}


// http://www.davidhamrick.com/2011/10/13/Monitoring-Files-With-GCD-Being-Edited-With-A-Text-Editor.html
- (void)watchPackageFile:(NSString*)path {
    __block typeof(self) blockSelf = self; // used inside blocks;
   
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    if (fileWatchSource != NULL) {
        NSLog(@"Already watching a file.");
        return;
    }
    
    //Wait for the file to exist
    int fildes = -1;
    while ((fildes = open([path UTF8String], O_EVTONLY)) == -1 && watchActive) {
        sleep(1);
    }

    // If the file doesn't exist yet, then someone canceled the watch, bail out.
    if (fildes == -1) {
        [blockSelf stopWatchingPackageFile];
        return;
    }

    // Create a new fileWatchSOurce
    fileWatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE,fildes,
                                        DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND |
                                        DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME |
                                        DISPATCH_VNODE_REVOKE, queue);
    dispatch_source_set_event_handler(fileWatchSource, ^{
                                      unsigned long flags = dispatch_source_get_data(fileWatchSource);
                                        NSLog(@"File flags %ld", flags);
                                      if(flags & DISPATCH_VNODE_DELETE)
                                      {
                                          dispatch_source_cancel(fileWatchSource);
                                          
                                          dispatch_async(queue, ^{
                                              // Wait for the fileWatchSource to be deallocated
                                              NSLog(@"wait for dealloc of source");
                                              while (fileWatchSource != NULL) {
                                                  sleep(1);
                                              }
                                              
                                              // Wait for the file to come back
                                              NSLog(@"Waiting for file to return");
                                              NSFileManager* mgr = [NSFileManager defaultManager];
                                              while (watchActive && ![mgr fileExistsAtPath:path]) {
                                                  sleep(1);
                                              }

                                              // Now we're ready to install the package and restart the watch
                                              [blockSelf watchPackageFile:path];
                                              [blockSelf installPackage:[NSURL fileURLWithPath:path] delete:YES];

                                          });
                                      } else {
                                          // The PKG changed on disk, send it to the newton.
                                          // No need to wait, as the file wasn't deleted.
                                          [blockSelf installPackage:[NSURL fileURLWithPath:path] delete:YES];
                                      }
        
                                  });
    dispatch_source_set_cancel_handler(fileWatchSource, ^(void)
                                   {
                                       close(fildes);
                                       dispatch_release(fileWatchSource);
                                       fileWatchSource = NULL;
                                   });
    dispatch_resume(fileWatchSource);
    
    for (NSToolbarItem* item in  self.view.window.toolbar.items) {
        if ([item.itemIdentifier isEqualToString:@"watch"]) {
            [item setImage:[NSImage imageNamed:@"watching.png"]];
            item.label = @"Stop Watching";
        }
    }
}

- (void)stopWatchingPackageFile {
    if (fileWatchSource) {
        dispatch_source_cancel(fileWatchSource);
    }
    watchActive = NO;

    for (NSToolbarItem* item in  self.view.window.toolbar.items) {
        if ([item.itemIdentifier isEqualToString:@"watch"]) {
            [item setImage:[NSImage imageNamed:@"package.png"]];
            item.label = @"Watch";
        }
    }
}

@end
