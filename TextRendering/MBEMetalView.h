//
//  MBEMetalView.h
//  TextRendering
//
//  Created by Warren Moore on 11/7/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

//@import UIKit;
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@import QuartzCore.CAMetalLayer;

@interface MBEMetalView : MTKView

@property (nonatomic, readonly) CAMetalLayer *metalLayer;

@end
