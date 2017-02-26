//
//  NewtonInspector.m
//  NewtonInspector
//
// Copyright (C) 2015 J. Bordens
// based on code from DyneTK https://github.com/MatthiasWM/dynee5/tree/master/DyneTK
// License: http://www.gnu.org/licenses/gpl.html GPL version 3 or higher
//
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//

#import "NewtonInspector.h"
#import <QuartzCore/QuartzCore.h>

#import "NewtFns.h"
#import "NewtEnv.h"
#import "NewtObj.h"
#import "NewtBC.h"
#import "NewtNSOF.h"
#import "NewtVM.h"
#import "NewtStr.h"
#import "NewtPrint.h"
#import "NewtNSOF.h"

@interface NewtonInspector (Private)

- (id)initWithDevicePath:(NSString*)devicePath speed:(int)speed;
- (id)initWithEinsteinNamedPipes;
- (void)sendTextToDelegate:(NSString*)text withColor:(NSColor*)color;

@end

@implementation NewtonInspector

@synthesize serial = _serial, delegate = _delegate;


+ (NewtonInspector*)inspectorWithDevicePath:(NSString*)devicePath speed:(int)speed {
    return [[[NewtonInspector alloc] initWithDevicePath:devicePath speed:speed] autorelease];
}

+ (NewtonInspector*)inspectorWithEinsteinNamedPipes {
    return [[[NewtonInspector alloc] initWithEinsteinNamedPipes] autorelease];
}


- (void) dealloc {
    dispatch_release(commsQueue);
    
    self.delegate = nil;
    
    [self.serial disconnect];
    self.serial = nil;
    
    [super dealloc];
}


- (id)initWithDevicePath:(NSString*)devicePath speed:(int)speed {
    if (self = [super init]) {
        NSLog(@"initializing newton connection");
        self.serial = [NewtonConnection connectionWithDevicePath:devicePath speed:speed];
        
        connected = NO;
        
        commsQueue = dispatch_queue_create("com.allaboutjake.NewtonInspector", NULL);
        dispatch_async(commsQueue, ^{
            [self.serial beginStream];
            [self doInput:nil];
        });

    }
    return self;
}

- (id)initWithEinsteinNamedPipes {
    if (self = [super init]) {
        NSLog(@"initializing Einstein connection");
        self.serial = [NewtonConnection connectionWithEinsteinNamedPipes];
        
        connected = NO;
        
        commsQueue = dispatch_queue_create("com.allaboutjake.NewtonInspector", NULL);
        dispatch_async(commsQueue, ^{
            [self.serial beginStream];
            [self doInput:nil];
        });
        
    }
    return self;
}


- (void)disconnect {
    [self.serial cancel];
    dispatch_async(commsQueue, ^{
        // If in 3 seconds the 'term' command hasn't resulted in a disconnect,
        // then force the disconnect from our side.  (Likley the inspector disconnected
        // already and didn't respond to the 'term' command.
        dispatch_async(dispatch_get_main_queue(), ^{
            // Must be done on main thread because the commsQueue thread is will likely
            // be blcoking waiting for an ack.
            [self performSelector:@selector(cleanUp) withObject:nil afterDelay:3.0];
        });

        [self.serial sendBytes:(unsigned char*)"newt" length:4];
        [self.serial sendBytes:(unsigned char*)"ntp " length:4];
        [self.serial sendBytes:(unsigned char*)"term" length:4];
        [self.serial sendBytes:(unsigned char*)"\0\0\0\0" length:4];
    });
}

- (void) cleanUp {
    // If we got here during the normal course of operation, then cancel the 3-second timeout
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cleanUp) object:nil];
    
    // If we're connected, then disconnect
    if ([self.serial isConnected]) {
        [self.serial disconnect];
    }

    connected = NO;
    
    if ([self.delegate respondsToSelector:@selector(inspectorDisconnected)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate inspectorDisconnected];
        });
    }
}

- (bool)isConnected {
    return connected;
}

- (void)doInput:(id)object {
    // Don't do anything if we're not connected
    if (![self.serial isConnected]) return;
    
    // Check to see if there are any bytes available
    int available = [self.serial bytesAvailable];
    if (available < 0) {
        // If available <= -1, then there was an error, or a Link Disconnect event
        // Returining will end the process, as the next iteration of the loop is not scheduled.
        [self cleanUp];
        return;
    } else if (available > 0) {
        // process the packet
        uint32_t command;
        uint32_t length;
        
        int result = [self.serial scanForBytes:(unsigned char*)"newtntp " ofLength:8];
        
        // If we didn't get any bytes, then ship around to the next loop
        if (result == 0) goto skip;
        
        else if (result < 0) {
            // If available <= -1, then there was an error, or a Link Disconnect event
            // Returining will end the process, as the next iteration of the loop is not scheduled.
            [self cleanUp];
            return;
        }
        
        // Okay we found a preamble.  Get the command and the length
        [self.serial receiveBytes:(unsigned char*)&command ofLength:4];
        command = CFSwapInt32BigToHost(command);
        [self.serial receiveBytes:(unsigned char*)&length ofLength:4];
        length = CFSwapInt32BigToHost(length);
        
        NSLog(@"Receivng object of length %d", length);
        
        // Get the payload
        NSMutableData* payload = nil;
        if (length > 0) {
            payload = [NSMutableData dataWithLength:length];
            [self.serial receiveBytes:[payload mutableBytes] ofLength:length];
        }
        
        switch (command) {
            case 'cnnt':
                // Send the connection response
                [self.serial sendBytes:(unsigned char*)"newtntp " length:8];
                [self.serial sendBytes:(unsigned char*)"okln"     length:4];
                [self.serial sendBytes:(unsigned char*)"\0\0\0\0" length:4];
                connected = YES;
                
                // tell the delegate that we're connected
                if ([self.delegate respondsToSelector:@selector(inspectorConnected)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate inspectorConnected];
                    });
                }
                break;
                
            case 'fstk':    // Stack Trace
            case 'fobj': {  // Object
                // This code handles 2 types of objects:
                //   1. A screenshot frame
                //   2. An NAArray. assumed to contain a stack trace.
                newtRef obj = NewtReadNSOF((uint8_t*)[payload bytes], [payload length]);
                if (NewtRefIsFrame(obj)) {
                    //Probably a screenshot?
                    newtRef interp = NewtGetFrameSlot(obj, NewtFindSlotIndex(obj, NSSYM(interpretation)));
                    if (NewtRefIsSymbol(interp)) {
                        if (NewtSymbolEqual(interp, NSSYM(screenshot))) {
                            NSImage* image = [NSImage imageFromScreenshotFrame:obj];
                            NSString* tempFile = [NSString stringWithFormat:@"%@.png", [self temporaryFilePath]];
                            [image saveImageToPath:tempFile];
                            [[NSWorkspace sharedWorkspace] openFile:tempFile];
                            [self sendTextToDelegate:[NSString stringFromNewtObj:obj] withColor:[NSColor blackColor]];
                        }
                    }
                } else if (NewtRefIsArray(obj)) {
                    // Probably a stack trace
                    [self sendTextToDelegate:[NSString stringFromNewtObj:obj] withColor:[NSColor blackColor]];
                }
                break;
            }
                
            case 'rslt':
                // Not really sure what these result messages are alla bout,  Usually 0x00000000
                NSLog(@"Got rslt %d", length);
                NSLog(@"Payload: %@", payload);
                break;

            
            case 'eref': {
                // An eref payload is as follows:
                // A 4-byte length followed by a string of that length
                // a 4-byte length followed by an NSOF of that length
                NSInputStream* stream = [[NSInputStream alloc] initWithData:payload];
                uint32_t len;
                [stream open];
                [stream read:(uint8_t*)&len maxLength:4];
                len = CFSwapInt32BigToHost(len);
                NSMutableData* data = [[NSMutableData alloc] initWithLength:len];
                [stream read:(uint8_t*)[data mutableBytes] maxLength:len];
                NSString* str = [[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding];
                [self sendTextToDelegate:str withColor:[NSColor redColor]];
                [self sendTextToDelegate:@"\n" withColor:nil];

                [str release];
                [data release];

                [stream read:(uint8_t*)&len maxLength:4];
                len = CFSwapInt32BigToHost(len);
                data = [[NSMutableData alloc]  initWithLength:len];
                [stream read:(uint8_t*)[data mutableBytes] maxLength:len];
                newtRef obj = NewtReadNSOF((uint8_t*)[data bytes], [data length]);
                NSString* objStr = [NSString stringFromNewtObj:obj];
                [self sendTextToDelegate:objStr withColor:[NSColor redColor]];

                [data release];
                [stream close];
                [stream release];
                break;
            }
                
            case 'eerr':
                //intentional fallthrough
            case 'text': {
                NSString* str = [[NSString alloc] initWithData:payload encoding:NSMacOSRomanStringEncoding];
                [self sendTextToDelegate:str withColor:[NSColor blackColor]];
                [str release];
            }
                break;
                
            case 'eext':
                NSLog(@"Got unhandled eext dumped %d", length);
                break;
                
            default:
                printf("Unknown command: %.*s\n", 4, (char*)&command);
                break;
        }
    }
        
skip:
    // If we haven't sent a keep-alive pin in 3 seconds, then send one.  Prevents the Toolkit app from disconencting
    if (!lastPing || [[lastPing dateByAddingTimeInterval:3.0] compare:[NSDate date]] == NSOrderedAscending) {
        [self.serial sendKeepAlive];
        lastPing = [NSDate date];
    }
    
    // Do this again
    dispatch_async(commsQueue, ^{
        [self doInput:nil];
    });

}

// Install a pacakge
- (void)installPackage:(NSURL*)fileURL {
    dispatch_async(commsQueue, ^{
        NSData* package = [NSData dataWithContentsOfURL:fileURL];
    
        if (package) {
            // send the package
            [self.serial sendBytes:(unsigned char*)"newt" length:4];
            [self.serial sendBytes:(unsigned char*)"ntp " length:4];
            [self.serial sendBytes:(unsigned char*)"pkg " length:4];
            uint32_t len = CFSwapInt32HostToBig((uint32_t)[package length]);
            [self.serial sendBytes:(unsigned char*)&len length:4];
            [NSThread sleepForTimeInterval:1.0];
            [self.serial sendBytes:(unsigned char*)[package bytes] length:(int)[package length]];
        }
    });
}

// Delete a package with the given signature
- (void)deletePackage:(NSString*)signature {
    dispatch_async(commsQueue, ^{
        NSData* packageSig = [signature dataUsingEncoding:NSUTF16BigEndianStringEncoding];
        NSLog(@"PacakgeSigData: %@", packageSig);
        if (packageSig) {
            // delete
            [self.serial sendBytes:(unsigned char*)"newt" length:4];
            [self.serial sendBytes:(unsigned char*)"ntp " length:4];
            [self.serial sendBytes:(unsigned char*)"pkgX" length:4];
            uint32_t len = CFSwapInt32HostToBig((uint32_t)([packageSig length]+2));
            [self.serial sendBytes:(unsigned char*)&len length:4];
            [self.serial sendBytes:(unsigned char*)[packageSig bytes] length:(int)[packageSig length]];
            [self.serial sendBytes:(unsigned char*)"\0\0" length:2]; //null terminator
        }
    });
}

// Scan a package file for its signature
+ (NSString*) getPackageSignature:(NSURL*)fileURL {
    NSInputStream *stream = [[NSInputStream alloc]initWithURL:fileURL];
    
    if (stream == nil)
        NSLog(@"blah");
    
    [stream open];
    uint8_t pkgsig[8];
    uint32_t buf, parts;
    uint16_t offset, length;
    if ([stream read:pkgsig maxLength:8] != 8)
        return nil;
    
    if (strncmp((char*)pkgsig, "package0", 8) != 0 && strncmp((char*)pkgsig, "package1", 8) != 0)
        return nil;
    
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; // reserved
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; // flags
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; // version
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; // copyright
    if ([stream read:(uint8_t*)&offset maxLength:2] != 2) return nil; //offset
    if ([stream read:(uint8_t*)&length maxLength:2] != 2) return nil; // length
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; // size
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; //date
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; //reserved
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil; //reserved
    if ([stream read:(uint8_t*)&buf maxLength:4] != 4) return nil;//directorySize
    if ([stream read:(uint8_t*)&parts maxLength:4] != 4) return nil; //parts

    offset = CFSwapInt16BigToHost(offset);
    length = CFSwapInt16BigToHost(length);
    parts = CFSwapInt32BigToHost(parts);
    
    // Discard the parts, just get to the data section
    for (int x=0; x<parts; x++) {
        uint8_t part[8*4];
        if ([stream read:(uint8_t*)&part maxLength:8*4] != 8*4) return nil; //parts
    }
    
    // We are at teh start of the data section
    // move to the start of the name
    for (int x=0; x<offset; x++) {
        if ([stream read:(uint8_t*)&buf maxLength:1] != 1) return nil;
    }

    NSMutableData* data = [NSMutableData dataWithLength:length-2];
    if ([stream read:[data mutableBytes] maxLength:length-2] != length-2) return nil;
    
    [stream close];
    [stream release];
    
    return [[[NSString alloc] initWithData:data encoding:NSUTF16BigEndianStringEncoding] autorelease];
}

// Compile a NewtonScript string and send to the Newton for execution
- (void) sendScript:(NSString*)newtonScript {
    // Prepare to compile the bytecode by clearing any exceptions
    NVMClearException();
    
    // Try and compile the bytecode.
    const char* script = [newtonScript cStringUsingEncoding:NSMacOSRomanStringEncoding];
    newtRefVar obj = NBCCompileStr((char*)script, true);
    
    // See if we have an exception
    newtRef exception = NVMCurrentException();
    
    // If there was an execption, send it to the output area
    if (NewtRefIsFrame(exception)) {
        if ([self.delegate respondsToSelector:@selector(textFromInspector:)]) {
            [self sendTextToDelegate:[NSString stringFromNewtObj:exception] withColor:[NSColor orangeColor]];
        }
        return;
    }
    
    // Make an NSOF representation
    newtRefVar nsof = NsMakeNSOF(0, obj, NewtMakeInt30(2));
    //TODO: test for error
    
    // Send the compiled bytecode to the Newton for execution
    if (NewtRefIsBinary(nsof)) {
        uint32_t size = NewtBinaryLength(nsof);
        uint8_t *data = NewtRefToBinary(nsof);
        dispatch_async(commsQueue, ^{
            int size_be = CFSwapInt32HostToBig((int)size);
            [self.serial sendBytes:(unsigned char*)"newt" length:4];
            [self.serial sendBytes:(unsigned char*)"ntp " length:4];
            [self.serial sendBytes:(unsigned char*)"lscb" length:4];
            [self.serial sendBytes:(unsigned char*)&size_be length:4];
            [self.serial sendBytes:(unsigned char*)data length:size];
        });
    }

}

// From https://gist.github.com/kristopherjohnson/5266679
// Generate a unique temporary file path.  Used to name Screenshots
- (NSString *)temporaryFilePath {
    // Construct full-path template by prepending tmp directory path to filename template
    NSString *tempFilePathTemplate = [NSString pathWithComponents:@[NSTemporaryDirectory(), @"Inspector.XXXXXX"]];
    
    // Convert template to ASCII for use by C library functions
    const char* tempFilePathTemplateASCII = [tempFilePathTemplate cStringUsingEncoding:NSASCIIStringEncoding];
    
    // Copy template to temporary buffer so it can be modified in place
    char *tempFilePathASCII = calloc(strlen(tempFilePathTemplateASCII) + 1, 1);
    strcpy(tempFilePathASCII, tempFilePathTemplateASCII);
    
    // Call mktemp() to replace the "XXXXXX" in the template with something unique
    NSString *tempFilePath = tempFilePathTemplate;
    if (mktemp(tempFilePathASCII)) {
        tempFilePath = [NSString stringWithCString:tempFilePathASCII encoding:NSASCIIStringEncoding];
    }
    
    // Free the temporary buffer
    free(tempFilePathASCII);
    
    return tempFilePath;
}

// Method to dispatch a text message to the delegate
- (void)sendTextToDelegate:(NSString*)text withColor:(NSColor*)color {
    __block typeof(self) blockSelf = self;
    if (color && [self.delegate respondsToSelector:@selector(textFromInspector:withColor:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [blockSelf.delegate textFromInspector:text withColor:color];
        });
        return;
    }
    if ([self.delegate respondsToSelector:@selector(textFromInspector:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [blockSelf.delegate textFromInspector:text];
        });
        return;
    }
    
}

@end

@implementation NSString (Newt0)

+ (NSString*) stringFromNewtObj:(newtRefVar)obj {
    // I couldn't get NcSPrintObject to work for some reason.
    // It always returned an empty Newt String.
    // So this will create a file handle to capture the output of NewtPrintObject.
    
    NSPipe* pipe = [NSPipe pipe];
    NSFileHandle* writeHandle = [pipe fileHandleForWriting];
    NSFileHandle* readHandle = [pipe fileHandleForReading];

    FILE *fileWrite = fdopen([writeHandle fileDescriptor], "w");
    NewtPrintObject(fileWrite, obj);
    fclose(fileWrite);
    
    NSData* data = [readHandle readDataToEndOfFile];
    
    
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

@end

@implementation NSImage (Newt0)

// From http://stackoverflow.com/questions/17507170/how-to-save-png-file-from-nsimage-retina-issues
- (void)saveImageToPath:(NSString *)path {
    CGImageRef cgRef = [self CGImageForProposedRect:NULL
                                             context:nil
                                               hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[self size]];   // if you want the same resolution
    NSData *pngData = [newRep representationUsingType:NSPNGFileType properties:nil];
    [pngData writeToFile:path atomically:YES];
    [newRep autorelease];
}

// This function is largely based on the DyneTK code.
+ (NSImage*)imageFromScreenshotFrame:(newtRefVar)snapshot {
    // See if we have a NewtonScript frame
    if (NewtRefIsFrame(snapshot)) {
        // If wedo, see if we have a data slot
        newtRef data = NewtGetFrameSlot(snapshot, NewtFindSlotIndex(snapshot, NSSYM(data)));
        if (NewtRefIsFrame(data)) {
            
            // get the dimensions and data
            newtRef nRowbytes = NewtGetFrameSlot(data, NewtFindSlotIndex(data, NSSYM(rowbytes)));
            newtRef nTop      = NewtGetFrameSlot(data, NewtFindSlotIndex(data, NSSYM(top)));
            newtRef nLeft     = NewtGetFrameSlot(data, NewtFindSlotIndex(data, NSSYM(left)));
            newtRef nBottom   = NewtGetFrameSlot(data, NewtFindSlotIndex(data, NSSYM(bottom)));
            newtRef nRight    = NewtGetFrameSlot(data, NewtFindSlotIndex(data, NSSYM(right)));
            newtRef nTheBits  = NewtGetFrameSlot(data, NewtFindSlotIndex(data, NSSYM(theBits)));
            int rowbytes = NewtRefToInteger(nRowbytes);
            int top      = NewtRefToInteger(nTop);
            int left     = NewtRefToInteger(nLeft);
            int bottom   = NewtRefToInteger(nBottom);
            int right    = NewtRefToInteger(nRight);
            int width    = right-left;
            int height   = bottom-top;
            unsigned char *theBits = (unsigned char*)NewtRefToData(nTheBits);
            
            // Convert the bitmap data into a CGImageRef
            size_t bufferLength = width * height / 2;
            CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, theBits, bufferLength, NULL);
            size_t bitsPerComponent = 4;
            size_t bitsPerPixel = 4;
            CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceGray();
            CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
            CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
            
            CGImageRef iref = CGImageCreate(width, height,
                                            bitsPerComponent, bitsPerPixel,
                                            rowbytes, colorSpaceRef,
                                            bitmapInfo, provider,
                                            NULL, YES, renderingIntent);
            
            // Invert the image.
            // http://stackoverflow.com/questions/6672517/is-programmatically-inverting-the-colors-of-an-image-possible
            CIImage *coreImage = [CIImage imageWithCGImage:iref];
            CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
            [filter setValue:coreImage forKey:kCIInputImageKey];
            CIImage *result = [filter valueForKey:kCIOutputImageKey];

            // Convert it back to an NS Image
            // http://stackoverflow.com/questions/17386650/converting-ciimage-into-nsimage
            NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:result];
            NSImage *image = [[NSImage alloc] initWithSize:rep.size];
            [image addRepresentation:rep];
            
            // Clean up
            CGImageRelease(iref);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(colorSpaceRef);
            
            return image;
        }
    }
    return nil;
}

@end
