ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DynamicIslandLSColor16Prefs
DynamicIslandLSColor16Prefs_FILES = DILSRootListController.m
DynamicIslandLSColor16Prefs_FRAMEWORKS = Foundation CoreFoundation UIKit
DynamicIslandLSColor16Prefs_PRIVATE_FRAMEWORKS = Preferences
DynamicIslandLSColor16Prefs_INSTALL_PATH = /Library/PreferenceBundles
DynamicIslandLSColor16Prefs_INFOPLIST_FILE = Info.plist
DynamicIslandLSColor16Prefs_RESOURCE_FILES = Resources/icon.png
DynamicIslandLSColor16Prefs_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter

include $(THEOS_MAKE_PATH)/bundle.mk
