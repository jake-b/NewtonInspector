//
//  NewtonConnection.m
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
#import "NewtonConnection.h"
#import "NSFileManager+DirectoryLocations.h"

@interface NewtonConnection (Private)

- (id)initWithDevicePath:(NSString*)devicePath speed:(int)speed;
- (id)initWithEinsteinNamedPipes;
- (void)calculateFCSWithWords:(unsigned short*)fcsWord octet:(unsigned char)octet;

- (BOOL)sendFrame:(unsigned char*)info header:(unsigned char*)head length:(int)infoLen;
- (void)sendLAFrame:(unsigned char)seqNo;
- (void)sendLTFrame:(unsigned char*)info length:(int)infoLen seqNo:(unsigned char)seqNo;
- (int)waitForLAFrame:(unsigned char)seqNo;
- (int)waitForLDFrame;
- (void)close;

@end


@implementation NewtonConnection

+ (NewtonConnection*)connectionWithDevicePath:(NSString*)devicePath speed:(int)speed
{
	return [[[NewtonConnection alloc] initWithDevicePath:devicePath speed:speed] autorelease];
}

+ (NewtonConnection*)connectionWithEinsteinNamedPipes
{
    return [[[NewtonConnection alloc] initWithEinsteinNamedPipes] autorelease];
}

- (id)init {
    if ( (self = [super init]) )
    {
        canceled = NO;
        
        // Initialize re-usable frame structures
        
        frameStart[0] = '\x16';
        frameStart[1] = '\x10';
        frameStart[2] = '\x02';
        
        frameEnd[0] = '\x10';
        frameEnd[1] = '\x03';
        
        ldFrame[0] = '\x04';	// Length of header
        ldFrame[1] = '\x02',	// Type indication LD frame
        ldFrame[2] = '\x01';
        ldFrame[3] = '\x01';
        ldFrame[4] = '\xff';
    }
    return self;
}

- (id)initWithEinsteinNamedPipes {
    if ( (self = [self init]) ) {
        NSString* einsteinAppSupportFolder = [[NSFileManager defaultManager] applicationSupportDirectoryWithPathComponent:@"Einstein Emulator"];
        
        // Note the reversed pipes.  Our send is Einstein's receive.
        NSString* txPipeName = [einsteinAppSupportFolder stringByAppendingPathComponent:@"ExtrSerPortSend"];
        NSString* rxPipeName = [einsteinAppSupportFolder stringByAppendingPathComponent:@"ExtrSerPortRecv"];
        
        if ((rxfd = open([txPipeName fileSystemRepresentation], O_RDWR)) == -1) {
            NSLog(@"Unable to open receive pipe: %@", rxPipeName);
            return nil;
        }

        if ((txfd = open([rxPipeName fileSystemRepresentation], O_RDWR)) == -1) {
            NSLog(@"Unable to open transmit pipe: %@", txPipeName);
            return nil;
        }
        
        // Create the circular buffer
        TPCircularBufferInit(&inBuffer, 512);
        
        // Set connection status
        connected = YES;
    }
    return self;
}

- (id)initWithDevicePath:(NSString*)devicePath speed:(int)speed
{
	if ( (self = [self init]) )
	{
        int newtFD = -1;
		// Open the serial port
        if ( (newtFD = open([devicePath fileSystemRepresentation], O_RDWR)) == -1 ) {
            NSLog(@"Error while opening port: %d", errno);
			return nil;
		}
		
		// Get the current device settings 
		tcgetattr(newtFD, &newtTTY);
		
		// Change the device settings 
		newtTTY.c_iflag = IGNBRK | INPCK;
		newtTTY.c_oflag = 0;
		newtTTY.c_cflag = (CREAD | CLOCAL | CS8) & ~PARENB & ~PARODD & ~CSTOPB;
		newtTTY.c_lflag = 0;
		newtTTY.c_cc[VMIN] = 1;
		newtTTY.c_cc[VTIME] = 0;
		
		// Select the communication speed 
		
		switch ( speed ) 
		{
			case 2400 :
				cfsetospeed(&newtTTY, B2400);
				cfsetispeed(&newtTTY, B2400);
				break;

			case 4800 :
				cfsetospeed(&newtTTY, B4800);
				cfsetispeed(&newtTTY, B4800);
				break;

			case 9600 :
				cfsetospeed(&newtTTY, B9600);
				cfsetispeed(&newtTTY, B9600);
				break;

			case 19200 :
				cfsetospeed(&newtTTY, B19200);
				cfsetispeed(&newtTTY, B19200);
				break;

			case 38400 :
				cfsetospeed(&newtTTY, B38400);
				cfsetispeed(&newtTTY, B38400);
				break;

			case 57600 :
				cfsetospeed(&newtTTY, B57600);
				cfsetispeed(&newtTTY, B57600);
				break;

			case 115200 :
				cfsetospeed(&newtTTY, B115200);
				cfsetispeed(&newtTTY, B115200);
				break;

			case 230400 :
				cfsetospeed(&newtTTY, B230400);
				cfsetispeed(&newtTTY, B230400);
				break;

			default :
				cfsetospeed(&newtTTY, B38400);
				cfsetispeed(&newtTTY, B38400);
				break;
		}
		
		// Flush the device and restart input and output 
		
		tcflush(newtFD, TCIOFLUSH);
		tcflow(newtFD, TCOON);
		
		// Update the new device settings 
		
		tcsetattr(newtFD, TCSANOW, &newtTTY);
        
        // Create the circular buffer
        TPCircularBufferInit(&inBuffer, 512);
        
        // Set connection status
        connected = YES;
        
        txfd = rxfd = newtFD;
	}
	
	return self;
}


- (void)close {
    // Close the serial port
    bool singleFileDescriptor = (txfd >= 0 && txfd == rxfd);
    
    if ( txfd >= 0 ) {
        close(txfd);
        txfd = -1;
    }
    
    if ( !singleFileDescriptor && rxfd >= 0 ) {
        close(rxfd);
        rxfd = -1;
    }
}

- (void)dealloc
{
    [self close];
    
    TPCircularBufferCleanup(&inBuffer);
    
    [super dealloc];
}


- (void)calculateFCSWithWords:(unsigned short*)fcsWord octet:(unsigned char)octet
//
// Calculate frame checksum
//
{
	int i;
	unsigned char pow = 1;

	for ( i = 0; i < 8; i++ ) 
	{
		if ( (((*fcsWord % 256) & 0x01) == 0x01) ^ ((octet & pow) == pow) )
			*fcsWord = (*fcsWord / 2) ^ 0xa001;
		else
			*fcsWord /= 2;

		pow *= 2;
	}
}

- (bool)isConnected {
    return connected;
}

- (void)cancel
{
	canceled = YES;
}


- (void)disconnect
{
    canceled = YES;
    
	if ( txfd >= 0 )
	{
		// Wait for all buffer sent
		tcdrain(txfd);
		[self sendFrame:NULL header:ldFrame length:0];
        [self close];
	}
    connected = NO;
    
	//ErrHandler("User interrupted, connection stopped!!");
}


- (int)receiveFrame:(unsigned char*)frame
{
	//char errMesg[] = "Error in reading from Newton device, connection stopped!!";
	int state;
	unsigned char buf;
	unsigned short fcsWord = 0;
	int i = 0;
	fd_set fds;
	struct timeval timeout = { 1, 0 };
		
	// Wait for head 
	
	state = 0;
	
	while ( state < 3 ) 
	{
        if (canceled) return -1;
        
        FD_ZERO(&fds);
		FD_SET(rxfd, &fds);
        int maxfd = MAX(txfd, rxfd);
        if ( select(maxfd+1, &fds, NULL, NULL, &timeout) < 1 ) {
            NSLog(@"Waititng on select");
            return 0;
        }
        
        if ( read(rxfd, &buf, 1) < 0 ) {
            NSLog(@"Error in reading from Newton device, connection stopped!!");
			return -1; //ErrHandler(errMesg);
        }
        
		switch ( state ) 
		{
			case 0 :
				if ( buf == frameStart[0] )
					++state;
				break;
				
			case 1 :
				if ( buf == frameStart[1] )
					++state;
				else
					state = 0;
				break;
				
			case 2:
				if ( buf == frameStart[2] )
					++state;
				else
					state = 0;
				break;
		}
	}
	
	// Wait for tail 
	
	state = 0;
	
	while ( state < 2 ) 
	{
        if ( read(rxfd, &buf, 1) < 0 ) {
            NSLog(@"Error in reading from Newton device, connection stopped!!");
			return -1; //ErrHandler(errMesg);
        }
			
		switch ( state ) 
		{
			case 0 :
				if ( buf == '\x10' )
					++state;
				else 
				{
					[self calculateFCSWithWords:&fcsWord octet:buf];
					
					if ( i < MAX_HEAD_LEN + MAX_INFO_LEN ) 
					{
						frame[i] = buf;
						++i;
					}
					else
						return -1;
				}
				break;
				
			case 1 :
				if ( buf == '\x10' ) 
				{
					[self calculateFCSWithWords:&fcsWord octet:buf];

					if ( i < MAX_HEAD_LEN + MAX_INFO_LEN ) 
					{
						frame[i] = buf;
						++i;
					}
					else
						return -1;
						
					state = 0;
				}
				else 
				{
					if ( buf == '\x03' ) 
					{
						[self calculateFCSWithWords:&fcsWord octet:buf];
						++state;
					}
					else
						return -1;
				}
				break;
			}
		}
		
	// Check FCS 
	
    if ( read(rxfd, &buf, 1) < 0 ) {
        NSLog(@"Error in reading from Newton device, connection stopped!!");
		return -1; //ErrHandler(errMesg);
    }
		
    if ( fcsWord % 256 != buf ) {
        NSLog(@"Error in reading from Newton device, connection stopped!!");
		return -1;
    }

    if ( read(rxfd, &buf, 1) < 0 ) {
        NSLog(@"Error in reading from Newton device, connection stopped!!");
		return -1; //ErrHandler(errMesg);
    }

    if ( fcsWord / 256 != buf ) {
        NSLog(@"Error in reading from Newton device, connection stopped!!");
		return -1;
    }

    if ( frame[1] == '\x02' ) {
        NSLog(@"Error in reading from Newton device, connection stopped!!");
		return -1;//ErrHandler("Newton device disconnected, connection stopped!!");
    }
	return i;
}


- (BOOL)sendFrame:(unsigned char*)info header:(unsigned char*)head length:(int)infoLen
{
	//char errMesg[] = "Error in writing to Newton device, connection stopped!!";
	unsigned short fcsWord = 0;
	unsigned char buf;
	int i;
	
	// Send frame start 

    if ( write(txfd, frameStart, 3) < 0 ) {
        NSLog(@"Error in writing to Newton device, connection stopped!!");
        return NO;
    }
	// Send frame head 
	
	for ( i = 0; i <= head[0]; i++ ) 
	{
		[self calculateFCSWithWords:&fcsWord octet:head[i]];
		
		if ( write(txfd, &head[i], 1) < 0 )
			return NO;
			
		if ( head[i] == frameEnd[0] ) 
		{
			if ( write(txfd, &head[i], 1) < 0 )
				return NO;
		}
	}
	
	// Send frame information 
	
	if ( info != NULL ) 
	{
		for ( i = 0; i < infoLen; i++ ) 
		{
			[self calculateFCSWithWords:&fcsWord octet:info[i]];
		
			if ( write(txfd, &info[i], 1) < 0 )
				return NO;
			
			if ( info[i] == frameEnd[0] ) 
			{
				if ( write(txfd, &info[i], 1) < 0 )
					return NO;
			}
		}
	}

	// Send frame end 

	if ( write(txfd, frameEnd, 2) < 0 )
		return NO;
		
	[self calculateFCSWithWords:&fcsWord octet:frameEnd[1]];

	// Send FCS 
	
	buf = fcsWord % 256;
	
	if ( write(txfd, &buf, 1) < 0 )
		return NO;
		
	buf = fcsWord / 256;
	
	if ( write(txfd, &buf, 1) < 0 )
		return NO;
		
	return YES;
}


- (void)sendLAFrame:(unsigned char)seqNo
{
    NSLog(@"SendLAFrame: %d", seqNo);
	unsigned char laFrameHead[4] = 
	{
		'\x03', // Length of header 
		'\x05', // Type indication LA frame 
		'\x00', // Sequence number 
		'\x01'	// N(k) = 1 
	};

	laFrameHead[2] = seqNo;
	[self sendFrame:NULL header:laFrameHead length:0];
}


- (void)sendLTFrame:(unsigned char*)info length:(int)infoLen seqNo:(unsigned char)seqNo
{
	unsigned char ltFrameHead[3] = 
	{
		'\x02', // Length of header 
		'\x04', // Type indication LT frame 
	};
	
	ltFrameHead[2] = seqNo;
	[self sendFrame:info header:ltFrameHead length:infoLen];
}


- (int)waitForLAFrame:(unsigned char)seqNo
{
	unsigned char frame[MAX_HEAD_LEN + MAX_INFO_LEN];

	do 
	{
		while ( [self receiveFrame:frame] < 0 )
		{
			if ( canceled )
				break;
		}
		
		if ( canceled )
			break;
		
        if ( frame[1] == '\x04' ) {
            lastSeenFrame = frame[2];
			[self sendLAFrame:frame[2]];
        }
	}
	while ( frame[1] != '\x05' );
	
	if ( frame[2] == seqNo )
		return 0;
	else
		return -1;
}


- (int)waitForLDFrame
{
	//char errMesg[] = "Error in reading from Newton device, connection stopped!!";
	int state;
	unsigned char buf;
	unsigned short fcsWord = 0;
		
	// Wait for head 

	state = 0;

	while ( state < 5 )
	{
		if ( read(rxfd, &buf, 1) < 0 )
			return -1;//ErrHandler(errMesg);

		switch ( state ) 
		{
			case 0 :
				if ( buf == frameStart[0] )
					++state;
				break;
				
			case 1 :
				if ( buf == frameStart[1] )
					++state;
				else
					state = 0;
				break;
				
			case 2 :
				if ( buf == frameStart[2] )
					++state;
				else
					state = 0;
				break;
				
			case 3 :
				[self calculateFCSWithWords:&fcsWord octet:buf];
				++state;
				break;
				
			case 4 :
				if ( buf == '\x02' ) 
				{
					[self calculateFCSWithWords:&fcsWord octet:buf];
					++state;
				}
				else 
				{
					state = 0;
					fcsWord = 0;
				}
				break;
		}
	}
	
	// Wait for tail 

	state = 0;

	while ( state < 2 ) 
	{
		if ( read(rxfd, &buf, 1) < 0 )
			return -1;//ErrHandler(errMesg);

		switch ( state ) 
		{
			case 0 :
				if ( buf == '\x10' )
					++state;
				else
					[self calculateFCSWithWords:&fcsWord octet:buf];
				break;
				
			case 1 :
				if ( buf == '\x10' ) 
				{
					[self calculateFCSWithWords:&fcsWord octet:buf];
					state = 0;
				}
				else 
				{
					if ( buf == '\x03' ) 
					{
						[self calculateFCSWithWords:&fcsWord octet:buf];
						++state;
					}
					else
						return -1;
				}
				break;
		}
	}
		
	// Check FCS 

	if ( read(rxfd, &buf, 1) < 0 )
		return -1;//ErrHandler(errMesg);

	if ( fcsWord % 256 != buf )
		return -1;

	if ( read(rxfd, &buf, 1) < 0 )
		return -1; //ErrHandler(errMesg);

	if ( fcsWord / 256 != buf )
		return -1;

	return 0;
}

- (int)bytesAvailable {
    NSLog(@"bytesAvailable");
    int32_t availableBytes = 0;
    TPCircularBufferTail(&inBuffer, &availableBytes);
    
    if (availableBytes) return availableBytes;

    unsigned char recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
 
    // Try and get some buytes
    int recvBytes = [self receiveFrame:recvBuf];
    if (recvBytes > 0 && (recvBuf[1] == '\x04')) {
        // got some good data.
        
        // send the Ack
        lastSeenFrame = recvBuf[2];
        [self sendLAFrame:recvBuf[2]];

        // save it to the buffer
        TPCircularBufferProduceBytes(&inBuffer, &recvBuf[3], recvBytes-3);
        availableBytes += recvBytes - 3;
    } else if (recvBytes < 0)
        return -1;
    
    return availableBytes;
}

- (int)receiveBytes:(unsigned char*)frame ofLength:(int)length {
    NSLog(@"receiveBytes");
    int remaining = length;
    unsigned char* pos = frame;
    while (remaining > 0) {
        int toRead = remaining > 256?256:remaining;
        
        int bytesRead;
        if ((bytesRead = [self receiveBytes2:pos ofLength:toRead]) < 0)
            return -1;
        
        pos += bytesRead;
        remaining -= bytesRead;
        NSLog(@"Requested %d, Read %d: %d left of %d", toRead, bytesRead, remaining, length);
    }
    return 0;
}

- (int)receiveBytes2:(unsigned char*)frame ofLength:(int)length
{
    NSLog(@"receiveBytes");
    NSAssert(length<=256, @"recediveBytes2 only supports 256 byte packets");
    
    int32_t availableBytes = 0;
    unsigned char recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
    memset(recvBuf, 0, MAX_HEAD_LEN + MAX_INFO_LEN);
    
    TPCircularBufferTail(&inBuffer, &availableBytes);
    int retries = 10;
    while (availableBytes < length) {
        int recvBytes;
        
        if ( canceled )
            return -1;
        
        // Wait for the response
        while ( (recvBytes = [self receiveFrame:recvBuf]) <= 0 || (recvBuf[1] != '\x04')) {
            if (retries-- <= 0) return -1;
            if ( canceled )
                return -1;
        }
        
        // Send the Ack
        [self sendLAFrame:recvBuf[2]];
        
        TPCircularBufferProduceBytes(&inBuffer, &recvBuf[3], recvBytes-3);
        availableBytes += recvBytes - 3;
    }
    
    uint8_t* tail = TPCircularBufferTail(&inBuffer, &availableBytes);
    if (frame) memcpy(frame, tail, length);
    TPCircularBufferConsume(&inBuffer, length);
    
    return length;
}

- (int)sendBytes:(unsigned char*)bytes length:(int)length {
    unsigned char *src = bytes;
    unsigned int size = length;
    
    while (size>MAX_INFO_LEN) {
        do {
            [self sendLTFrame:src length:MAX_INFO_LEN seqNo:ltSeqNo];
            if ( canceled )
                return -1;
        } while ( [self waitForLAFrame:ltSeqNo] < 0 );

        ltSeqNo++; // Increment the sequence
        
        src += MAX_INFO_LEN;
        size -= MAX_INFO_LEN;
    }
    // If the size was less than MAX_INFO, then this is where it gets sent
    // If we sent it in blocks, then this sends the remainder
    do {
        [self sendLTFrame:src length:size seqNo:ltSeqNo];
        if ( canceled )
            return -1;
    } while ( [self waitForLAFrame:ltSeqNo] < 0 );
    
    ltSeqNo++; // Increment the sequence

    return 0;
}

- (int)scanForBytes:(unsigned char*)needle ofLength:(int)length {
    int pos = 0;
    unsigned char c;
    while (1) {
        if ([self receiveBytes:&c ofLength:1] < 0)
            return -1;
        if (c == needle[pos]) {
            pos++;
            if (pos >= length) return 1;
        } else return 0;
    }
}

- (void) beginStream {
    unsigned char recvBuf[MAX_HEAD_LEN + MAX_INFO_LEN];
    
    do {
        while ( [self receiveFrame:recvBuf] < 0 )
        {
            if ( canceled )
                break;
        }
        
        if ( canceled )
            break;
    }
    while ( recvBuf[1] != '\x01' );
    
    if ( canceled )
        return;
    
    do {
        [self sendFrame:NULL header:lrFrame length:0];
    } 
    while ( [self waitForLAFrame:ltSeqNo] < 0 && !canceled );
    
    if ( canceled )
        return;
    
    ++ltSeqNo;
}

- (void) startKeepAlive {
  //  [self performSelector:@selector(keepAlive) withObject:nil afterDelay:3.0];
}

- (void) stopKeepAliveTimer {
}

-(void)sendKeepAlive {
    NSLog(@"sendPing");
    [self sendLAFrame:lastSeenFrame];
//    [self performSelector:@selector(keepAlive) withObject:nil afterDelay:3.0];
}

@end
