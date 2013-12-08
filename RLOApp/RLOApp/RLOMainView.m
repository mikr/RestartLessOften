//
//  RLOMainView.m
//  RLOApp
//
//  Created by michael on 1/19/13.
//
//

#import "RLOMainView.h"
#import "RLOCharacterMapping.h"
#import "GlobalEventHandler.h"


@implementation RLOMainView

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
    // Drawing code here.
}

- (void)keyDown:(NSEvent *)theEvent
{
    [self handleKeyEvent:theEvent eventtype:@"KeyDown"];
}

- (void)keyUp:(NSEvent *)theEvent
{
    [self handleKeyEvent:theEvent eventtype:@"KeyUp"];
}

- (void)handleKeyEvent:(NSEvent *)theEvent eventtype:(NSString *)eventtype
{
    NSString *charnames = [RLOCharacterMapping keynameForCharacters:theEvent.charactersIgnoringModifiers];
    NSUInteger modifierFlags = theEvent.modifierFlags;
    
    NSString *keycombo = [RLOCharacterMapping modifiedCharnames:charnames modifierFlags:modifierFlags];
    //NSLog(@"charname: %@ %@ %@ %@", keycombo, theEvent.charactersIgnoringModifiers, charnames, theEvent);
    
    NSMutableDictionary *querydict = [@{
                                        @"event" : eventtype,
                                        @"keycombo" : keycombo,
                                        @"autorepeat": @NO,
                                        @"skipfrontappcheck": @YES,
                                        } mutableCopy];

    [[NSNotificationCenter defaultCenter] postNotificationName:GlobalEventHandlerNotification object:self userInfo:querydict];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end
