//
//  MBEMetalView.m
//  TextRendering
//
//  Created by Warren Moore on 11/7/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import "MBEMetalView.h"

@implementation MBEMetalView

+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (CAMetalLayer *)metalLayer
{
    return (CAMetalLayer *)self.layer;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    // TEST: scale hardcoded to 2 as we get in Mac Catalyst app
    // During the first layout pass, we will not be in a view hierarchy, so we guess our scale
    CGFloat scale = 2;//10.0;//[NSScreen mainScreen].scale;
    
    // If we've moved to a window by the time our frame is being set, we can take its scale as our own
    if (self.window)
    {
        scale = 2;//10.0;//self.window.screen.scale;
    }
    
    CGSize drawableSize = self.bounds.size;
    
    // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels
    drawableSize.width *= scale;
    drawableSize.height *= scale;
    
    self.metalLayer.drawableSize = drawableSize;
}

@end
