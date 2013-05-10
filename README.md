SM1Password Sync
================

SM1Password Sync is a third party application that allows you to sync your 1Password keychain with your iOS devices. The official 1Password USB syncing application can be found on their [website](http://blog.agilebits.com/tag/1password-usb-sync/).

*This is a third party project developed outside the auspices of AgileBits. Nothing here should imply their cooperation, association, or endorsement.*

System Requirements
-------------------
* Mac OS X 10.6.8 or newer
* Xcode 3.2.6 or newer
* iTunes 11 or newer
* 1Password 3.8.20 for Mac
* 1Password 4 for iOS

Code Libraries
--------------
* [jsmn](https://bitbucket.org/zserge/jsmn)
* [MobileDeviceAccess](https://bitbucket.org/tristero/mobiledeviceaccess)
* [ZipArchive](http://code.google.com/p/ziparchive)

	### Notes:
	* Included is a header file that has been floating around the internet called MobileDevice.h. The copy included in this project is a consolidated version of this header file, and it is used for accessing Apple's private MobileDevice.framework.
	* There was no license posted with MobileDeviceAccess, and this project uses very modified version of that code. 

Icons
-----
* [Iconic](http://somerandomdude.com/work/iconic/)

Disclaimer
----------
It is mentioned with the code license below, however I am in no way responsible for any fault in this code and/or damage it may cause to the 1Password keychain files. USE AT YOUR OWN RISK. If you find a bug, please report an issue or submit a pull request and I will get to it as soon as possible. 

License
-------
	Copyright (c) 2013, Sam Marshall
	All rights reserved.
	
	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	3. All advertising materials mentioning features or use of this software must display the following acknowledgement:
		This product includes software developed by the Sam Marshall.
	4. Neither the name of the Sam Marshall nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY Sam Marshall ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Sam Marshall BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.