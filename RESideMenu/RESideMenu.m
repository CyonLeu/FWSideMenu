//
// REFrostedViewController.m
// RESideMenu
//
// Copyright (c) 2013-2014 Roman Efimov (https://github.com/romaonthego)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RESideMenu.h"
#import "UIViewController+RESideMenu.h"
#import "RECommonFunctions.h"
#import <UIImageEffects/UIImage+ImageEffects.h>

const CGFloat cMaxRotateAngel = M_PI / 180 * 90; ///rotate angle for '_contentViewController' when side menu is open
const CGFloat cMinContentWidth = 180.f;

@interface RESideMenu ()

@property (strong, readwrite, nonatomic) UIImageView *backgroundImageView;
@property (assign, readwrite, nonatomic) BOOL visible;
@property (assign, readwrite, nonatomic) BOOL leftMenuVisible;
@property (assign, readwrite, nonatomic) BOOL rightMenuVisible;
@property (assign, readwrite, nonatomic) CGPoint originalPoint;
@property (strong, readwrite, nonatomic) UIButton *contentButton;
@property (strong, readwrite, nonatomic) UIView *menuViewContainer;
@property (strong, readwrite, nonatomic) UIImageView *contentImageView;

@property (assign, readwrite, nonatomic) BOOL didNotifyDelegate;

@end

@implementation RESideMenu

#pragma mark -
#pragma mark Instance lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        [self __commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    if (self) {
        [self __commonInit];
    }
    return self;
}

- (void)__commonInit
{
    _menuViewContainer = [[UIView alloc] init];
    _contentViewContainer = [[UIView alloc] init];
    
    _animationDuration = 0.35f;
    _interactivePopGestureRecognizerEnabled = YES;
  
    _menuViewControllerTransformation = CGAffineTransformMakeScale(1.5f, 1.5f);
    
    _scaleContentView = YES;
    _scaleBackgroundImageView = YES;
    _scaleMenuView = YES;
    
    _parallaxEnabled = YES;
    _parallaxMenuMinimumRelativeValue = -15;
    _parallaxMenuMaximumRelativeValue = 15;
    _parallaxContentMinimumRelativeValue = -25;
    _parallaxContentMaximumRelativeValue = 25;
    
    _bouncesHorizontally = YES;
    
    _panGestureEnabled = YES;
    _panFromEdge = YES;
    _panMinimumOpenThreshold = 20.0;
    
    _contentViewShadowEnabled = NO;
    _contentViewShadowColor = [UIColor blackColor];
    _contentViewShadowOffset = CGSizeZero;
    _contentViewShadowOpacity = 0.4f;
    _contentViewShadowRadius = 8.0f;
    _contentViewInLandscapeOffsetCenterX = 30.f;
    _contentViewInPortraitOffsetCenterX  = 40.f;
    _contentViewScaleValue = 0.81f;
}

#pragma mark -
#pragma mark Public methods

- (id)initWithContentViewController:(UIViewController *)contentViewController leftMenuViewController:(UIViewController *)leftMenuViewController rightMenuViewController:(UIViewController *)rightMenuViewController
{
    self = [self init];
    if (self) {
        _contentViewController = contentViewController;
        _leftMenuViewController = leftMenuViewController;
        _rightMenuViewController = rightMenuViewController;
    }
    return self;
}

- (void)presentLeftMenuViewController
{
    [self __presentMenuViewContainerWithMenuViewController:self.leftMenuViewController];
    [self __showLeftMenuViewController];
}

- (void)presentRightMenuViewController
{
    [self __presentMenuViewContainerWithMenuViewController:self.rightMenuViewController];
    [self __showRightMenuViewController];
}

- (void)hideMenuViewController
{
    [self __hideMenuViewControllerAnimated:YES];
}

- (void)setContentViewController:(UIViewController *)contentViewController animated:(BOOL)animated
{
    if (_contentViewController == contentViewController)
    {
        return;
    }
    
    if (!animated) {
        [self setContentViewController:contentViewController];
    } else {
        [self addChildViewController:contentViewController];
        contentViewController.view.alpha = 0;
        contentViewController.view.frame = self.contentViewContainer.bounds;
        [self.contentViewContainer addSubview:contentViewController.view];
        [UIView animateWithDuration:self.animationDuration animations:^{
            contentViewController.view.alpha = 1;
        } completion:^(BOOL finished) {
            [self __hideViewController:self.contentViewController];
            [contentViewController didMoveToParentViewController:self];
            _contentViewController = contentViewController;

            [self __statusBarNeedsAppearanceUpdate];
            [self __updateContentViewShadow];
            
            if (self.visible) {
                [self __addContentViewControllerMotionEffects];
            }
        }];
    }
}

- (UIImage *)imageSnapshotFromView:(UIView *)sourceView
{
    UIGraphicsBeginImageContext(sourceView.bounds.size);
    [sourceView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)addContentBlurredImage
{
    UIImage *sourceImage = [self imageSnapshotFromView:self.contentViewController.view];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *blurredImage = [sourceImage applyLightEffect];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contentImageView.image = blurredImage;
        });
    });
}

#pragma mark View life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundImageView = ({
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        imageView.image = self.backgroundImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView;
    });
    self.contentButton = ({
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectNull];
        [button addTarget:self action:@selector(hideMenuViewController) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
   
    self.contentImageView = [[UIImageView alloc] initWithFrame:CGRectNull];
    [self.view addSubview:self.self.contentImageView];
    [self.view addSubview:self.backgroundImageView];
    [self.view addSubview:self.menuViewContainer];
    [self.view addSubview:self.contentViewContainer];
    
    self.menuViewContainer.frame = self.view.bounds;
    self.menuViewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    if (self.leftMenuViewController) {
        [self addChildViewController:self.leftMenuViewController];
        self.leftMenuViewController.view.frame = self.view.bounds;
        self.leftMenuViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.menuViewContainer addSubview:self.leftMenuViewController.view];
        [self.leftMenuViewController didMoveToParentViewController:self];
    }
    
    if (self.rightMenuViewController) {
        [self addChildViewController:self.rightMenuViewController];
        self.rightMenuViewController.view.frame = self.view.bounds;
        self.rightMenuViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.menuViewContainer addSubview:self.rightMenuViewController.view];
        [self.rightMenuViewController didMoveToParentViewController:self];
    }
    
    self.contentViewContainer.frame = self.view.bounds;
    self.contentViewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.contentViewContainer.backgroundColor = [UIColor greenColor];
    
    if (self.contentViewController) {
        [self addChildViewController:self.contentViewController];
        self.contentViewController.view.frame = self.view.bounds;
        [self.contentViewContainer addSubview:self.contentViewController.view];
        [self.contentViewController didMoveToParentViewController:self];
    }
    
    self.menuViewContainer.alpha = 0;
    if (self.scaleBackgroundImageView)
        self.backgroundImageView.transform = CGAffineTransformMakeScale(1.7f, 1.7f);
    
    [self __addMenuViewControllerMotionEffects];
    
    if (self.panGestureEnabled) {
        self.view.multipleTouchEnabled = NO;
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(__panGestureRecognized:)];
        panGestureRecognizer.delegate = self;
        [self.view addGestureRecognizer:panGestureRecognizer];
    }
    
    [self __updateContentViewShadow];
}

#pragma mark -
#pragma mark Private methods

- (void)__presentMenuViewContainerWithMenuViewController:(UIViewController *)menuViewController
{
    self.menuViewContainer.transform = CGAffineTransformIdentity;
    if (self.scaleBackgroundImageView) {
        self.backgroundImageView.transform = CGAffineTransformIdentity;
        self.backgroundImageView.frame = self.view.bounds;
    }
    self.menuViewContainer.frame = self.view.bounds;
    if (self.scaleMenuView) {
        self.menuViewContainer.transform = self.menuViewControllerTransformation;
    }
    self.menuViewContainer.alpha = 0;
    if (self.scaleBackgroundImageView)
        self.backgroundImageView.transform = CGAffineTransformMakeScale(1.7f, 1.7f);
    
    if ([self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willShowMenuViewController:)]) {
        [self.delegate sideMenu:self willShowMenuViewController:menuViewController];
    }
}

- (void)__showLeftMenuViewController
{
    if (!self.leftMenuViewController) {
        return;
    }
    self.leftMenuViewController.view.hidden = NO;
    self.rightMenuViewController.view.hidden = YES;
    [self.view.window endEditing:YES];
    [self __addContentButton];
    [self __updateContentViewShadow];
    
    [UIView animateWithDuration:self.animationDuration animations:^{
        
        CGFloat minWidth = CGRectGetWidth(self.view.bounds) - cMinContentWidth;
        CGFloat ratio = minWidth / CGRectGetWidth(self.view.bounds);
        CGFloat angle = ratio * cMaxRotateAngel;
        self.contentViewContainer.layer.zPosition = 100;
        
        CATransform3D translation = CATransform3DMakeTranslation(minWidth, 0, 0);
            translation.m34 = 1 / 700.f;
    
        CATransform3D scale = CATransform3DScale(translation, 1, self.contentViewScaleValue, 1);
        
        CATransform3D rotate = CATransform3DMakeRotation(angle, 0, 1, 0);
        CATransform3D mat = CATransform3DConcat(rotate, scale);
        
        self.contentViewContainer.layer.transform = mat;

        self.menuViewContainer.alpha = 1.0f;
        self.menuViewContainer.transform = CGAffineTransformIdentity;
        if (self.scaleBackgroundImageView)
            self.backgroundImageView.transform = CGAffineTransformIdentity;
        
        if (self.needBlurredImageEffect) {
            self.contentImageView.hidden = NO;
            [self addContentBlurredImage];
        }
    } completion:^(BOOL finished) {
        [self __addContentViewControllerMotionEffects];
       
        if (!self.visible && [self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:didShowMenuViewController:)]) {
            [self.delegate sideMenu:self didShowMenuViewController:self.leftMenuViewController];
        }
        
        self.visible = YES;
        self.leftMenuVisible = YES;
    }];
    
    [self __statusBarNeedsAppearanceUpdate];
}

- (void)__showRightMenuViewController
{
    if (!self.rightMenuViewController) {
        return;
    }
    self.leftMenuViewController.view.hidden = YES;
    self.rightMenuViewController.view.hidden = NO;
    [self.view.window endEditing:YES];
    [self __addContentButton];
    [self __updateContentViewShadow];
    
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:self.animationDuration animations:^{
        
        self.contentViewContainer.layer.zPosition = 100;
        CGFloat minWidth = CGRectGetWidth(self.view.bounds) - cMinContentWidth;
        CGFloat ratio = minWidth / CGRectGetWidth(self.view.bounds);
        CGFloat angle =  ratio * cMaxRotateAngel;
        CATransform3D translation = CATransform3DMakeTranslation(- minWidth, 0, 0);
        translation.m34 = - 1 / 700.f;
        
        CATransform3D scale = CATransform3DScale(translation, 1, self.contentViewScaleValue, 1);
        CATransform3D rotate = CATransform3DMakeRotation(angle, 0, 1, 0);
        CATransform3D mat = CATransform3DConcat(rotate, scale);
        self.contentViewContainer.layer.transform = mat;
        
        self.menuViewContainer.alpha = 1.0f;
        self.menuViewContainer.transform = CGAffineTransformIdentity;
        if (self.scaleBackgroundImageView)
            self.backgroundImageView.transform = CGAffineTransformIdentity;
        if (self.needBlurredImageEffect) {
            self.contentImageView.hidden = NO;
            [self addContentBlurredImage];
        }
    } completion:^(BOOL finished) {
        if (!self.rightMenuVisible && [self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:didShowMenuViewController:)]) {
            [self.delegate sideMenu:self didShowMenuViewController:self.rightMenuViewController];
        }
        
        self.visible = !(self.contentViewContainer.frame.size.width == self.view.bounds.size.width && self.contentViewContainer.frame.size.height == self.view.bounds.size.height && self.contentViewContainer.frame.origin.x == 0 && self.contentViewContainer.frame.origin.y == 0);
        self.rightMenuVisible = self.visible;
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        [self __addContentViewControllerMotionEffects];
    }];
    
    [self __statusBarNeedsAppearanceUpdate];
}

- (void)__hideViewController:(UIViewController *)viewController
{
    [viewController willMoveToParentViewController:nil];
    [viewController.view removeFromSuperview];
    [viewController removeFromParentViewController];
}

- (void)__hideMenuViewControllerAnimated:(BOOL)animated
{
    self.contentImageView.hidden = YES;
    self.contentImageView.image = nil;
    
    BOOL rightMenuVisible = self.rightMenuVisible;
    if ([self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willHideMenuViewController:)]) {
        [self.delegate sideMenu:self willHideMenuViewController:rightMenuVisible ? self.rightMenuViewController : self.leftMenuViewController];
    }
    
    self.visible = NO;
    self.leftMenuVisible = NO;
    self.rightMenuVisible = NO;
    [self.contentButton removeFromSuperview];
    
    __typeof (self) __weak weakSelf = self;
    void (^animationBlock)(void) = ^{
        __typeof (weakSelf) __strong strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.contentViewContainer.transform = CGAffineTransformIdentity;
        strongSelf.contentViewContainer.frame = strongSelf.view.bounds;
        if (strongSelf.scaleMenuView) {
            strongSelf.menuViewContainer.transform = strongSelf.menuViewControllerTransformation;
        }
        strongSelf.menuViewContainer.alpha = 0;
        if (strongSelf.scaleBackgroundImageView) {
            strongSelf.backgroundImageView.transform = CGAffineTransformMakeScale(1.7f, 1.7f);
        }
        if (strongSelf.parallaxEnabled) {
            IF_IOS7_OR_GREATER(
               for (UIMotionEffect *effect in strongSelf.contentViewContainer.motionEffects) {
                   [strongSelf.contentViewContainer removeMotionEffect:effect];
               }
            );
        }
    };
    void (^completionBlock)(void) = ^{
        __typeof (weakSelf) __strong strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (!strongSelf.visible && [strongSelf.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [strongSelf.delegate respondsToSelector:@selector(sideMenu:didHideMenuViewController:)]) {
            [strongSelf.delegate sideMenu:strongSelf didHideMenuViewController:rightMenuVisible ? strongSelf.rightMenuViewController : strongSelf.leftMenuViewController];
        }
    };
    
    if (animated) {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [UIView animateWithDuration:self.animationDuration animations:^{
            animationBlock();
        } completion:^(BOOL finished) {
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            completionBlock();
        }];
    } else {
        animationBlock();
        completionBlock();
    }
    [self __statusBarNeedsAppearanceUpdate];
}

- (void)__addContentButton
{
    if (self.contentButton.superview)
        return;

    self.contentButton.autoresizingMask = UIViewAutoresizingNone;
    self.contentButton.frame = self.contentViewContainer.bounds;
    self.contentButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentViewContainer addSubview:self.contentButton];

    self.contentImageView.autoresizingMask = UIViewAutoresizingNone;
    self.contentImageView.frame = self.contentViewContainer.bounds;
    self.contentImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.contentViewContainer addSubview:self.contentImageView];
}

- (void)__statusBarNeedsAppearanceUpdate
{
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [UIView animateWithDuration:0.3f animations:^{
            [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
        }];
    }
}

- (void)__updateContentViewShadow
{
    if (self.contentViewShadowEnabled) {
        CALayer *layer = self.contentViewContainer.layer;
        UIBezierPath *path = [UIBezierPath bezierPathWithRect:layer.bounds];
        layer.shadowPath = path.CGPath;
        layer.shadowColor = self.contentViewShadowColor.CGColor;
        layer.shadowOffset = self.contentViewShadowOffset;
        layer.shadowOpacity = self.contentViewShadowOpacity;
        layer.shadowRadius = self.contentViewShadowRadius;
    }
}

- (void)__resetContentViewScale
{
    CGAffineTransform t = self.contentViewContainer.transform;
    CGFloat scale = sqrt(t.a * t.a + t.c * t.c);
    CGRect frame = self.contentViewContainer.frame;
    self.contentViewContainer.transform = CGAffineTransformIdentity;
    self.contentViewContainer.transform = CGAffineTransformMakeScale(scale, scale);
    self.contentViewContainer.frame = frame;
}

#pragma mark -
#pragma mark iOS 7 Motion Effects (Private)

- (void)__addMenuViewControllerMotionEffects
{
    if (self.parallaxEnabled) {
        IF_IOS7_OR_GREATER(
           for (UIMotionEffect *effect in self.menuViewContainer.motionEffects) {
               [self.menuViewContainer removeMotionEffect:effect];
           }
           UIInterpolatingMotionEffect *interpolationHorizontal = [[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
           interpolationHorizontal.minimumRelativeValue = @(self.parallaxMenuMinimumRelativeValue);
           interpolationHorizontal.maximumRelativeValue = @(self.parallaxMenuMaximumRelativeValue);
           
           UIInterpolatingMotionEffect *interpolationVertical = [[UIInterpolatingMotionEffect alloc]initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
           interpolationVertical.minimumRelativeValue = @(self.parallaxMenuMinimumRelativeValue);
           interpolationVertical.maximumRelativeValue = @(self.parallaxMenuMaximumRelativeValue);
           
           [self.menuViewContainer addMotionEffect:interpolationHorizontal];
           [self.menuViewContainer addMotionEffect:interpolationVertical];
        );
    }
}

- (void)__addContentViewControllerMotionEffects
{
    if (self.parallaxEnabled) {
        IF_IOS7_OR_GREATER(
            for (UIMotionEffect *effect in self.contentViewContainer.motionEffects) {
               [self.contentViewContainer removeMotionEffect:effect];
            }
            [UIView animateWithDuration:0.2 animations:^{
                UIInterpolatingMotionEffect *interpolationHorizontal = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
                interpolationHorizontal.minimumRelativeValue = @(self.parallaxContentMinimumRelativeValue);
                interpolationHorizontal.maximumRelativeValue = @(self.parallaxContentMaximumRelativeValue);

                UIInterpolatingMotionEffect *interpolationVertical = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
                interpolationVertical.minimumRelativeValue = @(self.parallaxContentMinimumRelativeValue);
                interpolationVertical.maximumRelativeValue = @(self.parallaxContentMaximumRelativeValue);

                [self.contentViewContainer addMotionEffect:interpolationHorizontal];
                [self.contentViewContainer addMotionEffect:interpolationVertical];
            }];
        );
    }
}

#pragma mark -
#pragma mark UIGestureRecognizer Delegate (Private)

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    IF_IOS7_OR_GREATER(
       if (self.interactivePopGestureRecognizerEnabled && [self.contentViewController isKindOfClass:[UINavigationController class]]) {
           UINavigationController *navigationController = (UINavigationController *)self.contentViewController;
           if (navigationController.viewControllers.count > 1 && navigationController.interactivePopGestureRecognizer.enabled) {
               return NO;
           }
       }
    );
  
    CGFloat minPanWidth = 120.f;
    if (self.panFromEdge && [gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && !self.visible) {
        CGPoint point = [touch locationInView:gestureRecognizer.view];
        if ((point.x < minPanWidth && self.leftMenuViewController) || (point.x > (self.view.frame.size.width - minPanWidth) && self.rightMenuViewController)) {
            return YES;
        } else {
            return NO;
        }
    }
    
    return YES;
}

#pragma mark -
#pragma mark Pan gesture recognizer (Private)


- (void)__panGestureRecognized:(UIPanGestureRecognizer *)recognizer
{
    if ([self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:didRecognizePanGesture:)])
        [self.delegate sideMenu:self didRecognizePanGesture:recognizer];
    
    if (!self.panGestureEnabled) {
        return;
    }
    
    CGPoint point = [recognizer translationInView:self.view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self __updateContentViewShadow];
        
        self.originalPoint = CGPointMake(self.contentViewContainer.center.x - CGRectGetWidth(self.contentViewContainer.bounds) / 2.0,
                                         self.contentViewContainer.center.y - CGRectGetHeight(self.contentViewContainer.bounds) / 2.0);
        self.menuViewContainer.transform = CGAffineTransformIdentity;
        if (self.scaleBackgroundImageView) {
            self.backgroundImageView.transform = CGAffineTransformIdentity;
            self.backgroundImageView.frame = self.view.bounds;
        }
        self.menuViewContainer.frame = self.view.bounds;
        [self __addContentButton];
        [self.view.window endEditing:YES];
        self.didNotifyDelegate = NO;
       
//        self.contentViewContainer.frame = self.view.bounds;
        self.contentViewContainer.layer.zPosition = 100;

        if (self.needBlurredImageEffect) {
            self.contentImageView.hidden = NO;
            [self addContentBlurredImage];
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        // Limit size
        //
        BOOL shouldChangeTransform = YES;
        CGFloat contentAlpha = 0;
        CGFloat minWidth = cMinContentWidth;
        CGSize screenSize = self.view.bounds.size;
        if (point.x < 0) {
            if ((screenSize.width + point.x) <= minWidth) {
                point.x = - screenSize.width + minWidth;
                contentAlpha = 1.0;
            }
            else {
                if (fabs(point.x) < minWidth) {
                    contentAlpha = fabs(point.x) / screenSize.width;
                }
                else {
                    contentAlpha = (fabs(point.x) + minWidth) / screenSize.width;
                }
            }
        } else {
            if ((screenSize.width - point.x) <= minWidth) {
                point.x = screenSize.width - minWidth;
                contentAlpha = 1.0;
            }
            else {
                if (fabs(point.x) < minWidth) {
                    contentAlpha = fabs(point.x) / screenSize.width;
                }
                else {
                    contentAlpha = (fabs(point.x) + minWidth) / screenSize.width;
                }
            }
        }
        [recognizer setTranslation:point inView:self.view];
       
        if (!self.didNotifyDelegate) {
            if (point.x > 0) {
                if (!self.visible && [self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willShowMenuViewController:)]) {
                    [self.delegate sideMenu:self willShowMenuViewController:self.leftMenuViewController];
                }
            }
            if (point.x < 0) {
                if (!self.visible && [self.delegate conformsToProtocol:@protocol(RESideMenuDelegate)] && [self.delegate respondsToSelector:@selector(sideMenu:willShowMenuViewController:)]) {
                    [self.delegate sideMenu:self willShowMenuViewController:self.rightMenuViewController];
                }
            }
            self.didNotifyDelegate = YES;
        }

        CGFloat maxContentX = CGRectGetWidth(self.view.bounds) - cMinContentWidth;
        CGFloat translationX = point.x;
        CGFloat m43Sign = 1;
        CGFloat delta = 1;
        
        if (self.visible) {
            if (self.leftMenuVisible) {
                if (point.x > 0) {
                    translationX = maxContentX;
                    contentAlpha = 1.0;
                }
                else {
                    translationX = maxContentX - fabs(point.x);
                    if (fabs(point.x) > minWidth) {
                        contentAlpha = translationX / screenSize.width;
                    }
                    else {
                        contentAlpha = (translationX + minWidth)/ screenSize.width;
                    }
                    delta = fabs(translationX) / (screenSize.width - minWidth);
 
                }
                m43Sign = 1;
            }
            else if (self.rightMenuVisible) {
                if (point.x < 0) {
                    translationX = - maxContentX;
                    contentAlpha = 1.0;
                }
                else {
                    translationX = - maxContentX + fabs(point.x);
                    if (fabs(point.x) > minWidth) {
                        contentAlpha = fabs(translationX)  / screenSize.width;
                    }
                    else {
                        contentAlpha = (fabs(translationX) + minWidth) / screenSize.width;
                    }
                    delta = fabs(translationX) / (screenSize.width - minWidth);

                }
                m43Sign = - 1;
            }
        }
        else {
            if (point.x < 0 && !self.rightMenuViewController) {
                point.x = 0;
                translationX = 0;
                shouldChangeTransform = NO;
            }
            else if (point.x > 0 && !self.leftMenuViewController) {
                point.x = 0;
                translationX = 0;
                shouldChangeTransform = NO;
            }
            
            if (point.x < 0) {
                m43Sign = -1;
            }
            else {
                m43Sign = 1;
            }
            delta = fabs(point.x) / (screenSize.width - minWidth);
        }
        
        if (fabs(translationX) > screenSize.width) {
            if (translationX < 0) {
                translationX = - screenSize.width;
            }
            else {
                translationX = screenSize.width;
            }
        }
        
        CGFloat contentViewScale = self.scaleContentView ? 1 - ((1 - self.contentViewScaleValue) * delta) : 1;
        CGFloat backgroundViewScale = 1.7f - (0.7f * delta);
        CGFloat menuViewScale = 1.7f - (0.7f * delta);
        
        if (!self.bouncesHorizontally) {
            contentViewScale = MAX(contentViewScale, self.contentViewScaleValue);
            backgroundViewScale = MAX(backgroundViewScale, 1.0);
            menuViewScale = MAX(menuViewScale, 1.0);
        }
        
        self.menuViewContainer.alpha = 1;//delta;
        
        if (self.scaleBackgroundImageView) {
            self.backgroundImageView.transform = CGAffineTransformMakeScale(backgroundViewScale, backgroundViewScale);
        }
        
        if (self.scaleMenuView) {
            self.menuViewContainer.transform = CGAffineTransformMakeScale(menuViewScale, menuViewScale);
        }
        
        if (self.scaleBackgroundImageView) {
            if (backgroundViewScale < 1) {
                self.backgroundImageView.transform = CGAffineTransformIdentity;
            }
        }
        
        if (self.needBlurredImageEffect) {
            self.contentImageView.alpha = contentAlpha;
        }
        else {
            self.contentImageView.alpha = 0.f;
        }
        
        //change transfor3D
        if (shouldChangeTransform) {
            CGFloat blurWidth = fabs(translationX);
            CGFloat ratio = blurWidth / self.view.frame.size.width;
            CGFloat angle = ratio * cMaxRotateAngel;
            
//            NSLog(@"point:%@ angle:%f scaleY:%f, transX:%f", NSStringFromCGPoint(point), angle, contentViewScale, translationX);
            
            CATransform3D translation = CATransform3DMakeTranslation(translationX, 0, 0);
            translation.m34 = m43Sign * (1 / 700.f);
            CATransform3D scale = CATransform3DScale(translation, 1, contentViewScale, 1);
            CATransform3D rotate = CATransform3DMakeRotation(angle, 0, 1, 0);
            CATransform3D mat = CATransform3DConcat(rotate, scale);
            self.contentViewContainer.layer.transform = mat;
        }
        else {
            self.contentViewContainer.layer.transform = CATransform3DIdentity;
        }
 
        [self __statusBarNeedsAppearanceUpdate];
    }
    else if (recognizer.state == UIGestureRecognizerStateEnded) {
        self.didNotifyDelegate = NO;
        
        if (self.panMinimumOpenThreshold > 0 && (
            (self.contentViewContainer.frame.origin.x < 0 && self.contentViewContainer.frame.origin.x > -((NSInteger)self.panMinimumOpenThreshold)) ||
            (self.contentViewContainer.frame.origin.x > 0 && self.contentViewContainer.frame.origin.x < self.panMinimumOpenThreshold))
            ) {
            [self hideMenuViewController];
        }
        else if (self.contentViewContainer.frame.origin.x == 0) {
            [self __hideMenuViewControllerAnimated:NO];
        }
        else {
            if ([recognizer velocityInView:self.view].x >= 0) {
                if (self.contentViewContainer.frame.origin.x < 0) {
                    [self hideMenuViewController];
                } else {
                    if (self.leftMenuViewController) {
                        [self __showLeftMenuViewController];
                    }
                }
            } else {
                if (self.contentViewContainer.frame.origin.x < 20) {
                    if (self.rightMenuViewController) {
                        [self __showRightMenuViewController];
                    }
                } else {
                    [self hideMenuViewController];
                }
            }
        }
        if (self.needBlurredImageEffect) {
            self.contentImageView.alpha = 1;
        }
//        self.contentViewContainer.layer.shouldRasterize = NO;
    }
    else if (recognizer.state == UIGestureRecognizerStateCancelled) {
        if (self.needBlurredImageEffect) {
           self.contentImageView.hidden = YES;
        }
//        self.contentViewContainer.layer.shouldRasterize = NO;
    }
}

#pragma mark -
#pragma mark Setters

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
    _backgroundImage = backgroundImage;
    if (self.backgroundImageView)
        self.backgroundImageView.image = backgroundImage;
}

- (void)setContentViewController:(UIViewController *)contentViewController
{
    [self __hideViewController:_contentViewController];
    _contentViewController = contentViewController;
    
    [self addChildViewController:self.contentViewController];
    self.contentViewController.view.frame = self.view.bounds;
    [self.contentViewContainer addSubview:self.contentViewController.view];
    [self.contentViewController didMoveToParentViewController:self];
    
    [self __updateContentViewShadow];
    
    if (self.visible) {
        [self __addContentViewControllerMotionEffects];
    }
}

- (void)setLeftMenuViewController:(UIViewController *)leftMenuViewController
{
    [self __hideViewController:_leftMenuViewController];
    _leftMenuViewController = leftMenuViewController;
   
    [self addChildViewController:self.leftMenuViewController];
    self.leftMenuViewController.view.frame = self.view.bounds;
    self.leftMenuViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.menuViewContainer addSubview:self.leftMenuViewController.view];
    [self.leftMenuViewController didMoveToParentViewController:self];
    
    [self __addMenuViewControllerMotionEffects];
    [self.view bringSubviewToFront:self.contentViewContainer];
}

- (void)setRightMenuViewController:(UIViewController *)rightMenuViewController
{
    [self __hideViewController:_rightMenuViewController];
    _rightMenuViewController = rightMenuViewController;
    
    [self addChildViewController:self.rightMenuViewController];
    self.rightMenuViewController.view.frame = self.view.bounds;
    self.rightMenuViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.menuViewContainer addSubview:self.rightMenuViewController.view];
    [self.rightMenuViewController didMoveToParentViewController:self];
    
    [self __addMenuViewControllerMotionEffects];
    [self.view bringSubviewToFront:self.contentViewContainer];
}

#pragma mark -
#pragma mark View Controller Rotation handler

- (BOOL)shouldAutorotate
{
    return self.contentViewController.shouldAutorotate;
}

- (NSUInteger)supportedInterfaceOrientations{
    return self.contentViewController.supportedInterfaceOrientations;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return self.contentViewController.preferredInterfaceOrientationForPresentation;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    if (self.visible) {
        self.menuViewContainer.bounds = self.view.bounds;
        self.contentViewContainer.transform = CGAffineTransformIdentity;
        self.contentViewContainer.frame = self.view.bounds;
        
        if (self.scaleContentView) {
            self.contentViewContainer.transform = CGAffineTransformMakeScale(self.contentViewScaleValue, self.contentViewScaleValue);
        } else {
            self.contentViewContainer.transform = CGAffineTransformIdentity;
        }
        
        CGPoint center;
        if (self.leftMenuVisible) {
            center = CGPointMake((UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? self.contentViewInLandscapeOffsetCenterX + CGRectGetHeight(self.view.frame) : self.contentViewInPortraitOffsetCenterX + CGRectGetWidth(self.view.frame)), self.contentViewContainer.center.y);
        } else {
            center = CGPointMake((UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? -self.contentViewInLandscapeOffsetCenterX : -self.contentViewInPortraitOffsetCenterX), self.contentViewContainer.center.y);
        }
        
        self.contentViewContainer.center = center;
    }
    
    [self __updateContentViewShadow];
}

#pragma mark -
#pragma mark Status Bar Appearance Management

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleDefault;
    IF_IOS7_OR_GREATER(
       statusBarStyle = self.visible ? self.menuPreferredStatusBarStyle : self.contentViewController.preferredStatusBarStyle;
       if (self.contentViewContainer.frame.origin.y > 10) {
           statusBarStyle = self.menuPreferredStatusBarStyle;
       } else {
           statusBarStyle = self.contentViewController.preferredStatusBarStyle;
       }
    );
    return statusBarStyle;
}

- (BOOL)prefersStatusBarHidden
{
    BOOL statusBarHidden = NO;
    IF_IOS7_OR_GREATER(
        statusBarHidden = self.visible ? self.menuPrefersStatusBarHidden : self.contentViewController.prefersStatusBarHidden;
        if (self.contentViewContainer.frame.origin.y > 10) {
            statusBarHidden = self.menuPrefersStatusBarHidden;
        } else {
            statusBarHidden = self.contentViewController.prefersStatusBarHidden;
        }
    );
    return statusBarHidden;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    UIStatusBarAnimation statusBarAnimation = UIStatusBarAnimationNone;
    IF_IOS7_OR_GREATER(
        statusBarAnimation = self.visible ? self.leftMenuViewController.preferredStatusBarUpdateAnimation : self.contentViewController.preferredStatusBarUpdateAnimation;
        if (self.contentViewContainer.frame.origin.y > 10) {
            statusBarAnimation = self.leftMenuViewController.preferredStatusBarUpdateAnimation;
        } else {
            statusBarAnimation = self.contentViewController.preferredStatusBarUpdateAnimation;
        }
    );
    return statusBarAnimation;
}

@end
