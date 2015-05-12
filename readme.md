![Screenshot](/images/screenshot.png?raw=true "NewtonInspector Screenshot")

Disclaimer
----------
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even t
he implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public 
License for more details.

License
-------
This is released under GPL 3.0

Requirements
------------

- Mac OS X 10.7 (Lion) 
- USB Serial adapter connected on /dev/usbserial

Introduction
------------

**Note: Current version is hard coded to /dev/usbserial if youe Newton is not connected on this
serial device, then (a) create a symlink (b) edit the code before compiling (c) send a pull request
with a UI to select your serial port!**

This is a Mac OS X native implementation of the "Inspector" window of the Newton Toolkit.

The inspector was a debugging tool which allows you to see print statements, interrogate objects,
and execute code on a connected Newton device.

You'll need to install the standard Toolkit pacakge that comes with NTK.

I added a feature that lets you "Watch" a pacakge for changes on disk.  When a change occurs, it
will:

1. Delete any pacakges with the same signature on the Newton.
2. Install the pacakge

This allows you to use a Mac Classic emulator with the fileshare to the host Mac OS X file system
and auto-upload when the package changes.

Notes and limitations
---------------------
This app is 32-but only, as NEWT/0 does not support 64-bit.

This is a quick-and-drity tool that I wrote for a specific purposes it may contain:

- Unnessary logging statements to clutter your console log
- Memory leaks (I'm not quite sure how NEWT/0 works, and if I need to release anything)
- Crashes
- Unexpected behavior
- Unimplemented sections

Credits
-------
I borrowed parts or inspiration from:

- NEWT/0 -- it compiles NewtonScript and encodes/decodes NOSF objects
- NewTen -- Bhttps://github.com/panicsteve/NewTen
- UnixNPI 1.1.3 by Richard C.I. Li, Chayim I. Kirshen, and Victor Rehorst
- DyneTK - ttps://github.com/MatthiasWM/dynee5/tree/master/DyneTK

The MNP code is based on the code from NewTen, which is based on the code from UnixNPI.
The Inspector code is inspired by (or directly borrowed from) Matthias' DyneTK.

Version History
----------------
1.0 - Initial release
