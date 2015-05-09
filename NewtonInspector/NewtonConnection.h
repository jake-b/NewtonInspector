//
//  NewtonConnection.h
//  NewtonConnection
//
// Copyright (C) 2015 J. Bordens
// based on code from NewTen https://github.com/panicsteve/NewTen
// NewTen was based on Unux NPI by Richard C.I. Li, Chayim I. Kirshen, Victor Rehorst
// License: http://www.gnu.org/licenses/gpl.html GPL version 3 or higher
//
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// Based on UnixNPI by
// Richard C.I. Li, Chayim I. Kirshen, Victor Rehorst
// Objective-C adaptation by Steven Frank <stevenf@panic.com>
//

#import <Foundation/Foundation.h>
#include "TPCircularBuffer.h"
#include <termios.h>

#define MAX_HEAD_LEN 256
#define MAX_INFO_LEN 256

@interface NewtonConnection : NSObject 
{
	unsigned char frameStart[3];
	unsigned char frameEnd[2];
	unsigned char ldFrame[5]; 
	int newtFD;
	struct termios newtTTY;
	BOOL canceled;
    TPCircularBuffer inBuffer;

    unsigned int ltSeqNo;
    unsigned char lastSeenFrame;
    bool connected;
}


+ (NewtonConnection*)connectionWithDevicePath:(NSString*)devicePath speed:(int)speed;

- (void)cancel;
- (void)disconnect;

- (int)receiveBytes:(unsigned char*)frame ofLength:(int)length;
- (int)sendBytes:(unsigned char*)bytes length:(int)length;
- (int)scanForBytes:(unsigned char*)needle ofLength:(int)length;

- (int)receiveFrame:(unsigned char*)frame;
- (void) beginStream;
- (void)sendKeepAlive;
- (int) bytesAvailable;

- (bool)isConnected;
@end

static unsigned char lrFrame[] =
{
    '\x17', // Length of header
    '\x01', // Type indication LR frame
    '\x02', // Constant parameter 1
    '\x01', '\x06', '\x01', '\x00', '\x00', '\x00', '\x00', '\xff', // Constant parameter 2
    '\x02', '\x01', '\x02', // Octet-oriented framing mode
    '\x03', '\x01', '\x01', // k = 1
    '\x04', '\x02', '\x40', '\x00', // N401 = 64
    '\x08', '\x01', '\x03' // N401 = 256 & fixed LT, LA frames
};
