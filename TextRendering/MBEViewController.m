//
//  MBEViewController.m
//  TextRendering
//
//  Created by Warren Moore on 2/6/15.
//  Copyright (c) 2015 Metal By Example. All rights reserved.
//

#import "MBEViewController.h"
#import "MBEMetalView.h"
#import "MBERenderer.h"

@interface MBEViewController () //<UIGestureRecognizerDelegate>
@property (nonatomic, strong) MBERenderer *renderer;
//@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) CVDisplayLinkRef displayLink;
//@property (nonatomic) MTLCommandBuffer commandQueue;

@end



@implementation MBEViewController

// Vars
MBEMetalView *_view;

//Renderer *_renderer;

// Init
//NSFont *font;



- (MBEMetalView *)metalView
{
    return (MBEMetalView *)self.view;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    _view = (MBEMetalView *)self.view;
    
    _view.device = MTLCreateSystemDefaultDevice();
    
    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }
    
    self.renderer = [[MBERenderer alloc] initWithMetalKitView:_view];
    
    [_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];

    _view.delegate = _renderer;
    
    
    // Init
    _font = [NSFont fontWithName:@"American Typewriter" size:72];
    
    

    //self.renderer = [[MBERenderer alloc] initWithLayer:self.metalView.metalLayer];

    // TODO: port this to macOS: displayLinkDidFire -> redraw -> renderer.draw
    //self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidFire:)];
    //[self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    
        
//    CGDirectDisplayID   displayID = CGMainDisplayID();
//    CVReturn            error = kCVReturnSuccess;
//    error = CVDisplayLinkCreateWithCGDisplay(displayID, _displayLink);
//    if (error)
//    {
//        NSLog(@"DisplayLink created with error:%d", error);
//        _displayLink = NULL;
//    }
//    CVDisplayLinkSetOutputCallback(_displayLink, renderCallback, (__bridge void *)self);
    
    
//    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
//    CVDisplayLinkSetOutputCallback(_displayLink, &MyDisplayLinkCallback, (__bridge void * _Nullable)(self));
//    CVDisplayLinkStart(_displayLink);
    
    
    //  We moeten nu MetalView koppelen aan de Renderer maar het originele project was voor iOS en
    // gebruikte de oude CAMetalLayer methode (ipv MTKView). De renderer daar heeft:
    //
    // - (instancetype)initWithLayer:(CAMetalLayer *)layer;
    // - (void)draw;
    //
    // Hoe kunnen we draw nu aanduiden als de gameloop methode? CADisplayLink werkt niet op macOS.
    // Vraag is of we op die manier de boel kunnen koppelen of toch moeten ombouwen naar de MTKView methode
    // met een delegate.
    // Zo wordt het gedaan met MTKView:
    
//    //////////////
//    _view = (MBEMetalView *)self.view;
//
//    _view.device = MTLCreateSystemDefaultDevice();
//
//    if(!_view.device)
//    {
//        NSLog(@"Metal is not supported on this device");
//        self.view = [[NSView alloc] initWithFrame:self.view.frame];
//        return;
//    }
//
//    //_renderer = [[MBERenderer alloc] initWithMetalKitView:_view];
      // NOTE: Need  <MTKViewDelegate> in MBERenderer
    //self.renderer = [[MBERenderer alloc] initWithMetalKitView:_view];
//
//    //[_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];
//
//    //_view.delegate = _renderer;
//    ////////////////
    
    
    
    
    

    

//    //UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
//                                                                                           action:@selector(panGestureWasRecognized:)];
//    //panGestureRecognizer.delegate = self;
//    //[self.view addGestureRecognizer:panGestureRecognizer];
//
//    //UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self
//                                                                                                 action:@selector(pinchGestureWasRecognized:)];
//    //pinchGestureRecognizer.delegate = self;
//    //[self.view addGestureRecognizer:pinchGestureRecognizer];
}


- (BOOL)prefersStatusBarHidden
{
    return YES;
}


////////
- (void)displayLinkDidFire:(id)sender
{
    [self redraw];
}

- (void)redraw
{
    //[self.renderer draw];
}






- (void)changeFont:(id)sender { // deprecated but works
    // blah
//    NSAlert *alert = [[NSAlert alloc] init];
//    [alert setMessageText:@"Hi there."];
//    [alert runModal];
//
    
    
    // See: https://developer.apple.com/library/archive/documentation/TextFonts/Conceptual/CocoaTextArchitecture/FontHandling/FontHandling.html
    NSFont *oldFont = [self font];
    NSFont *newFont = [sender convertFont:oldFont];
    [self setFont:newFont];
    
//    NSString *str = [NSString stringWithFormat:@"Font: %@\nSize: %f", newFont.fontName, newFont.pointSize];
//
//    NSAlert *alert = [[NSAlert alloc] init];
//    [alert setMessageText:str];
//    [alert runModal];
    
    // rebuild font atlas
    [_renderer buildFontAtlas:newFont.fontName];
    [_renderer buildTextMesh:@"MyText" size:newFont.pointSize];
    [_renderer buildUniformBuffer];
    
    
    // TEST:
    // We get here only for the first time user picks a color from the Font Panel's T button color picker but do
    // not get the color this way. 
    //NSColor *newColor = [sender color];
    //_renderer.mbeTextColor = simd_make_float4( newColor.redComponent, newColor.greenComponent, newColor.blueComponent, newColor.alphaComponent );

    // NOTE: the font panel has three color pickers:
    // cogwheel -> color for text (works)
    // T for text (does not work)
    // / for background (works)
    // how can we access when user picks the T button?
    // See: NSFontPanelTextColorEffectModeMask and NSFontPanelModeMaskDocumentColorEffect
    
    
    return;
    
    
}




- (void)changeColor:(id)sender {
    // HELL: This works from Font->Show Colors menu, also from Cogwheel->Color but not From T Button Colorpicker.
    // Also when picking from T button then Cogwheel no longer works.
    // This API is such a major pain.
    // TODO: make text color changes also work from the Font Panel T button color picker
    NSColor *newColor = [sender color];
    _renderer.mbeTextColor = simd_make_float4( newColor.redComponent, newColor.greenComponent, newColor.blueComponent, newColor.alphaComponent );
}


-(void)changeDocumentBackgroundColor:(id)sender {
    //[self setBackgroundColor:[sender color]];
    NSColor *newColor = [sender color];
    _renderer.mbeClearColor = MTLClearColorMake( newColor.redComponent, newColor.greenComponent, newColor.blueComponent, newColor.alphaComponent );
}



// See: https://cocoadev.github.io/NSFontPanel/
// Allow the font panel to set the underline, strikethrough and shadow attributes.
// Why is this not in the docs??? Cocoa sucks.
-(void)changeAttributes:(id)sender {
    //NSDictionary *oldAttributes = [self fontAttributes];
    //NSDictionary *newAttributes = [sender convertAttributes: oldAttributes];
    //[self setFontAttributes:newAttributes]; return;
}





////////
// See: https://stackoverflow.com/questions/37794646/the-right-way-to-make-a-continuously-redrawn-metal-nsview
////////
//static CVReturn renderCallback(CVDisplayLinkRef displayLink,
//                               const CVTimeStamp *inNow,
//                               const CVTimeStamp *inOutputTime,
//                               CVOptionFlags flagsIn,
//                               CVOptionFlags *flagsOut,
//                               void *displayLinkContext)
//{
//    return [(__bridge SPVideoView *)displayLinkContext renderTime:inOutputTime];
//}


//static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
//{
//
//    [(__bridge MBEMetalView *)displayLinkContext setNeedsDisplay:YES];
//    return kCVReturnSuccess;
//}




//- (BOOL) wantsLayer {
//    return YES;
//}
//
//- (BOOL) wantsUpdateLayer {
//    return YES;
//}
//
//- (void) displayLayer:(CALayer *)layer {
//    //id<MTLCommandBuffer> cmdBuffer = [_commandQueue commandBuffer];
//    //id<CAMetalDrawable> drawable = [((CAMetalLayer *) layer) nextDrawable];
//
//    //[cmdBuffer enqueue];
//    //[cmdBuffer presentDrawable:drawable];
//
//    // rendering
//    [self redraw];
//
//    //[cmdBuffer commit];
//}








//- (void)panGestureWasRecognized:(UIPanGestureRecognizer *)sender
//{
//    CGPoint translation = self.renderer.textTranslation;
//    CGPoint deltaTranslation = [sender translationInView:self.view];
//    self.renderer.textTranslation = CGPointMake(translation.x + deltaTranslation.x, translation.y + deltaTranslation.y);
//    [sender setTranslation:CGPointZero inView:self.view];
//}
//
//- (void)pinchGestureWasRecognized:(UIPinchGestureRecognizer *)sender
//{
//    CGFloat targetScale = self.renderer.textScale * sender.scale;
//    targetScale = fmax(0.5, fmin(targetScale, 5)); // RG: 15 bepaalt max zoom
//    self.renderer.textScale = targetScale;
//    sender.scale = 1;
//}
//
//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
//{
//    return YES;
//}

@end
