//
//  MBERenderer.h
//  TextRendering
//
//  Created by Warren Moore on 12/15/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

#import <MetalKit/MetalKit.h>

@import Foundation;
@import QuartzCore.CAMetalLayer;


@interface MBERenderer : NSObject <MTKViewDelegate>

@property (nonatomic, assign) CGPoint textTranslation;
@property (nonatomic, assign) CGFloat textScale;


///////
@property (nonatomic, assign) NSString * _Nonnull mbeFontName;
@property (nonatomic, assign) float mbeFontDisplaySize;



//- (instancetype)initWithLayer:(CAMetalLayer *)layer;
//- (void)draw;

/////
-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

/////
// Make these callable from MBEViewController
-(void)buildFontAtlas:(nonnull NSString*)fontName;
-(void)buildTextMesh:(nonnull NSString*)text size:(float)fontSize;
-(void)buildUniformBuffer;

@end
