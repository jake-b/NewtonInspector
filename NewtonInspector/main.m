//
//  main.m
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

#import "NewtFns.h"
#import "NewtEnv.h"
#import "NewtObj.h"
#import "NewtBC.h"
#import "NewtNSOF.h"

void yyerror (char const *s) {
    fprintf (stderr, "%s\n", s);
}


int main(int argc, const char * argv[]) {
    // initialize the local interpreter and compiler
    NewtInit(argc, (const char**)argv, 0);
    NcSetGlobalVar(NSSYM(printLength), NSINT(9999));
    NcSetGlobalVar(NSSYM(printDepth), NSINT(30));
    
    NEWT_INDENT = 0;
    NEWT_DUMPBC = 0;
    NEWT_MODE_NOS2 = true;

    // Start the Application
    return NSApplicationMain(argc, argv);
    
}
