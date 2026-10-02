#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface SBSystemApertureContainerView : UIView
- (instancetype)initWithInterfaceElementIdentifier:(id)identifier;
- (void)setKeyLineTintColor:(UIColor *)color;
- (UIColor *)keyLineTintColor;
- (UIColor *)_validatedKeyLineTintColor;
- (void)_applySettingsValues;
@end

@interface SBUIProudLockIconView : UIView
- (void)setState:(long long)state
        animated:(BOOL)animated
      updateText:(BOOL)updateText
         options:(long long)options
      completion:(id)completion;
- (void)_transitionToState:(long long)state
                  animated:(BOOL)animated
                updateText:(BOOL)updateText
                   options:(long long)options
                completion:(id)completion;
- (void)_transitionToState:(long long)state
                  animated:(BOOL)animated
                   options:(long long)options
                completion:(id)completion;
@end

static UIColor *DILSPurpleColor(void) {
    static UIColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Bright purple for the first hook-verification build.
        color = [UIColor colorWithRed:(175.0 / 255.0)
                                green:(82.0 / 255.0)
                                 blue:(222.0 / 255.0)
                                alpha:1.0];
    });
    return color;
}

static UIView *DILSViewForKey(id object, NSString *key) {
    if (!object || !key) return nil;

    @try {
        id value = [object valueForKey:key];
        return [value isKindOfClass:[UIView class]] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void DILSApplyMonochromeColor(UIView *view, UIColor *color) {
    if (!view || !color) return;

    view.tintColor = color;

    @try {
        Class filterClass = NSClassFromString(@"CAFilter");
        SEL filterSelector = NSSelectorFromString(@"filterWithType:");

        if (!filterClass || ![filterClass respondsToSelector:filterSelector]) {
            return;
        }

        id filter = ((id (*)(id, SEL, id))objc_msgSend)(
            filterClass,
            filterSelector,
            @"colorMonochrome"
        );

        if (!filter) return;

        [filter setValue:(__bridge id)color.CGColor forKey:@"inputColor"];
        [filter setValue:@1.0 forKey:@"inputAmount"];
        [view.layer setValue:@[filter] forKey:@"filters"];
    } @catch (__unused NSException *exception) {
    }
}

static void DILSApplyLockColor(SBUIProudLockIconView *rootView) {
    if (!rootView) return;

    UIColor *purple = DILSPurpleColor();

    // On iOS 16 the animated lock/Face ID artwork lives in _lockView.
    UIView *lockView = DILSViewForKey(rootView, @"_lockView");
    if (lockView) {
        DILSApplyMonochromeColor(lockView, purple);
    } else {
        // Fallback so the first test still colours the glyph if Apple changes
        // the private ivar layout on a particular 16.x build.
        DILSApplyMonochromeColor(rootView, purple);
    }

    UIView *iconContainer = DILSViewForKey(rootView, @"_iconContainerView");
    if (iconContainer) {
        iconContainer.tintColor = purple;
    }
}

%hook SBSystemApertureContainerView

- (instancetype)initWithInterfaceElementIdentifier:(id)identifier {
    id result = %orig(identifier);
    if (result) {
        [(SBSystemApertureContainerView *)result setKeyLineTintColor:DILSPurpleColor()];
    }
    return result;
}

- (void)setKeyLineTintColor:(UIColor *)color {
    // Force the native Dynamic Island keyline to our colour while leaving
    // Apple's own keyline mode, shape, visibility and animations untouched.
    %orig(DILSPurpleColor());
}

- (UIColor *)keyLineTintColor {
    return DILSPurpleColor();
}

- (UIColor *)_validatedKeyLineTintColor {
    // iOS validates/substitutes the requested tint depending on the sampled
    // background. Returning our colour here prevents the lock-screen keyline
    // from being changed back to white/grey.
    return DILSPurpleColor();
}

- (void)_applySettingsValues {
    %orig;
    [self setKeyLineTintColor:DILSPurpleColor()];
}

- (void)layoutSubviews {
    %orig;
    [self setKeyLineTintColor:DILSPurpleColor()];
}

%end

%hook SBUIProudLockIconView

- (void)didMoveToWindow {
    %orig;
    DILSApplyLockColor(self);
}

- (void)layoutSubviews {
    %orig;
    DILSApplyLockColor(self);
}

- (void)setState:(long long)state
        animated:(BOOL)animated
      updateText:(BOOL)updateText
         options:(long long)options
      completion:(id)completion {
    %orig(state, animated, updateText, options, completion);
    DILSApplyLockColor(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        DILSApplyLockColor(self);
    });
}

- (void)_transitionToState:(long long)state
                  animated:(BOOL)animated
                updateText:(BOOL)updateText
                   options:(long long)options
                completion:(id)completion {
    %orig(state, animated, updateText, options, completion);
    DILSApplyLockColor(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        DILSApplyLockColor(self);
    });
}

- (void)_transitionToState:(long long)state
                  animated:(BOOL)animated
                   options:(long long)options
                completion:(id)completion {
    %orig(state, animated, options, completion);
    DILSApplyLockColor(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        DILSApplyLockColor(self);
    });
}

%end
