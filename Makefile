THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

# Stealth build flags + Wizard/Ninja features
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UnityGraphics

# Use innocent name for stealth - looks like Unity graphics plugin
# Includes all Wizard/Ninja features + ball-by-ball safety mode
# Supports newest 8 Ball Pool 56.29.x via vision detection

UnityGraphics_FILES = Tweak.x OverlayWindow.m PoolPredictor.mm Stealth.mm ModMenu.m
UnityGraphics_FRAMEWORKS = UIKit Foundation QuartzCore Vision CoreGraphics
UnityGraphics_PRIVATE_FRAMEWORKS = CoreGraphics
UnityGraphics_CFLAGS = -fobjc-arc -std=c++17 -O2 -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG -Wno-deprecated-declarations -Qunused-arguments
UnityGraphics_CCFLAGS = -O2 -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG -std=c++17
UnityGraphics_LDFLAGS = -lstdc++ -Wl,-x -Wl,-S -Wl,-dead_strip

export ADDITIONAL_LDFLAGS = -Wl,-x -Wl,-S
UnityGraphics_CFLAGS += -DSTEALTH_RELEASE=1 -DENABLE_LOGS=0

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "[*] Applying stealth post-processing..."
	@find .theos/obj -name "*.dylib" -exec sh -c 'echo "Stripping $$1"; strip -x "$$1" 2>/dev/null || true; xcrun strip -x "$$1" 2>/dev/null || true' _ {} \; || true
	@echo "[*] Checking for leaked strings..."
	@strings .theos/obj/debug/*.dylib 2>/dev/null | grep -i "poolhelper\|PoolHelper\|cheat\|ghost" && echo "WARNING: Found leaked strings!" || echo "No obvious cheat strings - GOOD"
	@echo "[*] Dylib ready for stealth rename to libUnityGraphics.dylib"
	@echo "[*] Features: Wizard (Best Shot, Bank, Cue Leave, Scratch, Combo) + Ninja + Ball-by-Ball Safety + Newest 56.29.x support"
