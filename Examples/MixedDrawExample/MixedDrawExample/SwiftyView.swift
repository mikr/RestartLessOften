//
//  SwiftyView.swift
//  MixedDrawExample
//
//  Created by michael on 6/9/14.
//  Copyright (c) 2014 Michael Krause. All rights reserved.
//

import Cocoa

extension NSGraphicsContext {
    var cgContext : CGContext {
    let opaqueContext = COpaquePointer(self.graphicsPort())
        return Unmanaged<CGContext>.fromOpaque(opaqueContext).takeUnretainedValue()
    }
}


class SwiftyView: NSView {
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "RLOTIfiNotification", object: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "rloNotification:", name: "RLOTIfiNotification", object: nil)
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        let ctx = NSGraphicsContext.currentContext().cgContext;
        
        let numshapes = 40
        for i in 0..<numshapes {
            CGContextSetRGBFillColor(ctx, 0, 0.5, 0, 1)
            CGContextFillRect(ctx, CGRectMake(10 + CGFloat(i) * 12.0, 50 + 30 * sin(CDouble(i) * 2.0 * 3.141592653589793 / CDouble(numshapes)), 10, 10))
        }
    }
    
    func rloNotification(notification: NSNotification) {
        needsDisplay = true
    }
}
