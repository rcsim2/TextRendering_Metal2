//
//  MBEViewController.h
//  TextRendering
//
//  Created by Warren Moore on 2/6/15.
//  Copyright (c) 2015 Metal By Example. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

// Our macOS view controller.
@interface MBEViewController : NSViewController

// Pointer to the view's window
@property (readwrite, nonatomic) NSWindow* window;

// Our font
@property (readwrite, nonatomic) NSFont* font;

// Our colors
//@property (readwrite, nonatomic) NSColor* colorText;
//@property (readwrite, nonatomic) NSColor* colorClear;

- (IBAction)showFonts2:(id)sender;

@end
