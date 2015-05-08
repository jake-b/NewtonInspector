//
//  InspectorSplitViewController.h
//  NewtonInspector
//
// Copyright (C) 2015 J. Bordens
// License: http://www.gnu.org/licenses/gpl.html GPL version 3 or higher
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//

#import <Cocoa/Cocoa.h>
#import "NewtonInspector.h"

@interface InspectorViewController : NSViewController <NewtonInspectorDelegate, NSTextViewDelegate>
{
    NewtonInspector* _inspector;
    NSTextView*      _outputTextView;
    NSTextView*      _inputTextView;
    NSFont*          _font;
    
    __block dispatch_source_t fileWatchSource;
    bool watchActive;
}

@property (retain, nonatomic) NewtonInspector* inspector;
@property (retain, nonatomic) IBOutlet NSTextView* outputTextView;
@property (retain, nonatomic) IBOutlet NSTextView* inputTextView;
@property (retain, nonatomic) IBOutlet NSFont* font;

- (IBAction)connectInspector:(id)sender;
- (IBAction)installPackage:(id)sender;
- (IBAction)watchPackage:(id)sender;

- (IBAction)clearLog:(id)sender;
- (IBAction)takeScreenshot:(id)sender;

@end
