// TEST: git2
//
//  MBERenderer.m
//  TextRendering
//
//  Created by Warren Moore on 12/15/14.
//  Copyright (c) 2014 Metal By Example. All rights reserved.
//

@import Metal;
#import "MBERenderer.h"
#import "MBEMathUtilities.h"
#import "MBETypes.h"
#import "MBEFontAtlas.h"
#import "MBETextMesh.h"

#import <Cocoa/Cocoa.h>




#define MBE_FORCE_REGENERATE_FONT_ATLAS 0

// NOTE: try different combinations of fonts and sizes and scale; one size smaller or bigger gets rid of glyph
// TODO:
// * use font dialog to let user switch fonts and sizes and colors
// * menu option to have text animated, print Frame, FPS, etc.
// * dialog box to let user set text
// * typing sound when animated text
// * implement gestures as in original


//static NSString *const MBEFontName = @"American Typewriter";//@"HoeflerText-Regular"; // NOTE: bold italic text looks best
//static float MBEFontDisplaySize = 72; // NOTE: huge size looks better, 72 in the original sample is OK.
//static NSString *const MBESampleText = @"It was the best of times, it was the worst of times, "
//                                        "it was the age of wisdom, it was the age of foolishness...\n\n"
//                                        "Все счастливые семьи похожи друг на друга, "
//                                        "каждая несчастливая семья несчастлива по-своему.";
//static vector_float4 MBETextColor = { 0.1, 0.1, 0.1, 1 };
//static MTLClearColor MBEClearColor = { 1, 1, 1, 1 };
static float MBEFontAtlasSize = 2048;






@interface MBERenderer ()
//@property (nonatomic, strong) CAMetalLayer *layer;
// Long-lived Metal objects
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLSamplerState> sampler;
// Resources
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (nonatomic, strong) MBEFontAtlas *fontAtlas;
@property (nonatomic, strong) MBETextMesh *textMesh;
@property (nonatomic, strong) id<MTLBuffer> uniformBuffer;
@property (nonatomic, strong) id<MTLTexture> fontTexture;
@end



@implementation MBERenderer

// Vars
int frame = 0;
int frame2 = 0;
float fps = 0.0;
clock_t start, end;

int frames = 0;

NSTimeInterval start_time = 0;

NSString *str3 = @"";
int i = 0;


id <MTLTexture> _colorMap;
MTLVertexDescriptor *_mtlVertexDescriptor;

typedef NS_ENUM(NSInteger, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
};

MTKMesh *_mesh;








// Old
//- (instancetype)initWithLayer:(CAMetalLayer *)layer
//{
//    if ((self = [super init]))
//    {
//        _layer = layer;
//        [self buildMetal];
//        [self buildResources];
//
//        _textScale = 1.0;
//        _textTranslation = CGPointMake(0, 0);
//
//        // init
//        //start = clock();
//    }
//    return self;
//}


// New
-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
{
    self = [super init];
    if(self)
    {
        _device = view.device;
        //_inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
        //[self _loadMetalWithView:view];
        //[self _loadAssets];
        
        // Where the hell can we init member vars in ObjC?
        // Well, here it seems.
        // See: https://stackoverflow.com/questions/5168633/initialize-instance-variables-on-objective-c/5168766
        // NOTE: must set these before buildResources
        _mbeFontName = @"American Typewriter";
        _mbeFontDisplaySize = 72;
        
        _mbeTextColor = simd_make_float4( 0.1, 0.1, 0.1, 1 );
        _mbeClearColor = MTLClearColorMake( 1.0, 1.0, 1.0, 1 );
        
        
        [self buildMetal];
        [self buildResources];
        
        
        // NOTE: the trick is to use a huge font size and scale it down: looks much better.
        _textScale = 1.0;
        _textTranslation = CGPointMake(0, 0);
        
        
        ///////////////////////
        // TEST: texture and cube
        NSError *error;
        
        MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];

        NSDictionary *textureLoaderOptions =
        @{
          MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead & MTLTextureUsageRenderTarget),
          MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
          };

        _colorMap = [textureLoader newTextureWithName:@"ColorMap"
                                          scaleFactor:1.0
                                               bundle:nil
                                              options:textureLoaderOptions
                                                error:&error];

        if(!_colorMap || error)
        {
            NSLog(@"Error creating texture %@", error.localizedDescription);
        }
        
        
        MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc]
                                                  initWithDevice: _device];

        MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){4, 4, 4}
                                                segments:(vector_uint3){2, 2, 2}
                                            geometryType:MDLGeometryTypeTriangles
                                           inwardNormals:NO
                                               allocator:metalAllocator];

        MDLVertexDescriptor *mdlVertexDescriptor =
        MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);

        mdlVertexDescriptor.attributes[VertexAttributePosition].name  = MDLVertexAttributePosition;
        mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;

        mdlMesh.vertexDescriptor = mdlVertexDescriptor;

        _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh
                                       device:_device
                                        error:&error];

        if(!_mesh || error)
        {
            NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
        }
        /////////////////////////
    }

    return self;
}






- (void)buildMetal
{
    _device = MTLCreateSystemDefaultDevice();
    //_layer.device = _device;
    //_layer.pixelFormat = MTLPixelFormatBGRA8Unorm;

    _commandQueue = [_device newCommandQueue];

    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToZero;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToZero;
    _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];

    id<MTLLibrary> library = [_device newDefaultLibrary];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];

    // TEST:
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;//MTLPixelFormatRGBA8Unorm_sRGB;//
    pipelineDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;

    // CRASH:
    // TEST: We crashed with MTLPixelFormatDepth32Float because:
    // failed assertion `For depth attachment, the renderPipelineState pixelFormat must be
    // MTLPixelFormatInvalid, as no texture is set.'
    // Using MTLPixelFormatInvalid makes the app run but without font texture, of course.
    // But we also see no quads. Why?
    // OK, we managed to build a texture with [self buildDepthTexture:view]; and now can use
    // MTLPixelFormatDepth32Float but we still see no text or quads. Why?
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_shade"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_shade"];
    pipelineDescriptor.vertexDescriptor = [self newVertexDescriptor];
    

    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState)
    {
        NSLog(@"Error occurred when compiling pipeline state: %@", error);
    }
}





- (MTLVertexDescriptor *)newVertexDescriptor
{
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];

    // Position
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;

    // Texture coordinates
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = sizeof(vector_float4);
    vertexDescriptor.attributes[1].bufferIndex = 0;

    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stride = sizeof(MBEVertex);

    return vertexDescriptor;
}

- (NSURL *)documentsURL
{
    NSArray *candidates = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = [candidates firstObject];
    return [NSURL fileURLWithPath:documentsPath isDirectory:YES];
}

- (void)buildResources
{
    [self buildFontAtlas:_mbeFontName];
    [self buildTextMesh:@"MyText" size:_mbeFontDisplaySize];
    [self buildUniformBuffer];
}






- (void)buildFontAtlas:(NSString*)fontName
{
    //NSURL *fontURL = [[self.documentsURL URLByAppendingPathComponent:MBEFontName] URLByAppendingPathExtension:@"sdff"];
    NSURL *fontURL = [[self.documentsURL URLByAppendingPathComponent:fontName] URLByAppendingPathExtension:@"sdff"];

#if !MBE_FORCE_REGENERATE_FONT_ATLAS
    // How does this work? How can it fill _fontAtlas._textureSize == 2048 ???
    // Not from MBEFontAtlasSize. 2048 must be some standard value.
    // It is getting it from the .sdff (signed-distance field) files that were previously made at:
    // ~/Library/Containers/com.metalbyexample.TextRendering-Metal2/Data/Documents
    // by MBEFontAtlas initWithFont here below.
    // For testing it is better to always regenerate.
    _fontAtlas = [NSKeyedUnarchiver unarchiveObjectWithFile:fontURL.path]; // read file
#endif
    
    // TEST:
    // TODO: Change buildResources into a version with arguments
    // This is now only used for printing the font name
    _mbeFontName = fontName;

    // NOTE: Only get here if a .sdff file was not previously made
    // NOTE2: Using size:MBEFontDisplaySize doesn't do much
    // Cache miss: if we don't have a serialized version of the font atlas, build it now
    // TEST:
    if (!_fontAtlas) // We change font dynamically so now must always generate font atlas
    {
        //NSFont *font = [NSFont fontWithName:MBEFontName size:32];
        NSFont *font = [NSFont fontWithName:fontName size:32];
        _fontAtlas = [[MBEFontAtlas alloc] initWithFont:font textureSize:MBEFontAtlasSize];
        [NSKeyedArchiver archiveRootObject:_fontAtlas toFile:fontURL.path]; // save .sdff file
    }

    MTLTextureDescriptor *textureDesc;
    textureDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                                     width:MBEFontAtlasSize
                                                                    height:MBEFontAtlasSize
                                                                 mipmapped:NO];
    
    MTLRegion region = MTLRegionMake2D(0, 0, MBEFontAtlasSize, MBEFontAtlasSize);
    
    // TODO: We need MTLTextureUsageRenderTarget for _fontTexture
    // DONE
    //textureDesc.usage = MTLTextureUsageRenderTarget;
    textureDesc.usage = MTLTextureUsageRenderTarget & MTLTextureUsageShaderRead;
    
    _fontTexture = [_device newTextureWithDescriptor:textureDesc];
    [_fontTexture setLabel:@"Font Atlas"];
    
    // NOTE: The reason for the un-textured black quads was because we commented out this line doing our
    // quick and dirty hack. It is crucial for the font atlas texture however.
    // Yyyesss!!! we were getting validateReplaceRegion:183: failed assertion `rowBytes(2048) must be >= (8192).'
    // Hardcoding 8192 for bytesPerRow gives quad textures but they are incorrect. Why?
    // Seems that failed assertion is also strange: the argument is bytesPerRow not rowBytes. And the value we
    // give it is 4096 (MBEFontAtlasSize) not 2048.
    // NONO: MBEFontAtlasSize is 2048. When hovering over it in MTLRegionMake2D above when hitting a breakpoint
    // we get 4096. Why??? Because it is declared as 4096 in MBEFontAtlas.m?
    // This IDE and API is so buggy.
    // Also, when trying to look what the texture looks like by hovering and clicking the eye icon, it takes
    // Xcode several tries to show the contents of the texture.
    // NOTE: we have to turn off Metal API Validation in the Scheme to get past this code with bytesPerRow == 2048.
    // But our font atlas texture is still not OK. It repeats 4x horizontally.
    // YESS!!!!: Stupid: one way or the other we had MTLPixelFormatBGRA8Unorm instead of MTLPixelFormatR8Unorm
    // in texture2DDescriptorWithPixelFormat above with the code hidden by the Minimap.
    // Coding on a MacBook Air is such a nono.
    // TODO: text prints fine now but still looks butt-ugly with wobbly font.
    // See: http://liu.diva-portal.org/smash/get/diva2:618269/FULLTEXT02.pdf
    // Times font looks OK but Arial looks particularly nasty. Especially, l and i.
    // The original sample definitely looks better (on Mac Catalyst) so it may be a UIKit vs Cocao issue.
    // But also there it doesn't really look good for Arial: wobbly font.
    // Anyway, shouldn't this stuff all be handled by some basic Metal text API? It's 2020.
    // NOTE: the code here and in the original sample is very finicky: MBEFontAtlasSize can only be 2048
    // (no go for e.g. 1024, 4096, etc.)
    // NOTE: one way or another we are getting through now with Metal API Validation Enabled.
    // OKOK: getting better: this was a quick and dirty hack and we have hardcoded several things to make
    // it work. E.g. in buildMeshWithString in MBETextMesh.m where we were using Times. No wonder font
    // looks wobbly when using Arial here for MBEFontName.
    // Gotta do a diff with the original sample to check things that we have changed for Cocao.
    // Times is acceptable now. But still ugly in Arial: e.g. second l in Hallo, S in FPS, 6 in 60 etc.
    //
    [_fontTexture replaceRegion:region mipmapLevel:0 withBytes:_fontAtlas.textureData.bytes bytesPerRow:MBEFontAtlasSize];
    //[_fontTexture replaceRegion:region mipmapLevel:0 withBytes:_fontAtlas.textureData.bytes bytesPerRow:2048];
    
    // TEST:
    [_fontTexture setLabel:@"Font Atlas2"];
}






// Added text argument so we can call it dynamically
// Added size argument too
- (void)buildTextMesh:(NSString*)text size:(float)fontSize
{
    CGRect textRect = CGRectInset([NSScreen mainScreen].visibleFrame, 40, 0); // RG: text x,y from top left

    _textMesh = [[MBETextMesh alloc] initWithString:text //@"QQQ"//MBESampleText
                                             inRect:textRect
                                      withFontAtlas:_fontAtlas
                                             atSize:fontSize //_mbeFontDisplaySize
                                             device:_device];
    
    // TODO: better make buildResources with arguments and do this there
    _mbeFontDisplaySize = fontSize;
}



- (void)buildUniformBuffer
{
    _uniformBuffer = [_device newBufferWithLength:sizeof(MBEUniforms)
                                          options:MTLResourceOptionCPUCacheModeDefault];
    [_uniformBuffer setLabel:@"Uniform Buffer"];
}



- (void)buildDepthTexture:(MTKView *)view
{
    //CGSize drawableSize = self.layer.drawableSize;
    CGSize drawableSize = view.drawableSize;
    
    MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                          width:drawableSize.width
                                                                                         height:drawableSize.height
                                                                                      mipmapped:NO];
    // RG: this was what we needed to get this sample running on macOS via Mac Catalyst
    // Build succeeded but then we got runtime errors because these were not set
    descriptor.storageMode = MTLStorageModePrivate;
    descriptor.usage = MTLTextureUsageRenderTarget;// & MTLTextureUsageShaderRead;
    
    
    self.depthTexture = [self.device newTextureWithDescriptor:descriptor];
    [self.depthTexture setLabel:@"Depth Texture"];
}




//- (MTLRenderPassDescriptor *)newRenderPassWithColorAttachmentTexture:(id<MTLTexture>)texture
//{
//    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor new];
//
//    renderPass.colorAttachments[0].texture = texture;
//    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
//    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
//    renderPass.colorAttachments[0].clearColor = MBEClearColor;
//
//    renderPass.depthAttachment.texture = self.depthTexture;
//    renderPass.depthAttachment.loadAction = MTLLoadActionClear;
//    renderPass.depthAttachment.storeAction = MTLStoreActionStore;
//    renderPass.depthAttachment.clearDepth = 1.0;
//
//    return renderPass;
//}





- (void)updateUniforms:(MTKView *)view
{
    //CGSize drawableSize = self.layer.drawableSize;
    CGSize drawableSize = view.drawableSize;

    MBEUniforms uniforms;

    vector_float3 translation = { self.textTranslation.x, self.textTranslation.y, 0 };
    vector_float3 scale = { self.textScale, self.textScale, 1 };
    matrix_float4x4 modelMatrix = matrix_multiply(matrix_translation(translation), matrix_scale(scale));
    uniforms.modelMatrix = modelMatrix;

    matrix_float4x4 projectionMatrix = matrix_orthographic_projection(0, drawableSize.width, 0, drawableSize.height);
    uniforms.viewProjectionMatrix = projectionMatrix;

    uniforms.foregroundColor = _mbeTextColor;

    memcpy([self.uniformBuffer contents], &uniforms, sizeof(MBEUniforms));
}




//- (void)draw
- (void)drawInMTKView:(nonnull MTKView *)view
{
    // Yess!!
    // We're in the loop
    
    
    // TEST:
    // Dynamically change font
//    if (frame == 1000) {
//        [self buildFontAtlas:@"Arial"];
//        [self buildTextMesh:@"MyText"];
//        [self buildUniformBuffer];
//    }
    
    
    
    // Boilerplate
//    /// Per frame updates here
//
//    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
//
//    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
//    commandBuffer.label = @"MyCommand";
//
//    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
//    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
//     {
//         dispatch_semaphore_signal(block_sema);
//     }];
//
//    [self _updateDynamicBufferState];
//
//    [self _updateGameState];
    
    
    
    
    //id<CAMetalDrawable> drawable = [self.layer nextDrawable];

    //if (drawable)
    {
        
//        CGSize drawableSize = self.layer.drawableSize;
//
//        if ([self.depthTexture width] != drawableSize.width || [self.depthTexture height] != drawableSize.height)
//        {
            //[self buildDepthTexture];
            [self buildDepthTexture:view];
//        }
        
        // [self updateUniforms];
        [self updateUniforms:view];
        

        /////////////////////////////////////////////////////////
        // TODO: we need renderpass descriptor with a texture attached
        // DONE: Well, we have that now. But now we get: failed assertion `PixelFormat
        // MTLPixelFormatDepth32Float is not color renderable'
        //
        // Set renderpass descriptor here, not in a function
        //MTLRenderPassDescriptor *renderPass = [self newRenderPassWithColorAttachmentTexture:[drawable texture]];
        MTLRenderPassDescriptor* renderPass = view.currentRenderPassDescriptor;
        
        // Mmm: failed assertion `Texture at colorAttachment[0] has usage (0x01) which doesn't specify MTLTextureUsageRenderTarget (0x04)'
        // Done. Looks good now: we have black output so it looks like we are loading the font atlas texture
        // Commenting out gives us white. All as expected.
        // But there is probably somthing wrong with our view or model matrix.
        // TEST: with colorMap texture
        // Mmm, don't get any texture, only black.
        // Shit: renderPass.colorAttachments[0].texture takes the depth texture, not _fontTexture
        // Put depthTexture here but we get: failed assertion `PixelFormat MTLPixelFormatDepth32Float is not color renderable'
        // NOTE: cannot set _fontTexture here, must do it later with [commandEncoder setFragmentTexture: or
        // we get a total black screen.
        // Why? And is it the fontTexture we must set here?
        //renderPass.colorAttachments[0].texture = _fontTexture;// _fontTexture
        renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPass.colorAttachments[0].clearColor = _mbeClearColor;

        renderPass.depthAttachment.texture = self.depthTexture; // the depth texture
        renderPass.depthAttachment.loadAction = MTLLoadActionClear;
        renderPass.depthAttachment.storeAction = MTLStoreActionStore;
        renderPass.depthAttachment.clearDepth = 1.0;
        /////////////////////////////////////////////////////////
        
        
        
        
        if(renderPass != nil) {

            /// Final pass rendering code here

            id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

            id<MTLRenderCommandEncoder> commandEncoder =
                                    [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
            [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
            [commandEncoder setCullMode:MTLCullModeNone];
            
            // CRASH: because: failed assertion `For depth attachment, the renderPipelineState pixelFormat
            // must be MTLPixelFormatInvalid, as no texture is set.'
            [commandEncoder setRenderPipelineState:self.pipelineState];

            [commandEncoder setVertexBuffer:self.textMesh.vertexBuffer offset:0 atIndex:0];
            [commandEncoder setVertexBuffer:self.uniformBuffer offset:0 atIndex:1];

            [commandEncoder setFragmentBuffer:self.uniformBuffer offset:0 atIndex:0];
            [commandEncoder setFragmentTexture:self.fontTexture atIndex:0]; // set _fontTexture for fragment shader
            [commandEncoder setFragmentSamplerState:self.sampler atIndex:0];
            
            
            // Wireframe
            // NOTE: wireframes draw ugly: the lines are vague and we have 4 quads per cube side
            // What's going on?
            // This: MDLMesh newBoxWithDimensions segments 2
            [commandEncoder setTriangleFillMode: MTLTriangleFillModeFill]; // default
            //[commandEncoder setTriangleFillMode: MTLTriangleFillModeLines]; // wireframe
            
            
            // TEST: can we dynamically draw text? Yes!
            frame++;
            //[self buildTextMesh:@"QQQ"];
            //[self buildTextMesh:@(frame).stringValue];
            //end = clock();
    //        if ( (clock() - start)/CLOCKS_PER_SEC > 1 ) {
    //            fps = (frame - frame2);
    //
    //            frame2 = frame;
    //            start = clock();
    //        }
            
            
            
            
            // Get FPS
            // NOTE: we are not getting proper fps because the renderloop is timer based which fuck up clock()
    //        if (frame % 2 == 0) {
    //            //float frametime = clock() - start;
    //            clock_t delta_ticks = clock() - start;
    //            fps = CLOCKS_PER_SEC/delta_ticks;
    //        } else {
    //            start = clock();
    //        }
            
            
            // Hè hè, zo krijgen we wel de juiste FPS. Het lijkt er dus inderdaad op dat Metal de clock() vertraagt
            // om 60 FPS te krijgen, en daarom kunnen we clock() niet meer gebruiken voor real-time timers.
            NSTimeInterval current_time = [[NSDate date] timeIntervalSince1970];
            ++frames;
            
            if (current_time - start_time > 1.0)
            {
                fps = frames / (current_time - start_time);
                start_time = current_time;
                frames = 0;
                
                printf("FPS: %.1f\n", fps);
            }
            
            // TEST: print substring
            
            NSString *str2 = @"Hallo Mirjam de Pirjam heb je lekker Verkleedfeest gevierd?";
            //NSString *str3 = str2;//[str2 substringToIndex:(i)];
            if (frame % 5 == 0) {
                str3 = [str2 substringToIndex:(i++)];
                if (i>str2.length) i=0;
                //[[NSSound soundNamed:@"Pop"] play];
            }
            
            
            // Print FPS onscreen
            //NSString *string1 = [NSString stringWithFormat:@"A string: %@, a float: %1.2f", @"string", 31415.9265];
            NSString *str = [NSString stringWithFormat:@"Frame: %i\nFPS: %.1f\nFont: %@\n\n%@", frame, fps, _mbeFontName, str3];
            [self buildTextMesh:str size:_mbeFontDisplaySize];
            
            
            // SHIT: These font quads are not visible
            // What we see is small incoorect cubelets from the cube mesh, that ARE affected by all font
            // algos.
            // TODO: make these visible first
//            [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
//                                       indexCount:[self.textMesh.indexBuffer length] / sizeof(MBEIndexType)
//                                        indexType:MTLIndexTypeUInt16
//                                      indexBuffer:self.textMesh.indexBuffer
//                                indexBufferOffset:0];
            
            
            /////////////////////
            // Draw cube
            // TEST: we are getting small animated cubes: this is the mesh from our cube and the vertices are
            // transformed by the vertex shader from the font atlas pipeline
            // Nono, it looks like they ARE from the textmesh: changing rect in buildTextMesh changes
            // the layout. So how can that be this cube?
            // This vertexBuffer affects the quad drawing. It has to happen before drawIndexedPrimitives
            // Hell, the first cubelets were of course not from the cube, but were out text:
            // Frame: XXX
            // FPS: 60
            // Well, they WERE from the cube: they were the first (incorrect) vertices from the cube
            // that got transformed by the vertex shader. Don't draw the cube and draw the font quads
            // after vertexBuffer and it works!!!
//            for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++)
//            {
//                MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers[bufferIndex];
//                if((NSNull*)vertexBuffer != [NSNull null])
//                {
//                    [commandEncoder setVertexBuffer:vertexBuffer.buffer
//                                             offset:vertexBuffer.offset
//                                            atIndex:bufferIndex];
//                }
//            }

            // Well, well. This is causing things to work or not.
            // Leave this out and we get no black quads. Why?????
            // Mmm, got to put our _fontTexture texture here??? No, no go.
            // NONO: we already do this in the code before. Reason for it not working is we were making an
            // fault font atlas. So we don't need this here either.
//            [commandEncoder setFragmentTexture:_fontTexture//colorMap//_fontTexture
//                                      atIndex:0];
            
            
//            [commandEncoder setVertexTexture:_fontTexture//
//            atIndex:0];
//            [commandEncoder setFragmentTexture:_fontTexture//
//            atIndex:0];
            
//
//            for(MTKSubmesh *submesh in _mesh.submeshes)
//            {
//                [commandEncoder drawIndexedPrimitives:submesh.primitiveType
//                                          indexCount:submesh.indexCount
//                                           indexType:submesh.indexType
//                                         indexBuffer:submesh.indexBuffer.buffer
//                                   indexBufferOffset:submesh.indexBuffer.offset];
//            }
            /////////////////////
            
            // YYYYYeeeeessss!!! Breakthrough: Now these are being drawn and animated!!!!
            // What's going on???? Has to do with drawing order here.
            // Yes: must do this after [commandEncoder setVertexBuffer...
            // NOTE: the vertexbuffer now has the size of the cube mesh but must be set to that of the font quads
            // NOTE2: when drawing filled we get black cubes. What's going on?
            // Odd: we aren't even reaching [commandEncoder setVertexBuffer because
            // _mesh.vertexBuffers.count == 0
            // Why does it still work???
            // NONO: must do this after [commandEncoder setFragmentTexture:_colorMap to get it to show at all.
            // Why???
            [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                                  indexCount:[self.textMesh.indexBuffer length] / sizeof(MBEIndexType)
                                                   indexType:MTLIndexTypeUInt16
                                                 indexBuffer:self.textMesh.indexBuffer
                                           indexBufferOffset:0];
           
            
            
            

            [commandEncoder endEncoding];

            //[commandBuffer presentDrawable:drawable];
            [commandBuffer presentDrawable:view.currentDrawable];
            
            [commandBuffer commit];
            
        }
            
        
    }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {

    /// Respond to drawable size or orientation changes here

    //float aspect = size.width / (float)size.height;
    //_projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
    
    [self updateUniforms:view];
}


@end
