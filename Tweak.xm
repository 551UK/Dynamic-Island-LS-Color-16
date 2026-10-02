#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
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

static NSString * const DILSPrefsDomain = @"com.551.dynamicislandlscolor16";
static NSString * const DILSPrefsChanged = @"com.551.dynamicislandlscolor16/preferences.changed";

static BOOL DILSEnabled = YES;
static UIColor *DILSSelectedColor = nil;
static NSHashTable *DILSApertureViews = nil;
static NSHashTable *DILSLockViews = nil;

static char DILSOriginalApertureTintKey;
static char DILSOriginalFiltersKey;
static char DILSOriginalTintKey;
static char DILSStoredAppearanceKey;

static id DILSCopyPreference(NSString *key) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)DILSPrefsDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)DILSPrefsDomain);
    return value ? CFBridgingRelease(value) : nil;
}

static UIColor *DILSColorFromHexString(NSString *string) {
    if (![string isKindOfClass:[NSString class]]) {
        return [UIColor colorWithRed:(175.0 / 255.0)
                               green:(82.0 / 255.0)
                                blue:(222.0 / 255.0)
                               alpha:1.0];
    }

    NSString *hex = [[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];

    if (hex.length != 6) {
        return [UIColor colorWithRed:(175.0 / 255.0)
                               green:(82.0 / 255.0)
                                blue:(222.0 / 255.0)
                               alpha:1.0];
    }

    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&rgb]) {
        return [UIColor colorWithRed:(175.0 / 255.0)
                               green:(82.0 / 255.0)
                                blue:(222.0 / 255.0)
                               alpha:1.0];
    }

    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

static void DILSReloadPreferences(void) {
    id value = DILSCopyPreference(@"enabled");
    DILSEnabled = value ? [value boolValue] : YES;

    value = DILSCopyPreference(@"color");
    DILSSelectedColor = DILSColorFromHexString([value isKindOfClass:[NSString class]] ? value : @"#AF52DE");
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

static void DILSStoreOriginalAppearance(UIView *view) {
    if (!view || [objc_getAssociatedObject(view, &DILSStoredAppearanceKey) boolValue]) return;

    objc_setAssociatedObject(view, &DILSStoredAppearanceKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id filters = nil;
    @try {
        filters = [view.layer valueForKey:@"filters"];
    } @catch (__unused NSException *exception) {
    }

    objc_setAssociatedObject(view,
                             &DILSOriginalFiltersKey,
                             filters ?: (id)[NSNull null],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view,
                             &DILSOriginalTintKey,
                             view.tintColor ?: (id)[NSNull null],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DILSRestoreAppearance(UIView *view) {
    if (!view || ![objc_getAssociatedObject(view, &DILSStoredAppearanceKey) boolValue]) return;

    id filters = objc_getAssociatedObject(view, &DILSOriginalFiltersKey);
    @try {
        [view.layer setValue:(filters == [NSNull null] ? nil : filters) forKey:@"filters"];
    } @catch (__unused NSException *exception) {
    }

    id tint = objc_getAssociatedObject(view, &DILSOriginalTintKey);
    view.tintColor = (tint == [NSNull null]) ? nil : tint;
}

static void DILSApplyMonochromeColor(UIView *view) {
    if (!view) return;

    DILSStoreOriginalAppearance(view);

    if (!DILSEnabled) {
        DILSRestoreAppearance(view);
        return;
    }

    UIColor *color = DILSSelectedColor ?: UIColor.whiteColor;
    view.tintColor = color;

    @try {
        Class filterClass = NSClassFromString(@"CAFilter");
        SEL filterSelector = NSSelectorFromString(@"filterWithType:");

        if (!filterClass || ![filterClass respondsToSelector:filterSelector]) return;

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

    UIView *lockView = DILSViewForKey(rootView, @"_lockView");
    if (lockView) {
        DILSApplyMonochromeColor(lockView);
    } else {
        DILSApplyMonochromeColor(rootView);
    }

    UIView *iconContainer = DILSViewForKey(rootView, @"_iconContainerView");
    if (iconContainer) {
        DILSStoreOriginalAppearance(iconContainer);
        if (DILSEnabled) {
            iconContainer.tintColor = DILSSelectedColor;
        } else {
            DILSRestoreAppearance(iconContainer);
        }
    }
}

static void DILSRegisterAperture(SBSystemApertureContainerView *view) {
    if (!view) return;
    if (!DILSApertureViews) DILSApertureViews = [NSHashTable weakObjectsHashTable];
    [DILSApertureViews addObject:view];
}

static void DILSRegisterLock(SBUIProudLockIconView *view) {
    if (!view) return;
    if (!DILSLockViews) DILSLockViews = [NSHashTable weakObjectsHashTable];
    [DILSLockViews addObject:view];
}

static void DILSRefreshVisibleViews(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SBSystemApertureContainerView *view in [DILSApertureViews allObjects]) {
            if (DILSEnabled) {
                [view setKeyLineTintColor:DILSSelectedColor];
            } else {
                id original = objc_getAssociatedObject(view, &DILSOriginalApertureTintKey);
                UIColor *restore = (original == [NSNull null]) ? nil : original;
                [view setKeyLineTintColor:restore];

                if ([view respondsToSelector:@selector(_applySettingsValues)]) {
                    [view _applySettingsValues];
                }
            }

            [view setNeedsLayout];
            [view layoutIfNeeded];
        }

        for (SBUIProudLockIconView *view in [DILSLockViews allObjects]) {
            DILSApplyLockColor(view);
            [view setNeedsLayout];
        }
    });
}

static void DILSPreferencesChanged(CFNotificationCenterRef center,
                                   void *observer,
                                   CFStringRef name,
                                   const void *object,
                                   CFDictionaryRef userInfo) {
    DILSReloadPreferences();
    DILSRefreshVisibleViews();
}

%hook SBSystemApertureContainerView

- (instancetype)initWithInterfaceElementIdentifier:(id)identifier {
    id result = %orig(identifier);
    if (!result) return nil;

    DILSRegisterAperture((SBSystemApertureContainerView *)result);

    UIColor *original = [(SBSystemApertureContainerView *)result keyLineTintColor];
    objc_setAssociatedObject(result,
                             &DILSOriginalApertureTintKey,
                             original ?: (id)[NSNull null],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (DILSEnabled) {
        [(SBSystemApertureContainerView *)result setKeyLineTintColor:DILSSelectedColor];
    }

    return result;
}

- (void)setKeyLineTintColor:(UIColor *)color {
    DILSRegisterAperture(self);

    if (!DILSEnabled) {
        %orig(color);
        return;
    }

    if (!color || ![color isEqual:DILSSelectedColor]) {
        objc_setAssociatedObject(self,
                                 &DILSOriginalApertureTintKey,
                                 color ?: (id)[NSNull null],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    %orig(DILSSelectedColor);
}

- (UIColor *)keyLineTintColor {
    return DILSEnabled ? DILSSelectedColor : %orig;
}

- (UIColor *)_validatedKeyLineTintColor {
    return DILSEnabled ? DILSSelectedColor : %orig;
}

- (void)_applySettingsValues {
    %orig;
    DILSRegisterAperture(self);

    if (DILSEnabled) {
        [self setKeyLineTintColor:DILSSelectedColor];
    }
}

- (void)layoutSubviews {
    %orig;
    DILSRegisterAperture(self);

    if (DILSEnabled) {
        [self setKeyLineTintColor:DILSSelectedColor];
    }
}

%end

%hook SBUIProudLockIconView

- (void)didMoveToWindow {
    %orig;
    DILSRegisterLock(self);
    DILSApplyLockColor(self);
}

- (void)layoutSubviews {
    %orig;
    DILSRegisterLock(self);
    DILSApplyLockColor(self);
}

- (void)setState:(long long)state
        animated:(BOOL)animated
      updateText:(BOOL)updateText
         options:(long long)options
      completion:(id)completion {
    %orig(state, animated, updateText, options, completion);
    DILSRegisterLock(self);
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
    DILSRegisterLock(self);
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
    DILSRegisterLock(self);
    DILSApplyLockColor(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        DILSApplyLockColor(self);
    });
}

%end

%ctor {
    @autoreleasepool {
        DILSApertureViews = [NSHashTable weakObjectsHashTable];
        DILSLockViews = [NSHashTable weakObjectsHashTable];
        DILSReloadPreferences();

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        DILSPreferencesChanged,
                                        (__bridge CFStringRef)DILSPrefsChanged,
                                        NULL,
                                        CFNotificationSuspensionBehaviorCoalesce);
    }
}
