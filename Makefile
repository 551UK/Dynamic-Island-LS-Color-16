ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DynamicIslandLSColor16
DynamicIslandLSColor16_FILES = Tweak.xm
DynamicIslandLSColor16_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore
DynamicIslandLSColor16_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
