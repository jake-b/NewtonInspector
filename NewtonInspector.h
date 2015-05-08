//
//  NewtonInspector.h
//  NewtonInspector
//
//
// Copyright (C) 2015 J. Bordens
// based on code from DyneTK https://github.com/MatthiasWM/dynee5/tree/master/DyneTK
// License: http://www.gnu.org/licenses/gpl.html GPL version 3 or higher
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "NewtonConnection.h"
#import "NewtObj.h"


@protocol NewtonInspectorDelegate <NSObject>

// The inspector will call this delegate function when it has text to display.
- (void) textFromInspector:(NSString*)text;

// The inspector will call this delegate function if it receives a disconnect from
// the Newton or the Toolbox app on the newton.
- (void) inspectorDisconnected;

// The inspector will call this app when it successfully negotiates a connection.
- (void) inspectorConnected;

@optional

- (void) textFromInspector:(NSString*)text withColor:(NSColor*)color;

@end

@interface NewtonInspector : NSObject
{
    dispatch_queue_t commsQueue;  // A GCD queue where the communcations occurs
    
    NSDate* lastPing;  // holds the last time sent a ping for keep-alive
    BOOL connected;    // boolean flag to indicate whether we are connected
    
    id<NewtonInspectorDelegate> _delegate; // for the delegate property
    NewtonConnection* _serial; // handles the MNP communications with the Newton
}

@property (retain, nonatomic) id<NewtonInspectorDelegate> delegate;
@property (retain, nonatomic) NewtonConnection* serial;

+ (NewtonInspector*)inspectorWithDevicePath:(NSString*)devicePath speed:(int)speed;

// Sends a package to the newton.  Will delete an exisitng pacakge with the same signature
- (void) installPackage:(NSURL*)fileURL;

// Deletes a pacakge with the given signature
- (void) deletePackage:(NSString*)signature;

// Takes a NewtonScript snippedna nd compiles it into a NSOF binary.  Then
// sends the binary to the Newton for execution
- (void) sendScript:(NSString*)newtonScript;

// Cleanly request disconnect from the Newton
- (void)disconnect;

// Determine if we are connected to the Toolkit app on the Newton
- (bool)isConnected;

// A helper function that reads a package on disk and gets its signature
+ (NSString*) getPackageSignature:(NSURL*)fileURL;

@end


// Helper methods
@interface NSString (Newt0)

// Takes a newton opject and returns it as a string representation
+ (NSString*) stringFromNewtObj:(newtRefVar)obj;

@end

@interface NSImage (Newt0)

// Saves an image to the given path (used for screenshots)
- (void)saveImageToPath:(NSString *)path;

// Converts a NewtonScript screenshot frame into an NSImage
+ (NSImage*)imageFromScreenshotFrame:(newtRefVar)snapshot;

@end