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
#include <OpenGL/gl.h>
#include <time.h>

#import "FXScreenView.h"

static int closestPowerOfTwo(int number);
static CVReturn ScreenRenderCallback(CVDisplayLinkRef displayLink,
									 const CVTimeStamp *now,
									 const CVTimeStamp *outputTime,
									 CVOptionFlags flagsIn,
									 CVOptionFlags *flagsOut,
									 void *displayLinkContext);

@interface FXScreenView ()

- (void) prepareIOSurfaceWithRef:(IOSurfaceRef) surfaceRef;
- (void) resetProjection;

@end

@implementation FXScreenView
{
	GLuint _screenTextureId;
	CVDisplayLinkRef _displayLink;
	IOSurfaceRef _surfaceRef;
	NSPoint _texturePos;
	NSInteger _surfacePitch;
}

#pragma mark - Initialize, Dealloc

- (void) dealloc
{
	CVDisplayLinkRelease(self->_displayLink);
	
    glDeleteTextures(1, &self->_screenTextureId);
	
	if (self->_surfaceRef) {
		CFRelease(self->_surfaceRef);
	}
}

- (void) awakeFromNib
{
	self->_surfaceRef = NULL;
}

#pragma mark - Cocoa Callbacks

- (void) prepareOpenGL
{
    [super prepareOpenGL];
	
    NSLog(@"FXScreenView/prepareOpenGL");
    
	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1;
	[[self openGLContext] setValues:&swapInt
					   forParameter:NSOpenGLCPSwapInterval];
 
	// Create a display link capable of being used with all active displays
	CVDisplayLinkCreateWithActiveCGDisplays(&self->_displayLink);
 
	// Set the renderer output callback function
	CVDisplayLinkSetOutputCallback(self->_displayLink, &ScreenRenderCallback, (__bridge void *) self);
 
	// Set the display link for the current renderer
	CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
	CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(self->_displayLink, cglContext, cglPixelFormat);
 
	// Activate the display link
	CVDisplayLinkStart(self->_displayLink);
	
    glClearColor(0, 0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glGenTextures(1, &self->_screenTextureId);
}

- (void) drawRect:(NSRect) dirtyRect
{
	if (!self->_surfaceRef) {
		[[self->wrapper remoteObjectProxy] describeScreenWithHandler:^(BOOL isReady, NSInteger surfaceId) {
			if (isReady) {
				[self prepareIOSurfaceWithRef:IOSurfaceLookup((IOSurfaceID) surfaceId)];
			}
		}];
		return;
	}
	
    NSOpenGLContext *nsContext = [self openGLContext];
    [nsContext makeCurrentContext];
    
    glClear(GL_COLOR_BUFFER_BIT);
	
	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, self->_screenTextureId);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	
	IOSurfaceLock(self->_surfaceRef, kIOSurfaceLockReadOnly, NULL);
	void *addr = IOSurfaceGetBaseAddress(self->_surfaceRef);
	for (int y = 0; y < self->_screenHeight; y++, addr += self->_surfacePitch) {
		glTexSubImage2D(GL_TEXTURE_2D, 0, 0, y, (GLsizei) self->_screenWidth, 1,
						GL_BGR, GL_UNSIGNED_BYTE, addr);
	}
	IOSurfaceUnlock(self->_surfaceRef, kIOSurfaceLockReadOnly, NULL);
	
	NSSize size = [self bounds].size;
	CGFloat offset = 0;
	
	glBegin(GL_QUADS);
	glTexCoord2f(0.0, 0.0);
	glVertex3f(-offset, 0.0, 0.0);
	glTexCoord2f(self->_texturePos.x, 0.0);
	glVertex3f(size.width + offset, 0.0, 0.0);
	glTexCoord2f(self->_texturePos.x, self->_texturePos.y);
	glVertex3f(size.width + offset, size.height, 0.0);
	glTexCoord2f(0.0, self->_texturePos.y);
	glVertex3f(-offset, size.height, 0.0);
	glEnd();
	glDisable(GL_TEXTURE_2D);
	
	[nsContext flushBuffer];
}

- (void) reshape
{
    [[self openGLContext] makeCurrentContext];
    [[self openGLContext] update];
    
    [self resetProjection];
    
    glClear(GL_COLOR_BUFFER_BIT);
}

- (void) prepareIOSurfaceWithRef:(IOSurfaceRef) surfaceRef
{
	self->_surfaceRef = surfaceRef;
	GLint bytesPerPixel = (GLint) IOSurfaceGetBytesPerElement(self->_surfaceRef);
	GLint surfaceWidth = (GLint) IOSurfaceGetWidth(self->_surfaceRef);
	GLint surfaceHeight = (GLint) IOSurfaceGetHeight(self->_surfaceRef);
	GLsizei textureWidth = closestPowerOfTwo(surfaceWidth);
	GLsizei textureHeight = closestPowerOfTwo(surfaceHeight);
	
	self->_surfacePitch = surfaceWidth * bytesPerPixel;
	self->_texturePos = NSMakePoint((GLfloat) self->_screenWidth / (GLfloat) textureWidth,
									(GLfloat) self->_screenHeight / (GLfloat) textureHeight);
	
	NSOpenGLContext *nsContext = [self openGLContext];
	[nsContext makeCurrentContext];
	
	glEnable(GL_TEXTURE_2D);
	
	glBindTexture(GL_TEXTURE_2D, self->_screenTextureId);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	
	glTexImage2D(GL_TEXTURE_2D, 0, bytesPerPixel, textureWidth, textureHeight,
				 0, GL_BGR, GL_UNSIGNED_BYTE, NULL);
	
	glDisable(GL_TEXTURE_2D);
	
	[self resetProjection];
}

#pragma mark - Private methods

- (void) resetProjection
{
    NSSize size = [self bounds].size;
    
    glViewport(0, 0, size.width, size.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    
	if (!self->_screenRotated) {
	 	glOrtho(0, size.width, size.height, 0, -1, 1);
	}
	else
	{
		glRotatef(90.0, 0.0, 0.0, 1.0);
	 	glOrtho(0, size.width, size.height, 0, -1, 5);
	}
    
    glMatrixMode(GL_MODELVIEW);
}

@end

#pragma mark - CV

static CVReturn ScreenRenderCallback(CVDisplayLinkRef displayLink,
									 const CVTimeStamp *now,
									 const CVTimeStamp *outputTime,
									 CVOptionFlags flagsIn,
									 CVOptionFlags *flagsOut,
									 void *displayLinkContext)
{
	@autoreleasepool {
		FXScreenView *sv = (__bridge FXScreenView *) displayLinkContext;
		[sv setNeedsDisplay:YES];
	}
	
	return kCVReturnSuccess;
}

static int closestPowerOfTwo(int number)
{
	int rv = 1;
	while (rv < number) {
		rv *= 2;
	}
	return rv;
}
