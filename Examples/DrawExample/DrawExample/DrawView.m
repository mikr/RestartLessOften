//
//  DrawView.m
//  DrawExample
//
//  Created by michael on 12/8/13.
//  Copyright (c) 2013 Michael Krause. All rights reserved.
//

#import "DrawView.h"

@implementation DrawView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	   
    // Try changing the drawing code.
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, 160.0, 45.0);
    CGContextAddLineToPoint(ctx, 185.0, 45.0);
    CGContextClosePath(ctx);
    CGContextStrokePath(ctx);
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:@"Helvetica" size:48],
                                        NSFontAttributeName, [NSColor blackColor], NSForegroundColorAttributeName, nil];
    NSAttributedString * currentText = [[NSAttributedString alloc] initWithString:@"Restart Less Often" attributes:attributes];
    
    [currentText drawAtPoint:NSMakePoint(200.0, 15.0)];

    
    
    //// Bezier 2 Drawing
    NSBezierPath* bezier2Path = [NSBezierPath bezierPath];
    [bezier2Path moveToPoint: NSMakePoint(82.5, 68.5)];
    [bezier2Path lineToPoint: NSMakePoint(81.5, 26.5)];
    [bezier2Path lineToPoint: NSMakePoint(108.5, 26.5)];
    [[NSColor blackColor] setStroke];
    [bezier2Path setLineWidth: 4];
    [bezier2Path stroke];
    
    
    //// Oval Drawing
    NSBezierPath* ovalPath = [NSBezierPath bezierPathWithOvalInRect: NSMakeRect(118.5, 25.5, 27, 41)];
    [[NSColor blackColor] setStroke];
    [ovalPath setLineWidth: 4];
    [ovalPath stroke];
    
    
    //// Bezier 3 Drawing
    NSBezierPath* bezier3Path = [NSBezierPath bezierPath];
    [bezier3Path moveToPoint: NSMakePoint(33, 24)];
    [bezier3Path curveToPoint: NSMakePoint(33, 66.21) controlPoint1: NSMakePoint(33, 64.33) controlPoint2: NSMakePoint(33, 66.21)];
    [bezier3Path curveToPoint: NSMakePoint(58.78, 66) controlPoint1: NSMakePoint(33, 66.21) controlPoint2: NSMakePoint(49.08, 73.14)];
    [bezier3Path curveToPoint: NSMakePoint(58.78, 49) controlPoint1: NSMakePoint(68.48, 58.86) controlPoint2: NSMakePoint(58.78, 49)];
    [bezier3Path curveToPoint: NSMakePoint(42.78, 46) controlPoint1: NSMakePoint(58.78, 49) controlPoint2: NSMakePoint(45.78, 41.02)];
    [bezier3Path curveToPoint: NSMakePoint(65, 24.94) controlPoint1: NSMakePoint(39.78, 50.98) controlPoint2: NSMakePoint(65, 24.94)];
    [[NSColor blackColor] setStroke];
    [bezier3Path setLineWidth: 4];
    [bezier3Path stroke];

}

@end
