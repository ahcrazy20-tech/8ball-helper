THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PoolHelper

PoolHelper_FILES = Tweak.x OverlayWindow.m PoolPredictor.mm
PoolHelper_FRAMEWORKS = UIKit Foundation QuartzCore Vision CoreGraphics
PoolHelper_CFLAGS = -fobjc-arc -std=c++17
PoolHelper_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk

# For building standalone dylib for TrollFools injection
# Use: make package

# For jailed IPA injection, build dylib only:
# make clean && make
# dylib will be at .theos/obj/debug/libPoolHelper.dylib
