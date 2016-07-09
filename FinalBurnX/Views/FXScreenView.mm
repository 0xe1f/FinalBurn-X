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

@interface FXScreenView ()

+ (int)powerOfTwoClosestTo:(int)number;
- (void)resetProjection;

@end

@implementation FXScreenView

#pragma mark - Initialize, Dealloc

- (void)dealloc
{
    glDeleteTextures(1, &screenTextureId);
    free(self->texture);
    
    [super dealloc];
}

- (void)awakeFromNib
{
    self->renderLock = [[NSLock alloc] init];
}

#pragma mark - Cocoa Callbacks

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    
    NSLog(@"FXScreenView/prepareOpenGL");
    
    [self->renderLock lock];
    
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    glClearColor(0, 0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glGenTextures(1, &screenTextureId);
    
    [self->renderLock unlock];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self->renderLock lock];
    
    NSOpenGLContext *nsContext = [self openGLContext];
    [nsContext makeCurrentContext];
    
    glClear(GL_COLOR_BUFFER_BIT);
	
    GLfloat coordX = (GLfloat)self->imageWidth / self->textureWidth;
    GLfloat coordY = (GLfloat)self->imageHeight / self->textureHeight;
    
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, screenTextureId);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    
    NSSize size = [self bounds].size;
    CGFloat offset = 0;
    
    glBegin(GL_QUADS);
    glTexCoord2f(0.0, 0.0);
    glVertex3f(-offset, 0.0, 0.0);
    glTexCoord2f(coordX, 0.0);
    glVertex3f(size.width + offset, 0.0, 0.0);
    glTexCoord2f(coordX, coordY);
    glVertex3f(size.width + offset, size.height, 0.0);
    glTexCoord2f(0.0, coordY);
    glVertex3f(-offset, size.height, 0.0);
    glEnd();
    glDisable(GL_TEXTURE_2D);
    
    [nsContext flushBuffer];
    
    [self->renderLock unlock];
}

- (void)reshape
{
    [self->renderLock lock];
    
    [[self openGLContext] makeCurrentContext];
    [[self openGLContext] update];
    
    [self resetProjection];
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    [self->renderLock unlock];
}

#pragma mark - FXVideoRenderDelegate

- (void)initTextureOfWidth:(int)width
                    height:(int)height
                 isRotated:(BOOL)rotated
             bytesPerPixel:(int)bytesPerPixel
{
    NSLog(@"FXScreenView/initTexture");
    
    [self->renderLock lock];
    
    NSOpenGLContext *nsContext = [self openGLContext];
    [nsContext makeCurrentContext];
    
    free(self->texture);
    
    self->imageWidth = width;
    self->imageHeight = height;
    self->isRotated = rotated;
    self->textureWidth = [FXScreenView powerOfTwoClosestTo:self->imageWidth];
    self->textureHeight = [FXScreenView powerOfTwoClosestTo:self->imageHeight];
    self->textureBytesPerPixel = bytesPerPixel;
    self->screenSize = NSMakeSize((CGFloat)width, (CGFloat)height);
    
    int texSize = self->textureWidth * self->textureHeight * bytesPerPixel;
    self->texture = (unsigned char *)malloc(texSize);
    
    glEnable(GL_TEXTURE_2D);
    
    glBindTexture(GL_TEXTURE_2D, screenTextureId);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, bytesPerPixel,
                 self->textureWidth, self->textureHeight,
                 0, GL_BGR, GL_UNSIGNED_BYTE, self->texture);
    
    glDisable(GL_TEXTURE_2D);
    
    [self resetProjection];
    
    [self->renderLock unlock];
}

- (void)renderFrame:(unsigned char *)bitmap
{
    [self->renderLock lock];
    
    NSOpenGLContext *nsContext = [self openGLContext];
    [nsContext makeCurrentContext];
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    GLfloat coordX = (GLfloat)self->imageWidth / self->textureWidth;
    GLfloat coordY = (GLfloat)self->imageHeight / self->textureHeight;
    
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, screenTextureId);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    
    for (int y = 0; y < self->imageHeight; y += 1) {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, y, self->imageWidth, 1,
                        GL_BGR, GL_UNSIGNED_BYTE,
                        bitmap + y * self->imageWidth * self->textureBytesPerPixel);
    }
    
    NSSize size = [self bounds].size;
    CGFloat offset = 0;
    
    glBegin(GL_QUADS);
    glTexCoord2f(0.0, 0.0);
    glVertex3f(-offset, 0.0, 0.0);
    glTexCoord2f(coordX, 0.0);
    glVertex3f(size.width + offset, 0.0, 0.0);
    glTexCoord2f(coordX, coordY);
    glVertex3f(size.width + offset, size.height, 0.0);
    glTexCoord2f(0.0, coordY);
    glVertex3f(-offset, size.height, 0.0);
    glEnd();
    glDisable(GL_TEXTURE_2D);
    
    [nsContext flushBuffer];
    
    [self->renderLock unlock];
}

#pragma mark - Public methods

- (NSSize)screenSize
{
    return self->screenSize;
}

#pragma mark - Private methods

- (void)resetProjection
{
    NSSize size = [self bounds].size;
    
    glViewport(0, 0, size.width, size.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    
	if (!self->isRotated) {
	 	glOrtho(0, size.width, size.height, 0, -1, 1);
	}
	else
	{
		glRotatef(90.0, 0.0, 0.0, 1.0);
	 	glOrtho(0, size.width, size.height, 0, -1, 5);
	}
    
    glMatrixMode(GL_MODELVIEW);
}

+ (int)powerOfTwoClosestTo:(int)number
{
    int rv = 1;
    while (rv < number) rv *= 2;
    return rv;
}

@end
