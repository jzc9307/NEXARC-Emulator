// NEXARC's in-process Cocoa companion. It never executes guest code.
// The upstream Mac frontend iterates at kCFRunLoopBeforeWaiting. A repeating
// common-mode timer provides a wake-up even when the user makes no input.
#import <AppKit/AppKit.h>
#import <GameController/GameController.h>
#import <objc/runtime.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <stdbool.h>
#include <pthread.h>
extern bool NXSetSpeed(int speed);
extern uint64_t NXFrameCount(void);
extern uint64_t NXVideoFrameCount(void);
extern unsigned char *NXCopyVideoRGBA(unsigned *width,unsigned *height);
static NSInteger nxBlockedCursorHides=0;
static void NXKeepCursor(id self,SEL command){nxBlockedCursorHides++;}
static void NXBalanceCursor(id self,SEL command){}
static void (*NXOriginalHiddenUntilMove)(id,SEL,BOOL);
static void NXNeverHideUntilMove(id self,SEL command,BOOL hidden){if(hidden)nxBlockedCursorHides++;if(NXOriginalHiddenUntilMove)NXOriginalHiddenUntilMove(self,command,NO);}
static void NXInstallCursor(void){
 Method hide=class_getClassMethod(NSCursor.class,@selector(hide));
 Method show=class_getClassMethod(NSCursor.class,@selector(unhide));
 if(hide)method_setImplementation(hide,(IMP)NXKeepCursor);
 if(show)method_setImplementation(show,(IMP)NXBalanceCursor);
 Method untilMove=class_getClassMethod(NSCursor.class,@selector(setHiddenUntilMouseMoves:));
 if(untilMove){NXOriginalHiddenUntilMove=(void(*)(id,SEL,BOOL))method_getImplementation(untilMove);method_setImplementation(untilMove,(IMP)NXNeverHideUntilMove);}
 fprintf(stderr,"[NEXARC_CURSOR] Keeping the native cursor visible in this player process\n");
}

static NSString *NXEnv(const char *key) { const char *v=getenv(key); return v ? [NSString stringWithUTF8String:v] : @""; }
static void NXSend(NSString *command) {
 int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)return;
 struct sockaddr_in a={0};a.sin_len=sizeof(a);a.sin_family=AF_INET;a.sin_port=htons(NXEnv("NEXARC_COMMAND_PORT").intValue);a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);
 NSData *d=[[command stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];sendto(fd,d.bytes,d.length,0,(void*)&a,sizeof(a));close(fd);
}
static NSColor *NXColor(CGFloat r,CGFloat g,CGFloat b){return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1];}

static NSColor *NXHex(NSString *text,NSColor *fallback){unsigned int value=0;if(!text.length||![[NSScanner scannerWithString:text]scanHexInt:&value])return fallback;return NXColor(((value>>16)&255)/255.0,((value>>8)&255)/255.0,(value&255)/255.0);}
static NSString *NXSelectedSkinImage(void){return NXEnv([NXEnv("NEXARC_SKIN")isEqual:@"Console hardware"]?"NEXARC_HARDWARE_IMAGE":"NEXARC_SKIN_IMAGE");}
static NSRect NXUploadedCanvas(NSRect bounds){CGFloat aspect=MAX(.05,NXEnv([NXEnv("NEXARC_SKIN")isEqual:@"Console hardware"]?"NEXARC_HARDWARE_ASPECT":"NEXARC_SKIN_IMAGE_ASPECT").doubleValue),w=MIN(bounds.size.width,bounds.size.height*aspect),h=w/aspect;return NSMakeRect(NSMidX(bounds)-w/2,NSMidY(bounds)-h/2,w,h);}
static NSRect NXUploadedScreen(NSRect bounds){NSRect c=NXUploadedCanvas(bounds);NSArray *a=[NXEnv([NXEnv("NEXARC_SKIN")isEqual:@"Console hardware"]?"NEXARC_HARDWARE_SCREEN":"NEXARC_SKIN_SCREEN")componentsSeparatedByString:@","];if(a.count!=4)return NSInsetRect(c,c.size.width*.1,c.size.height*.1);return NSMakeRect(c.origin.x+[a[0]doubleValue]*c.size.width,c.origin.y+(1-[a[1]doubleValue]-[a[3]doubleValue])*c.size.height,[a[2]doubleValue]*c.size.width,[a[3]doubleValue]*c.size.height);}
static BOOL NXSeparateScreens(void){return [NXEnv("NEXARC_SKIN")isEqual:@"Uploaded skin"]&&NXEnv("NEXARC_DUAL_SECONDARY").length>0;}
static NSRect NXDualRect(NSRect bounds,const char *key){NSRect canvas=NXUploadedCanvas(bounds);NSArray *a=[NXEnv(key)componentsSeparatedByString:@","];if(a.count!=4)return NSZeroRect;return NSMakeRect(canvas.origin.x+[a[0]doubleValue]*canvas.size.width,canvas.origin.y+(1-[a[1]doubleValue]-[a[3]doubleValue])*canvas.size.height,[a[2]doubleValue]*canvas.size.width,[a[3]doubleValue]*canvas.size.height);}
static void NXReleasePixels(void *info,const void *data,size_t size){free((void*)data);}
// Software DS/3DS frames remain presentable even if the frontend replaces its
// Metal drawable during state loading or a window/fullscreen transition.
static CGImageRef NXCopyFrameImage(void){
 unsigned w=0,h=0;unsigned char *pixels=NXCopyVideoRGBA(&w,&h);if(!pixels||w<2||h<2){free(pixels);return NULL;}
 CGDataProviderRef provider=CGDataProviderCreateWithData(NULL,pixels,(size_t)w*h*4,NXReleasePixels);CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();CGImageRef image=CGImageCreate(w,h,8,32,w*4,color,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault,provider,NULL,false,kCGRenderingIntentDefault);CGDataProviderRelease(provider);CGColorSpaceRelease(color);return image;
}
static BOOL NXSoftwarePresentation(void){return [NXEnv("NEXARC_CAPTURE_VIDEO")isEqual:@"1"];}
static BOOL NXDrawSoftwareFrame(NSRect screen){CGImageRef image=NXCopyFrameImage();if(!image)return NO;[NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext.imageInterpolation=[NXEnv("NEXARC_SMOOTH")isEqual:@"1"]?NSImageInterpolationHigh:NSImageInterpolationNone;[[[NSImage alloc]initWithCGImage:image size:NSZeroSize]drawInRect:screen];[NSGraphicsContext restoreGraphicsState];CGImageRelease(image);return YES;}
static BOOL NXDrawSeparateScreens(NSRect bounds){
 static NSImage *art;static NSString *artPath;NSString *path=NXSelectedSkinImage();if(![artPath isEqual:path]){artPath=path;art=[[NSImage alloc]initWithContentsOfFile:path];}
 CGImageRef image=NXCopyFrameImage();if(!image)return NO;size_t w=CGImageGetWidth(image),h=CGImageGetHeight(image);
 [NXColor(.025,.035,.05)setFill];NSRectFill(bounds);[art drawInRect:NXUploadedCanvas(bounds)];
 [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext.imageInterpolation=[NXEnv("NEXARC_SMOOTH")isEqual:@"1"]?NSImageInterpolationHigh:NSImageInterpolationNone;
 CGFloat half=h/2.0,bottomWidth=[NXEnv("NEXARC_SYSTEM_ID")isEqual:@"n3ds"]?w*.8:w;
 CGImageRef top=CGImageCreateWithImageInRect(image,CGRectMake(0,0,w,half));CGImageRef bottom=CGImageCreateWithImageInRect(image,CGRectMake((w-bottomWidth)/2,half,bottomWidth,h-half));
 if(top){[[[NSImage alloc]initWithCGImage:top size:NSZeroSize]drawInRect:NXDualRect(bounds,"NEXARC_DUAL_PRIMARY")];CGImageRelease(top);}
 if(bottom){[[[NSImage alloc]initWithCGImage:bottom size:NSZeroSize]drawInRect:NXDualRect(bounds,"NEXARC_DUAL_SECONDARY")];CGImageRelease(bottom);}
 [NSGraphicsContext restoreGraphicsState];CGImageRelease(image);return YES;
}
@interface NXShellView:NSView
@property NSRect screen;
@property NSString *system;
@property NSImage *customImage;
@property NSString *imagePath;
@property NSString *skin;
@end
@implementation NXShellView
- (BOOL)isOpaque{return YES;}
- (void)resetCursorRects{[self addCursorRect:self.bounds cursor:NSCursor.arrowCursor];}
- (void)drawRect:(NSRect)dirty {
 [NXColor(.025,.035,.05)setFill];NSRectFill(self.bounds);
 if([self.skin isEqual:@"Screen only"])return;
 if([self.skin isEqual:@"Uploaded skin"]||[self.skin isEqual:@"Console hardware"]){NSString *path=NXSelectedSkinImage();if(![self.imagePath isEqual:path]){self.imagePath=path;self.customImage=[[NSImage alloc]initWithContentsOfFile:path];}[self.customImage drawInRect:NXUploadedCanvas(self.bounds)];return;}
 BOOL neon=[self.skin isEqual:@"Neon shell"];
 BOOL television=[NXEnv("NEXARC_SKIN_DESIGN")isEqual:@"television"];
 NSColor *bodyColor=NXHex(NXEnv("NEXARC_SHELL_COLOR"),NXColor(.65,.68,.75)),*accent=NXHex(NXEnv("NEXARC_ACCENT_COLOR"),NXColor(.28,.95,.83));
 NSRect shell=NSInsetRect(self.screen,-55,-25);
 if(television)shell=NSMakeRect(self.screen.origin.x-35,self.screen.origin.y-65,self.screen.size.width+70,self.screen.size.height+90);
 if([self.system isEqual:@"gb"]||[self.system isEqual:@"gbc"]){shell=NSMakeRect(self.screen.origin.x-30,self.screen.origin.y-105,self.screen.size.width+60,self.screen.size.height+140);}
 NSBezierPath *body=[NSBezierPath bezierPathWithRoundedRect:shell xRadius:[NXEnv("NEXARC_SKIN_DESIGN")isEqual:@"landscape"]?42:22 yRadius:[NXEnv("NEXARC_SKIN_DESIGN")isEqual:@"landscape"]?42:22];
 NSGradient *gradient=[[NSGradient alloc]initWithStartingColor:neon?[accent blendedColorWithFraction:.8 ofColor:NSColor.blackColor]:bodyColor endingColor:neon?NXColor(.025,.07,.12):[bodyColor blendedColorWithFraction:.3 ofColor:NSColor.blackColor]];[gradient drawInBezierPath:body angle:90];
 [neon?NXColor(.28,.95,.83):NXColor(.8,.83,.9) setStroke];body.lineWidth=1.5;[body stroke];
 NSRect bezel=NSInsetRect(self.screen,-5,-5);[NXColor(.03,.04,.06)setFill];[[NSBezierPath bezierPathWithRoundedRect:bezel xRadius:6 yRadius:6]fill];
 if(television){
  [NXColor(.04,.05,.07)setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(NSMidX(shell)-70,NSMinY(shell)+22,140,6) xRadius:3 yRadius:3]fill];
  [accent setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMaxX(shell)-28,NSMinY(shell)+20,8,8)]fill];
  [self.system.uppercaseString drawAtPoint:NSMakePoint(NSMinX(shell)+18,NSMinY(shell)+17) withAttributes:@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold],NSForegroundColorAttributeName:neon?accent:NSColor.blackColor}];
  for(int i=0;i<5;i++)NSRectFill(NSMakeRect(NSMaxX(shell)-75+i*6,NSMinY(shell)+20,2,10));return;
 }
 CGFloat y=NSMinY(self.screen)+self.screen.size.height*.23,x=NSMinX(shell)+23;
 if([self.system isEqual:@"gb"]||[self.system isEqual:@"gbc"]){x=NSMinX(shell)+35;y=NSMinY(shell)+54;}
 NSRectFill(NSMakeRect(x-12,y-4,24,8));NSRectFill(NSMakeRect(x-4,y-12,8,24));
 CGFloat bx=NSMaxX(shell)-25;for(int i=0;i<4;i++){CGFloat dx=i==0?-10:i==1?10:0,dy=i==2?-10:i==3?10:0;[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(bx+dx-4,y+dy-4,8,8)]fill];}
 NSDictionary *attrs=@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightBold],NSForegroundColorAttributeName:neon?NXColor(.4,1,.85):NXColor(.1,.13,.2)};
 NSString *title=[@"NEXARC / " stringByAppendingString:(NXEnv("NEXARC_SYSTEM_NAME").length?NXEnv("NEXARC_SYSTEM_NAME"):self.system).uppercaseString];[title drawAtPoint:NSMakePoint(NSMinX(shell)+16,NSMaxY(shell)-16) withAttributes:attrs];
 for(int i=0;i<4;i++){NSRectFill(NSMakeRect(NSMinX(shell)+12+i*5,NSMaxY(self.screen)-20,2,10));NSRectFill(NSMakeRect(NSMaxX(shell)-30+i*5,NSMaxY(self.screen)-20,2,10));}
}
@end

@interface NXHingeView:NSView
@property NSRect screen;
@property NSInteger speed;
@property NSString *startupMessage;
@property NSDate *startupUntil;
@property NSImage *hardwareImage;
@property uint64_t presentedFrames;
@end
@implementation NXHingeView
- (NSView*)hitTest:(NSPoint)point{return nil;}
- (void)drawRect:(NSRect)dirty {
 BOOL presented=NXSeparateScreens()?NXDrawSeparateScreens(self.bounds):(NXSoftwarePresentation()?NXDrawSoftwareFrame(self.screen):NO);if(presented)self.presentedFrames++;
 if([NXEnv("NEXARC_SKIN")isEqual:@"Console hardware"]){if(!self.hardwareImage)self.hardwareImage=[[NSImage alloc]initWithContentsOfFile:NXSelectedSkinImage()];[self.hardwareImage drawInRect:NXUploadedCanvas(self.bounds)];}
 if(self.speed>1){
  NSRect badge=NSMakeRect(NSMaxX(self.screen)-248,NSMaxY(self.screen)-54,236,42);[NXColor(.025,.055,.07)setFill];[[NSBezierPath bezierPathWithRoundedRect:badge xRadius:12 yRadius:12]fill];
  [NXColor(.28,.95,.83)setStroke];NSBezierPath *outline=[NSBezierPath bezierPathWithRoundedRect:badge xRadius:12 yRadius:12];outline.lineWidth=1.6;[outline stroke];
  [[NSString stringWithFormat:@"▶   FAST FORWARD  %ld×",(long)self.speed]drawAtPoint:NSMakePoint(badge.origin.x+13,badge.origin.y+13) withAttributes:@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:16 weight:NSFontWeightBold],NSForegroundColorAttributeName:NXColor(.62,1,.88)}];
 }
 if(self.startupMessage.length&&self.startupUntil&&[self.startupUntil timeIntervalSinceNow]>0){NSSize z=[self.startupMessage sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold]}];NSRect toast=NSMakeRect(NSMidX(self.screen)-z.width/2-20,NSMinY(self.screen)+18,z.width+40,34);[NXColor(.035,.05,.07)setFill];[[NSBezierPath bezierPathWithRoundedRect:toast xRadius:12 yRadius:12]fill];[self.startupMessage drawAtPoint:NSMakePoint(NSMinX(toast)+20,NSMinY(toast)+10) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:NXColor(.63,1,.88)}];}
 if([NXEnv("NEXARC_SKIN") isEqual:@"Console hardware"]||[NXEnv("NEXARC_SKIN") isEqual:@"Uploaded skin"]||[NXEnv("NEXARC_SKIN") isEqual:@"Screen only"]||![NXEnv("NEXARC_LAYOUT") isEqual:@"Stacked"]||![NXEnv("NEXARC_SYSTEM_ID") isEqual:@"nds"])return;
 CGFloat gap=NXEnv("NEXARC_GAP").doubleValue;
 CGFloat h=self.screen.size.height*gap/(384+gap);
 NSRect hinge=NSMakeRect(self.screen.origin.x-53,NSMidY(self.screen)-h/2,self.screen.size.width+106,h);
 [NXEnv("NEXARC_SKIN").length&&[NXEnv("NEXARC_SKIN") hasPrefix:@"Neon"]?NXColor(.08,.20,.25):NXColor(.36,.39,.47) setFill];
 [[NSBezierPath bezierPathWithRoundedRect:hinge xRadius:5 yRadius:5]fill];
 [NXColor(.06,.08,.11)setFill];NSRectFill(NSMakeRect(hinge.origin.x,NSMidY(hinge)-1,hinge.size.width,2));
}
@end

// Switch uses the separate SDL window, so its skin is a non-interactive
// AppKit overlay that follows that window without intercepting game input.
@interface NXSwitchSkinView:NSView
@property NSString *skin;
@property NSString *speedText;
@property NSImage *customImage;
@property NSString *titleText;
@end
@implementation NXSwitchSkinView
- (BOOL)isOpaque{return NO;}
- (NSView*)hitTest:(NSPoint)p{return nil;}
- (void)drawRect:(NSRect)dirty {
 if([self.skin isEqual:@"Screen only"])return;
 if([self.skin isEqual:@"Uploaded skin"]){if(!self.customImage)self.customImage=[[NSImage alloc]initWithContentsOfFile:NXEnv("NEXARC_SKIN_IMAGE")];[self.customImage drawInRect:self.bounds];return;}
 BOOL neon=[self.skin isEqual:@"Neon shell"];
 NSColor *left=neon?NXColor(.20,.94,.79):NXColor(.93,.25,.31),*right=neon?NXColor(.57,.40,.96):NXColor(.24,.53,.98);
 CGFloat rail=38,w=self.bounds.size.width,h=self.bounds.size.height;
 NSGradient *lg=[[NSGradient alloc]initWithStartingColor:neon?NXColor(.025,.10,.12):NXColor(.16,.17,.20) endingColor:neon?NXColor(.06,.19,.21):NXColor(.27,.28,.31)];
 NSGradient *rg=[[NSGradient alloc]initWithStartingColor:neon?NXColor(.06,.14,.20):NXColor(.16,.17,.20) endingColor:neon?NXColor(.10,.20,.28):NXColor(.27,.28,.31)];
 [lg drawInRect:NSMakeRect(0,0,rail,h) angle:0];[rg drawInRect:NSMakeRect(w-rail,0,rail,h) angle:180];
 [left setFill];NSRectFill(NSMakeRect(0,0,5,h));[right setFill];NSRectFill(NSMakeRect(w-5,0,5,h));
 NSColor *ink=NXColor(.03,.04,.06);[ink setFill];
 [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(9,h*.66,20,20) xRadius:10 yRadius:10]fill];
 for(int i=0;i<4;i++){CGFloat dx=(i==0?-7:i==1?7:0),dy=(i==2?-7:i==3?7:0);[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(w-19+dx-4,h*.30+dy-4,8,8)]fill];}
 [left setStroke];NSBezierPath *ls=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(7,h*.66-2,24,24)];ls.lineWidth=2;[ls stroke];
 [right setStroke];NSBezierPath *rs=[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(w-24,h*.30-13,26,26)];rs.lineWidth=2;[rs stroke];
 NSDictionary *a=@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:9 weight:NSFontWeightBold],NSForegroundColorAttributeName:neon?NXColor(.72,1,.94):NSColor.whiteColor};
 [@"NEXARC" drawAtPoint:NSMakePoint(rail+12,h-20) withAttributes:a];
 if(self.speedText.length){NSString *label=[NSString stringWithFormat:@"▶  %@×",self.speedText];NSSize size=[label sizeWithAttributes:@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightBold]}];NSRect badge=NSMakeRect(w-size.width-rail-28,h-54,size.width+20,34);[NXColor(.025,.055,.07)setFill];[[NSBezierPath bezierPathWithRoundedRect:badge xRadius:10 yRadius:10]fill];[left setStroke];NSBezierPath *b=[NSBezierPath bezierPathWithRoundedRect:badge xRadius:10 yRadius:10];b.lineWidth=1.5;[b stroke];[label drawAtPoint:NSMakePoint(badge.origin.x+10,badge.origin.y+9) withAttributes:@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightBold],NSForegroundColorAttributeName:NSColor.whiteColor}];}
}
@end

@interface NXSwitchSkin:NSObject
@property NSPanel *panel;
@property NXSwitchSkinView *view;
@property NSTimer *timer;
@property pid_t ownerPID;
@end
@implementation NXSwitchSkin
- (void)tick:(NSTimer*)t {
 NSWindow *target=nil;NSString *title=NXEnv("NEXARC_WINDOW_TITLE");
 for(NSWindow *w in NSApp.windows){if(w==self.panel||!w.visible||w.frame.size.width<480||w.frame.size.height<300)continue;if([w.title containsString:title]||!target)target=w;if([w.title containsString:title])break;}
 if(!target)return;
 if(!self.panel){self.panel=[[NSPanel alloc]initWithContentRect:target.frame styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];self.panel.backgroundColor=NSColor.clearColor;self.panel.opaque=NO;self.panel.hasShadow=NO;self.panel.ignoresMouseEvents=YES;self.panel.hidesOnDeactivate=YES;self.panel.level=NSStatusWindowLevel;self.panel.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;self.view=[[NXSwitchSkinView alloc]initWithFrame:NSMakeRect(0,0,target.frame.size.width,target.frame.size.height)];self.view.skin=NXEnv("NEXARC_SKIN");self.panel.contentView=self.view;}
 if(!NSEqualRects(self.panel.frame,target.frame))[self.panel setFrame:target.frame display:YES];
 NSData *data=[NSData dataWithContentsOfFile:NXEnv("NEXARC_STATUS_PATH")];NSDictionary *status=data?[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil]:nil;NSInteger speed=[status[@"speed"] integerValue];self.view.speedText=speed>1?@(speed).stringValue:@"";self.view.frame=self.panel.contentView.bounds;self.view.needsDisplay=YES;
 if(![self.view.skin isEqual:@"Screen only"])[self.panel orderFrontRegardless];else [self.panel orderOut:nil];
}
- (void)start {self.timer=[NSTimer timerWithTimeInterval:.1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];[[NSRunLoop mainRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];}
@end
@interface NXMenuButton:NSButton
@property BOOL primary;
@property BOOL pressed;
@property BOOL hovered;
@property BOOL controllerFocused;
@property NSString *shortcut;
@property NSTrackingArea *tracking;
@end
@implementation NXMenuButton
- (BOOL)acceptsFirstMouse:(NSEvent*)event{return YES;}
- (void)updateTrackingAreas{if(self.tracking)[self removeTrackingArea:self.tracking];self.tracking=[[NSTrackingArea alloc]initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingActiveInActiveApp|NSTrackingInVisibleRect owner:self userInfo:nil];[self addTrackingArea:self.tracking];[super updateTrackingAreas];}
- (void)mouseEntered:(NSEvent*)event{self.hovered=YES;self.needsDisplay=YES;}
- (void)mouseExited:(NSEvent*)event{self.hovered=NO;self.needsDisplay=YES;}
- (void)drawRect:(NSRect)dirty{
 NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,1,1) xRadius:9 yRadius:9];
 NSColor *fill=self.primary?NXColor(.72,.64,1):NXColor((self.hovered||self.controllerFocused)?.15:.105,(self.hovered||self.controllerFocused)?.18:.135,(self.hovered||self.controllerFocused)?.23:.17);
 if(self.pressed)fill=[fill blendedColorWithFraction:.18 ofColor:NSColor.blackColor];
 [fill setFill];[shape fill];[(self.controllerFocused?NXColor(.45,1,.84):self.primary?NXColor(.82,.76,1):NXColor(.23,.28,.34))setStroke];shape.lineWidth=1;[shape stroke];
 NSColor *ink=self.primary?NXColor(.1,.08,.16):NSColor.whiteColor;if(!self.enabled)ink=[ink colorWithAlphaComponent:.3];
 NSDictionary *attrs=@{NSFontAttributeName:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium],NSForegroundColorAttributeName:ink};
 NSSize size=[self.title sizeWithAttributes:attrs];[self.title drawAtPoint:NSMakePoint(16,(self.bounds.size.height-size.height)/2) withAttributes:attrs];
 if(self.shortcut.length){NSDictionary *keys=@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular],NSForegroundColorAttributeName:[ink colorWithAlphaComponent:self.enabled?.65:.2]};NSSize k=[self.shortcut sizeWithAttributes:keys];[self.shortcut drawAtPoint:NSMakePoint(self.bounds.size.width-k.width-16,(self.bounds.size.height-k.height)/2) withAttributes:keys];}
}
- (void)activate{if(!self.enabled)return;fprintf(stderr,"[NEXARC_MENU] %s\n",self.title.UTF8String);self.pressed=YES;self.needsDisplay=YES;[[NSHapticFeedbackManager defaultPerformer]performFeedbackPattern:NSHapticFeedbackPatternAlignment performanceTime:NSHapticFeedbackPerformanceTimeNow];[self sendAction:self.action to:self.target];__weak NXMenuButton *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_MSEC),dispatch_get_main_queue(),^{weak.pressed=NO;weak.needsDisplay=YES;});}
- (void)mouseDown:(NSEvent*)event{[self activate];}
@end
@interface NXMenuPanel:NSPanel
@end
@implementation NXMenuPanel
- (BOOL)canBecomeKeyWindow{return YES;}
- (BOOL)canBecomeMainWindow{return YES;}
@end
// Compact, app-owned slot tabs match the session controls in both window modes.
@interface NXSlotControl:NSControl
@property(nonatomic) NSInteger selectedSegment;
@end
@implementation NXSlotControl
- (void)setSelectedSegment:(NSInteger)value{_selectedSegment=MAX(0,MIN(5,value));self.needsDisplay=YES;}
- (void)drawRect:(NSRect)dirty{
 [NXColor(.105,.13,.16)setFill];[[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8]fill];
 CGFloat width=self.bounds.size.width/6;
 for(NSInteger i=0;i<6;i++){
  NSRect cell=NSInsetRect(NSMakeRect(i*width,0,width,self.bounds.size.height),2,2);BOOL selected=i==self.selectedSegment;
  if(selected){[NXColor(.63,.93,.84)setFill];[[NSBezierPath bezierPathWithRoundedRect:cell xRadius:6 yRadius:6]fill];}
  NSString *label=[NSString stringWithFormat:@"Slot %ld",(long)i+1];NSDictionary *attributes=@{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold],NSForegroundColorAttributeName:selected?NXColor(.04,.10,.12):NXColor(.70,.75,.80)};NSSize size=[label sizeWithAttributes:attributes];[label drawAtPoint:NSMakePoint(NSMidX(cell)-size.width/2,NSMidY(cell)-size.height/2) withAttributes:attributes];
 }
}
- (void)mouseDown:(NSEvent*)event{NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];self.selectedSegment=(NSInteger)(point.x/MAX(1,self.bounds.size.width)*6);[self sendAction:self.action to:self.target];}
@end
@protocol NXRenderPlatform
- (NSView*)renderView;
- (NSWindow*)window;
- (void)setDrawableSize:(CGSize)size;
@end
@interface NXPlayer : NSObject
@property NSPanel *panel;
@property NSWindow *game;
@property NXShellView *shell;
@property NSView *render;
@property NXHingeView *hinge;
@property BOOL sized;
@property NSTextField *notice;
@property NSTextField *elapsed;
@property NSDate *began;
@property NSDate *saveDate;
@property BOOL saving;
@property BOOL exitAfterSave;
@property BOOL paused;
@property NSInteger ticks;
@property NSInteger speed;
@property NSInteger fastTarget;
@property NXSlotControl *slotControl;
@property NSInteger selectedSlot;
@property NSInteger controllerIndex;
@property BOOL controllerA;
@property BOOL controllerB;
@property BOOL controllerChord;
@property NSDate *controllerRepeat;
@property uint64_t lastVideoFrame;
@property BOOL fastHeld;
@property id monitor;
@property NSTimer *timer;
@end
static NXPlayer *player;
static pthread_mutex_t nx_pointer_lock=PTHREAD_MUTEX_INITIALIZER;
static bool nx_pointer_active;
static int16_t nx_pointer_values[4]={INT16_MIN,INT16_MIN,0,0};
static void NXUpdateCustomPointer(void);
@implementation NXPlayer
- (NSString*)statePath {return NXEnv("NEXARC_STATE_PATH");}
- (void)writeStatus {
 NSDictionary *v=@{@"rendererAttached":@(self.render.window==self.game && self.game.contentView==self.shell),@"skin":NXEnv("NEXARC_SKIN"),@"menuOpen":@(self.panel.visible),@"paused":@(self.paused),@"pid":@(getpid()),@"speed":@(MAX(1,self.speed)),@"emulatedFrames":@(NXFrameCount()),@"videoFrames":@(NXVideoFrameCount()),@"presentedFrames":@(self.hinge.presentedFrames),@"softwarePresentation":@(NXSoftwarePresentation()),@"separateScreens":@(NXSeparateScreens()),@"cursorHideRequestsBlocked":@(nxBlockedCursorHides)};
 NSData *d=[NSJSONSerialization dataWithJSONObject:v options:0 error:nil];[d writeToFile:NXEnv("NEXARC_STATUS_PATH") atomically:YES];
}
- (NSTextField*)label:(NSString*)text size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor*)color {
 NSTextField *v=[NSTextField wrappingLabelWithString:text];v.font=[NSFont systemFontOfSize:size weight:weight];v.textColor=color;return v;
}
- (NSButton*)button:(NSString*)title action:(SEL)action primary:(BOOL)primary {
 NXMenuButton *b=[[NXMenuButton alloc]initWithFrame:NSZeroRect];
 NSArray *parts=[title componentsSeparatedByString:@"   "];b.title=parts.firstObject;b.shortcut=[[parts.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]isEqual:b.title]?@"":[parts.lastObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
 b.target=self;b.action=action;b.primary=primary;b.bordered=NO;b.font=[NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
 [b.heightAnchor constraintEqualToConstant:40].active=YES;[b.widthAnchor constraintEqualToConstant:438].active=YES;return b;
}
- (void)setPlaybackSpeed:(NSInteger)speed {
 if(self.speed==speed)return;
 if(NXSetSpeed((int)speed)){self.speed=speed;self.hinge.speed=speed;self.hinge.needsDisplay=YES;[self writeStatus];}
}
- (void)openMenu {
 if(!self.game||self.panel.visible)return;
 self.fastHeld=NO;[self setPlaybackSpeed:1];[NSCursor setHiddenUntilMouseMoves:NO];[NSCursor.arrowCursor set];CGDisplayShowCursor(CGMainDisplayID());
 if(!self.panel){
  self.panel=[[NXMenuPanel alloc]initWithContentRect:NSMakeRect(0,0,510,690) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];
  self.panel.title=@"NEXARC · Session menu";self.panel.titleVisibility=NSWindowTitleHidden;self.panel.titlebarAppearsTransparent=YES;self.panel.movableByWindowBackground=YES;
  self.panel.backgroundColor=NXColor(.055,.075,.105);self.panel.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];self.panel.level=NSFloatingWindowLevel;self.panel.hidesOnDeactivate=YES;self.panel.becomesKeyOnlyIfNeeded=NO;self.panel.ignoresMouseEvents=NO;self.panel.acceptsMouseMovedEvents=YES;
  self.panel.collectionBehavior=NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorMoveToActiveSpace;
  NSStackView *s=[NSStackView stackViewWithViews:@[]];s.orientation=NSUserInterfaceLayoutOrientationVertical;s.alignment=NSLayoutAttributeLeading;s.spacing=10;s.translatesAutoresizingMaskIntoConstraints=NO;
  [self.panel.contentView addSubview:s];[NSLayoutConstraint activateConstraints:@[[s.leadingAnchor constraintEqualToAnchor:self.panel.contentView.leadingAnchor constant:36],[s.trailingAnchor constraintEqualToAnchor:self.panel.contentView.trailingAnchor constant:-36],[s.centerYAnchor constraintEqualToAnchor:self.panel.contentView.centerYAnchor]]];
  [s addArrangedSubview:[self label:@"N E X A R C   /   SESSION PAUSED" size:12 weight:NSFontWeightBold color:NXColor(.45,1,.84)]];
  [s addArrangedSubview:[self label:NXEnv("NEXARC_GAME_TITLE") size:25 weight:NSFontWeightSemibold color:NSColor.whiteColor]];
  self.elapsed=[self label:@"" size:14 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];[s addArrangedSubview:self.elapsed];
  self.slotControl=[NXSlotControl new];self.slotControl.target=self;self.slotControl.action=@selector(slotChanged:);[self.slotControl.heightAnchor constraintEqualToConstant:30].active=YES;self.slotControl.selectedSegment=0;[self.slotControl.widthAnchor constraintEqualToConstant:438].active=YES;[s addArrangedSubview:self.slotControl];
  [s addArrangedSubview:[self button:@"Resume game                         Esc" action:@selector(resume:) primary:YES]];
  [s addArrangedSubview:[self button:@"Save selected slot                 F5" action:@selector(save:) primary:NO]];
  NSButton *load=[self button:@"Load selected slot                 F8" action:@selector(load:) primary:NO];load.identifier=@"load";[s addArrangedSubview:load];
  [s addArrangedSubview:[self button:@"Toggle full screen" action:@selector(fullscreen:) primary:NO]];
  NSButton *skinButton=[self button:[@"Console skin: " stringByAppendingString:NXEnv("NEXARC_SKIN")] action:@selector(changeSkin:) primary:NO];skinButton.identifier=@"skin";[s addArrangedSubview:skinButton];
  [s addArrangedSubview:[self button:@"Recovery & diagnostics" action:@selector(recovery:) primary:NO]];
  [s addArrangedSubview:[self button:@"Save & return to library" action:@selector(saveExit:) primary:NO]];
  [s addArrangedSubview:[self button:@"Return to library · auto-save" action:@selector(exit:) primary:NO]];
  self.notice=[self label:@"F5 saves the selected slot; F8 loads it. A selects, B resumes, ←/→ changes slots. Press both stick buttons to open this menu. In-game saves stay separate." size:13 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];[s addArrangedSubview:self.notice];
 }
 if(!self.paused)NXSend(@"PAUSE_TOGGLE");self.paused=YES;
 NSRect f=self.game.frame;[self.panel setFrameOrigin:NSMakePoint(NSMidX(f)-255,NSMidY(f)-345)];
 [self.game addChildWindow:self.panel ordered:NSWindowAbove];[self.panel makeKeyAndOrderFront:nil];
 for(NSView*v in ((NSStackView*)self.panel.contentView.subviews.firstObject).arrangedSubviews)if([v.identifier isEqual:@"load"]) ((NSButton*)v).enabled=[[NSFileManager defaultManager]fileExistsAtPath:[NXEnv("NEXARC_SLOTS_DIRECTORY")stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%ld.state",(long)self.selectedSlot]]];
 [self writeStatus];fprintf(stderr,"[NEXARC_PLAYER] Session menu opened\n");
}
- (void)resume:(id)sender {if(self.saving)return;[self.panel orderOut:nil];[self.game removeChildWindow:self.panel];[self.game makeKeyAndOrderFront:nil];if(self.paused)NXSend(@"PAUSE_TOGGLE");self.paused=NO;[self writeStatus];}
- (void)requestAction:(NSString*)action {
 NSString *path=NXEnv("NEXARC_PLAYER_ACTION");if(!path.length)return;
 [[NSFileManager defaultManager]removeItemAtPath:NXEnv("NEXARC_PLAYER_RESULT") error:nil];
 NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"action":action,@"slot":@(self.selectedSlot)} options:0 error:nil];[data writeToFile:path atomically:YES];
}
- (void)slotChanged:(id)sender {self.selectedSlot=MAX(0,MIN(5,self.slotControl.selectedSegment));for(NSView*v in ((NSStackView*)self.panel.contentView.subviews.firstObject).arrangedSubviews)if([v.identifier isEqual:@"load"])((NSButton*)v).enabled=[[NSFileManager defaultManager]fileExistsAtPath:[NXEnv("NEXARC_SLOTS_DIRECTORY")stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%ld.state",(long)self.selectedSlot]]];}
- (void)save:(id)sender {if(self.saving)return;self.saving=YES;self.saveDate=[NSDate date];self.notice.stringValue=@"Writing save slot and recovery backup…";[self requestAction:self.exitAfterSave?@"saveExit":@"save"];self.exitAfterSave=NO;}
- (void)saveExit:(id)sender {self.exitAfterSave=YES;[self save:sender];}
- (void)load:(id)sender {if(self.saving)return;self.saving=YES;self.saveDate=[NSDate date];self.notice.stringValue=@"Protecting current progress before loading…";[self requestAction:@"load"];}
- (void)recovery:(id)sender {[self requestAction:@"recovery"];}
- (void)changeSkin:(NSButton*)sender {
 NSMutableArray *choices=[NSMutableArray arrayWithObject:@"Screen only"];if(NXEnv("NEXARC_HARDWARE_IMAGE").length)[choices addObject:@"Console hardware"];[choices addObjectsFromArray:@[@"Classic shell",@"Neon shell"]];if(NXEnv("NEXARC_SKIN_IMAGE").length)[choices addObject:@"Uploaded skin"];NSUInteger index=[choices indexOfObject:NXEnv("NEXARC_SKIN")];NSString *skin=choices[index==NSNotFound?1:(index+1)%choices.count];
 setenv("NEXARC_SKIN",skin.UTF8String,1);self.shell.skin=skin;self.shell.needsDisplay=YES;self.hinge.needsDisplay=YES;[self layoutScreen];sender.title=[@"Console skin: " stringByAppendingString:skin];[self writeStatus];
}
- (void)fullscreen:(id)sender {[self.game toggleFullScreen:nil];}
- (void)exit:(id)sender {if(self.saving)return;NXSend(@"QUIT");}
- (void)layoutScreen {
 if(!self.game)return;
 // Video reinitialization replaces MetalView; follow the active renderer.
 id platform=NSApp.delegate;
 if(![platform respondsToSelector:@selector(renderView)])return;
 NSView *activeRender=[(id<NXRenderPlatform>)platform renderView];
 if(!activeRender || !activeRender.window)return;
 if(activeRender.window!=self.game){self.game=activeRender.window;self.shell=nil;self.hinge=nil;self.render=nil;fprintf(stderr,"[NEXARC_RENDER] Following renderer into its current window\n");}
 if(self.render!=activeRender || self.game.contentView!=self.shell){
  [self.hinge removeFromSuperview];self.hinge=nil;self.shell=nil;self.render=nil;
 }
 if(!self.shell){
  NSView *render=activeRender;
  // Upstream keeps its own renderView reference. Reparent it while preserving
  // its responder chain and coordinate conversion for the DS touchscreen.
  self.render=render;self.shell=[[NXShellView alloc]initWithFrame:render.bounds];self.shell.system=NXEnv("NEXARC_SYSTEM_ID");self.shell.skin=NXEnv("NEXARC_SKIN");self.shell.wantsLayer=YES;
  self.game.contentView=self.shell;[self.shell addSubview:render];self.hinge=[[NXHingeView alloc]initWithFrame:self.shell.bounds];self.hinge.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.hinge.startupMessage=[NXEnv("NEXARC_RESUMING") isEqual:@"1"]?@"NEXARC  ·  RESUME REQUESTED":@"NEXARC  ·  GAME READY";self.hinge.startupUntil=[NSDate dateWithTimeIntervalSinceNow:4];self.hinge.wantsLayer=YES;self.hinge.layer.backgroundColor=NSColor.clearColor.CGColor;[self.shell addSubview:self.hinge];fprintf(stderr,"[NEXARC_RENDER] Attached active %s renderer to shell\n",NSStringFromClass(render.class).UTF8String);render.autoresizingMask=NSViewNotSizable;[self.game makeFirstResponder:render];
 }
 if(!self.sized && !(self.game.styleMask&NSWindowStyleMaskFullScreen)){
  [self.game setContentSize:NSMakeSize(MAX(480,NXEnv("NEXARC_WINDOW_WIDTH").doubleValue),MAX(360,NXEnv("NEXARC_WINDOW_HEIGHT").doubleValue))];[self.game center];self.sized=YES;
 }
 NSRect bounds=self.shell.bounds;BOOL skin=![self.shell.skin isEqual:@"Screen only"];
 CGFloat aspect=MAX(.25,NXEnv("NEXARC_ASPECT").doubleValue);
 CGFloat mx=skin?75:0,my=skin?45:0;
 BOOL gb=[self.shell.system isEqual:@"gb"]||[self.shell.system isEqual:@"gbc"];
 if(skin&&gb){mx=45;my=95;}
 CGFloat w=MAX(1,bounds.size.width-2*mx),h=MAX(1,bounds.size.height-2*my);
 if(w/h>aspect)w=h*aspect;else h=w/aspect;
 NSString *sizing=NXEnv("NEXARC_SIZING");
 if(![sizing isEqual:@"Fit"]){
  CGFloat factor=[sizing containsString:@"3"]?3:[sizing containsString:@"2"]?2:1;
  CGFloat nativeWidth=256;
  if(gb)nativeWidth=160;else if([self.shell.system isEqual:@"gba"])nativeWidth=240;else if([self.shell.system isEqual:@"n3ds"])nativeWidth=400;else if([self.shell.system isEqual:@"psp"])nativeWidth=480;
  NSString *layout=NXEnv("NEXARC_LAYOUT");if([layout isEqual:@"Side by side"])nativeWidth=[self.shell.system isEqual:@"n3ds"]?720:512;else if([layout hasPrefix:@"Large"])nativeWidth=[self.shell.system isEqual:@"n3ds"]?1120:768;
  CGFloat nw=nativeWidth*factor/self.game.backingScaleFactor;if(nw<w){w=nw;h=w/aspect;}
 }
 NSRect frame=NSMakeRect(floor((bounds.size.width-w)/2),floor((bounds.size.height-h)/2+(skin&&gb?30:0)),floor(w),floor(h));
 if([self.shell.skin isEqual:@"Uploaded skin"]||[self.shell.skin isEqual:@"Console hardware"]){NSRect area=NXUploadedScreen(bounds);CGFloat cw=area.size.width,ch=area.size.height;if(cw/ch>aspect)cw=ch*aspect;else ch=cw/aspect;frame=NSMakeRect(NSMidX(area)-cw/2,NSMidY(area)-ch/2,cw,ch);}
 if(!NSEqualRects(frame,self.render.frame)){self.render.frame=frame;if([self.render respondsToSelector:@selector(setDrawableSize:)]){CGFloat scale=self.game.backingScaleFactor;[(id<NXRenderPlatform>)self.render setDrawableSize:CGSizeMake(MAX(1,frame.size.width*scale),MAX(1,frame.size.height*scale))];}self.shell.screen=frame;self.shell.needsDisplay=YES;self.hinge.screen=frame;self.hinge.needsDisplay=YES;}
}
- (void)tick:(NSTimer*)timer {
 // Merely waking this run loop is sufficient; calling runloop_iterate here would
 // emulate twice per iteration and break pacing. Vsync remains upstream's job.
 id platform=NSApp.delegate;if([platform respondsToSelector:@selector(window)]){NSWindow *nativeWindow=[(id<NXRenderPlatform>)platform window];if(nativeWindow&&nativeWindow!=self.game){self.game=nativeWindow;}}
 [self layoutScreen];
 if(self.hinge.startupUntil && self.hinge.startupUntil.timeIntervalSinceNow<=0){self.hinge.startupMessage=nil;self.hinge.startupUntil=nil;self.hinge.needsDisplay=YES;}
 if(self.game){self.game.acceptsMouseMovedEvents=YES;self.game.title=[@"NEXARC · " stringByAppendingString:NXEnv("NEXARC_GAME_TITLE")];}
 if(!NSApp.active && self.fastHeld){self.fastHeld=NO;[self setPlaybackSpeed:1];}
 if(++self.ticks%30==0){
  NSString *speedFile=NXEnv("NEXARC_SPEED_REQUEST");NSString *requested=[NSString stringWithContentsOfFile:speedFile encoding:NSUTF8StringEncoding error:nil];
  if(requested){self.fastTarget=MAX(2,MIN(5,requested.integerValue));[[NSFileManager defaultManager]removeItemAtPath:speedFile error:nil];if(self.fastHeld)[self setPlaybackSpeed:self.fastTarget];}
 }
 if(self.ticks%60==0){
  NSInteger t=-self.began.timeIntervalSinceNow;self.elapsed.stringValue=[NSString stringWithFormat:@"%@  ·  Playing for %02ld:%02ld",NXEnv("NEXARC_SYSTEM"),(long)t/60,(long)t%60];
  NSString *request=NXEnv("NEXARC_MENU_REQUEST");if([[NSFileManager defaultManager]fileExistsAtPath:request]){NSString *action=[NSString stringWithContentsOfFile:request encoding:NSUTF8StringEncoding error:nil];[[NSFileManager defaultManager]removeItemAtPath:request error:nil];if([action isEqual:@"resume"])[self resume:nil];else if(!self.panel.visible)[self openMenu];}
  [self writeStatus];
 }
 NSString *resultPath=NXEnv("NEXARC_PLAYER_RESULT");NSData *resultData=[NSData dataWithContentsOfFile:resultPath];
 if(resultData){NSDictionary *result=[NSJSONSerialization JSONObjectWithData:resultData options:0 error:nil];if(result[@"message"]){self.notice.stringValue=result[@"message"];self.saving=NO;[self slotChanged:nil];}[[NSFileManager defaultManager]removeItemAtPath:resultPath error:nil];}
 if(self.saving&&self.saveDate.timeIntervalSinceNow < -20){self.saving=NO;self.notice.stringValue=@"The operation was not confirmed. Your existing slots are kept.";}
 NSString *refresh=NXEnv("NEXARC_DISPLAY_REQUEST");if(refresh.length&&[[NSFileManager defaultManager]fileExistsAtPath:refresh]){[[NSFileManager defaultManager]removeItemAtPath:refresh error:nil];NSView *current=self.render;if(current&&current.window){[self.hinge removeFromSuperview];[current removeFromSuperview];self.game.contentView=current;self.shell=nil;self.hinge=nil;self.render=nil;[self layoutScreen];[current setNeedsDisplay:YES];fprintf(stderr,"[NEXARC_RENDER] Display refresh applied\n");}}
 if(NXSoftwarePresentation()&&self.lastVideoFrame!=NXVideoFrameCount()){self.lastVideoFrame=NXVideoFrameCount();self.hinge.needsDisplay=YES;}
 NXUpdateCustomPointer();
 [self pollController];
}
- (void)pollController {
 if(!NSApp.active)return;GCExtendedGamepad *pad=GCController.controllers.firstObject.extendedGamepad;if(!pad)return;
 BOOL chord=pad.leftThumbstickButton.pressed&&pad.rightThumbstickButton.pressed;
 if(chord&&!self.controllerChord){if(self.panel.visible)[self resume:nil];else [self openMenu];}self.controllerChord=chord;
 BOOL a=pad.buttonA.pressed,b=pad.buttonB.pressed;
 if(self.panel.visible){
  NSArray *buttons=[((NSStackView*)self.panel.contentView.subviews.firstObject).arrangedSubviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id view,NSDictionary *bindings){return [view isKindOfClass:NXMenuButton.class];}]];
  self.controllerIndex=MAX(0,MIN((NSInteger)buttons.count-1,self.controllerIndex));
  int move=pad.dpad.up.pressed||pad.leftThumbstick.yAxis.value>.65?-1:pad.dpad.down.pressed||pad.leftThumbstick.yAxis.value<-.65?1:0;
  int slot=pad.dpad.right.pressed||pad.leftThumbstick.xAxis.value>.65?1:pad.dpad.left.pressed||pad.leftThumbstick.xAxis.value<-.65?-1:0;
  if((move||slot)&&(!self.controllerRepeat||self.controllerRepeat.timeIntervalSinceNow<-.22)){self.controllerRepeat=[NSDate date];if(move)self.controllerIndex=(self.controllerIndex+move+buttons.count)%buttons.count;if(slot){self.slotControl.selectedSegment=(self.selectedSlot+slot+6)%6;[self slotChanged:nil];}}
  for(NSInteger i=0;i<buttons.count;i++){NXMenuButton *button=buttons[i];button.controllerFocused=i==self.controllerIndex;button.needsDisplay=YES;}
  if(b&&!self.controllerB)[self resume:nil];else if(a&&!self.controllerA&&buttons.count)[(NXMenuButton*)buttons[self.controllerIndex]activate];
 }
 self.controllerA=a;self.controllerB=b;
}
- (void)start {
 self.began=[NSDate date];self.speed=1;self.fastTarget=MAX(2,MIN(5,NXEnv("NEXARC_FAST_SPEED").integerValue));[NSCursor setHiddenUntilMouseMoves:NO];CGAssociateMouseAndMouseCursorPosition(true);__weak NXPlayer *weak=self;
 [[NSNotificationCenter defaultCenter]addObserverForName:NSWindowDidEnterFullScreenNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){[NSCursor setHiddenUntilMouseMoves:NO];[NSCursor.arrowCursor set];CGAssociateMouseAndMouseCursorPosition(true);CGDisplayShowCursor(CGMainDisplayID());}];
 self.monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskKeyUp|NSEventMaskFlagsChanged|NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown handler:^NSEvent*(NSEvent*e){NXPlayer *s=weak;if(!s)return e;
  if(e.type==NSEventTypeKeyDown&&e.keyCode==48&&!s.panel.visible){s.fastHeld=YES;[s setPlaybackSpeed:(e.modifierFlags&NSEventModifierFlagShift)?5:s.fastTarget];return nil;}
  if(e.type==NSEventTypeKeyUp&&e.keyCode==48){s.fastHeld=NO;[s setPlaybackSpeed:1];return nil;}
  if(e.type==NSEventTypeFlagsChanged&&s.fastHeld){[s setPlaybackSpeed:(e.modifierFlags&NSEventModifierFlagShift)?5:s.fastTarget];return nil;}
  if(e.type==NSEventTypeKeyDown&&e.keyCode==53){if(!e.isARepeat){if(s.panel.visible)[s resume:nil];else [s openMenu];}return nil;}
  if(e.type==NSEventTypeKeyDown&&e.keyCode==96){[s save:nil];return nil;}if(e.type==NSEventTypeKeyDown&&e.keyCode==100){[s load:nil];return nil;}
  if(s.panel.visible){if(e.type==NSEventTypeKeyDown){}
   else if(e.type==NSEventTypeLeftMouseDown||e.type==NSEventTypeRightMouseDown){
    // Fullscreen Cocoa may stamp a child-panel click with the game window.
    // Hit-test its actual screen point, not the event's window identity.
    NSPoint screen=e.window?[e.window convertPointToScreen:e.locationInWindow]:NSEvent.mouseLocation;
    if(NSPointInRect(screen,s.panel.frame)){
     if(e.window==s.panel)return e;
     NSPoint local=[s.panel.contentView convertPoint:[s.panel convertPointFromScreen:screen] fromView:nil];
     NSView *hit=[s.panel.contentView hitTest:local];
     while(hit&&![hit isKindOfClass:NXMenuButton.class]&&![hit isKindOfClass:NXSlotControl.class])hit=hit.superview;
     if([hit isKindOfClass:NXSlotControl.class]){NSPoint p=[hit convertPoint:local fromView:s.panel.contentView];s.slotControl.selectedSegment=MAX(0,MIN(5,(NSInteger)(p.x/MAX(1,hit.bounds.size.width)*6)));[s slotChanged:nil];}
     else if(hit)[(NXMenuButton*)hit activate];return nil;
    }
    [s resume:nil];return nil;
   }}
  return e;}];
 self.timer=[NSTimer timerWithTimeInterval:1.0/60.0 target:self selector:@selector(tick:) userInfo:nil repeats:YES];[[NSRunLoop mainRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];fprintf(stderr,"[NEXARC_PLAYER] 60 Hz Cocoa wake-up installed; Escape opens session menu\n");
}
@end
// AppKit coordinates are sampled on the main thread. Core input callbacks may
// run on another thread, so they only read the cached libretro pointer values.
static void NXUpdateCustomPointer(void){
 bool active=player&&player.game&&player.shell&&NXSeparateScreens();
 int16_t values[4]={INT16_MIN,INT16_MIN,0,0};
 if(active&&!player.panel.visible&&NSApp.active){
  NSPoint window=[player.game convertPointFromScreen:NSEvent.mouseLocation];NSPoint point=[player.shell convertPoint:window fromView:nil];NSRect bottom=NXDualRect(player.shell.bounds,"NEXARC_DUAL_SECONDARY");BOOL inside=NSPointInRect(point,bottom);
  if(inside){double x=(point.x-bottom.origin.x)/MAX(1,bottom.size.width),y=1-(point.y-bottom.origin.y)/MAX(1,bottom.size.height);if([NXEnv("NEXARC_SYSTEM_ID")isEqual:@"n3ds"])x=.1+x*.8;values[0]=(int16_t)MAX(-32767,MIN(32767,x*65534-32767));values[1]=(int16_t)MAX(-32767,MIN(32767,(.5+y*.5)*65534-32767));values[2]=(NSEvent.pressedMouseButtons&1)?1:0;values[3]=1;}
 }
 pthread_mutex_lock(&nx_pointer_lock);nx_pointer_active=active;memcpy(nx_pointer_values,values,sizeof(values));pthread_mutex_unlock(&nx_pointer_lock);
}
bool NXCustomPointer(unsigned identifier,int16_t *value){
 if(identifier>3)return false;
 pthread_mutex_lock(&nx_pointer_lock);bool active=nx_pointer_active;if(active)*value=nx_pointer_values[identifier];pthread_mutex_unlock(&nx_pointer_lock);return active;
}
static NXSwitchSkin *switchSkin;
__attribute__((constructor))static void NXInstall(void){
 if(getenv("NEXARC_SWITCH_OVERLAY")){dispatch_async(dispatch_get_main_queue(),^{[NSApplication sharedApplication];switchSkin=[NXSwitchSkin new];[switchSkin start];});return;}
 if(!getenv("NEXARC_COMMAND_PORT"))return;
 NXInstallCursor();dispatch_async(dispatch_get_main_queue(),^{player=[NXPlayer new];[player start];});
}
