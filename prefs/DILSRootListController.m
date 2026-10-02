#import "DILSRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

static NSString * const DILSPrefsDomain = @"com.551.dynamicislandlscolor16";
static NSString * const DILSPrefsChanged = @"com.551.dynamicislandlscolor16/preferences.changed";

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

static NSString *DILSStringFromColor(UIColor *color) {
    CGFloat red = 175.0 / 255.0;
    CGFloat green = 82.0 / 255.0;
    CGFloat blue = 222.0 / 255.0;
    CGFloat alpha = 1.0;

    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        return @"#AF52DE";
    }

    return [NSString stringWithFormat:@"#%02X%02X%02X",
            (unsigned int)lrint(red * 255.0),
            (unsigned int)lrint(green * 255.0),
            (unsigned int)lrint(blue * 255.0)];
}

@interface DILSRootListController () <UIColorPickerViewControllerDelegate>
@end

@implementation DILSRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Dynamic Island LS Color 16";
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id fallback = [specifier propertyForKey:@"default"];
    if (!key) return fallback;

    CFPreferencesAppSynchronize((__bridge CFStringRef)DILSPrefsDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                        (__bridge CFStringRef)DILSPrefsDomain);
    return value ? CFBridgingRelease(value) : fallback;
}

- (void)postPreferencesChanged {
    CFPreferencesAppSynchronize((__bridge CFStringRef)DILSPrefsDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)DILSPrefsChanged,
                                         NULL,
                                         NULL,
                                         true);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key,
                             (__bridge CFPropertyListRef)value,
                             (__bridge CFStringRef)DILSPrefsDomain);
    [self postPreferencesChanged];
}

- (PSSpecifier *)switchSpecifier {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"Enable"
                                                             target:self
                                                                set:@selector(setPreferenceValue:specifier:)
                                                                get:@selector(readPreferenceValue:)
                                                             detail:nil
                                                               cell:PSSwitchCell
                                                               edit:nil];
    [specifier setProperty:DILSPrefsDomain forKey:@"defaults"];
    [specifier setProperty:@"enabled" forKey:@"key"];
    [specifier setProperty:@YES forKey:@"default"];
    [specifier setProperty:DILSPrefsChanged forKey:@"PostNotification"];
    return specifier;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *items = [NSMutableArray array];

    PSSpecifier *mainGroup = [PSSpecifier groupSpecifierWithName:@"Dynamic Island LS Color 16"];
    [mainGroup setProperty:@"Changes the native Dynamic Island border and Lock Screen lock/Face ID icon to the selected colour." forKey:@"footerText"];
    [items addObject:mainGroup];
    [items addObject:[self switchSpecifier]];

    PSSpecifier *appearanceGroup = [PSSpecifier groupSpecifierWithName:@"Appearance"];
    [appearanceGroup setProperty:@"The selected colour is used for both the Dynamic Island border and Lock Screen lock icon." forKey:@"footerText"];
    [items addObject:appearanceGroup];

    PSSpecifier *color = [PSSpecifier preferenceSpecifierNamed:@"Color"
                                                        target:self
                                                           set:nil
                                                           get:nil
                                                        detail:nil
                                                          cell:PSButtonCell
                                                          edit:nil];
    [color setButtonAction:@selector(openColorPicker)];
    [color setProperty:NSStringFromSelector(@selector(openColorPicker)) forKey:@"action"];
    [items addObject:color];

    PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:@"Reset Color"
                                                        target:self
                                                           set:nil
                                                           get:nil
                                                        detail:nil
                                                          cell:PSButtonCell
                                                          edit:nil];
    [reset setButtonAction:@selector(resetColor)];
    [reset setProperty:NSStringFromSelector(@selector(resetColor)) forKey:@"action"];
    [items addObject:reset];

    PSSpecifier *aboutGroup = [PSSpecifier groupSpecifierWithName:@"About"];
    [items addObject:aboutGroup];

    PSSpecifier *repo = [PSSpecifier preferenceSpecifierNamed:@"GitHub"
                                                       target:self
                                                          set:nil
                                                          get:nil
                                                       detail:nil
                                                         cell:PSButtonCell
                                                         edit:nil];
    [repo setButtonAction:@selector(openGitHub)];
    [repo setProperty:NSStringFromSelector(@selector(openGitHub)) forKey:@"action"];
    [items addObject:repo];

    _specifiers = [items copy];
    return _specifiers;
}

- (NSString *)currentColorHex {
    CFPreferencesAppSynchronize((__bridge CFStringRef)DILSPrefsDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("color"),
                                                        (__bridge CFStringRef)DILSPrefsDomain);
    id object = value ? CFBridgingRelease(value) : nil;
    return [object isKindOfClass:[NSString class]] ? object : @"#AF52DE";
}

- (void)openColorPicker {
    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.delegate = self;
    picker.selectedColor = DILSColorFromHexString([self currentColorHex]);
    picker.supportsAlpha = NO;
    picker.title = @"Color";
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)openColorPicker:(id)sender {
    (void)sender;
    [self openColorPicker];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    NSString *hex = DILSStringFromColor(viewController.selectedColor ?: DILSColorFromHexString(@"#AF52DE"));

    CFPreferencesSetAppValue(CFSTR("color"),
                             (__bridge CFPropertyListRef)hex,
                             (__bridge CFStringRef)DILSPrefsDomain);
    [self postPreferencesChanged];
}

- (void)resetColor {
    CFPreferencesSetAppValue(CFSTR("color"),
                             (__bridge CFPropertyListRef)@"#AF52DE",
                             (__bridge CFStringRef)DILSPrefsDomain);
    [self postPreferencesChanged];
}

- (void)resetColor:(id)sender {
    (void)sender;
    [self resetColor];
}

- (void)openGitHub {
    NSURL *url = [NSURL URLWithString:@"https://github.com/551UK/Dynamic-Island-LS-Color-16"];
    if (!url) return;

    UIApplication *application = UIApplication.sharedApplication;
    if ([application respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [application openURL:url options:@{} completionHandler:nil];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [application openURL:url];
#pragma clang diagnostic pop
    }
}

- (void)openGitHub:(id)sender {
    (void)sender;
    [self openGitHub];
}

@end
