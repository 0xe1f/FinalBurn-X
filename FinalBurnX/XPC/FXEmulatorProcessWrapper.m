/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014-2016 Akop Karapetyan
 **
 ** This program is free software; you can redistribute it and/or modify
 ** it under the terms of the GNU General Public License as published by
 ** the Free Software Foundation; either version 2 of the License, or
 ** (at your option) any later version.
 **
 ** This program is distributed in the hope that it will be useful,
 ** but WITHOUT ANY WARRANTY; without even the implied warranty of
 ** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ** GNU General Public License for more details.
 **
 ** You should have received a copy of the GNU General Public License
 ** along with this program; if not, write to the Free Software
 ** Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 **
 ******************************************************************************
 */
#import "FXEmulatorProcessWrapper.h"

#import "OpenEmuXPCCommunicator/OEXPCCAgentConfiguration.h"
#import "OpenEmuXPCCommunicator/OEXPCCAgent.h"

#import "FXEmulationCommunication.h"

@implementation FXEmulatorProcessWrapper
{
	NSTask *_processTask;
	NSXPCConnection *_processConnection;
}

- (void) setUpWithArchive:(NSString *) archive
					  uid:(NSString *) uid
{
	if (!uid) {
		uid = [[NSUUID UUID] UUIDString];
	}
	
	self->_archive = [archive copy];
	self->_uid = [uid copy];
	
	OEXPCCAgentConfiguration *configuration = [OEXPCCAgentConfiguration defaultConfiguration];
	
	self->_processTask = [[NSTask alloc] init];
	[self->_processTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"Emulator"
																	  ofType:nil]];
	[self->_processTask setArguments:@[
									   [configuration agentServiceNameProcessArgument],
									   [configuration processIdentifierArgumentForIdentifier:self->_uid],
									   self->_archive
									   ]];
	[_processTask launch];
	
	[[OEXPCCAgent defaultAgent] retrieveListenerEndpointForIdentifier:self->_uid
													completionHandler:^(NSXPCListenerEndpoint *endpoint)
	 {
		 self->_processConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
		 [self->_processConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(FXEmulationCommunication)]];
		 [self->_processConnection resume];
		 
		 self->_remoteObjectProxy = [self->_processConnection remoteObjectProxy];
		 
		 [self->_delegate connectionDidEstablish:self];
	 }];
}

- (void) terminate
{
	[self->_processTask terminate];
}

@end
