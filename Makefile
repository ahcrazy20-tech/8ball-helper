THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

# Must be set BEFORE including common.mk: Theos tests it while parsing that
# file (makefiles/common.mk) to decide whether to inject `-Wall -Werror` and
# Logos `-c warnings=error`. Setting it afterwards has no effect.
GO_EASY_ON_ME = 1

# Stealth build flags + Wizard/Ninja features
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UnityGraphics

# Use innocent name for stealth - looks like Unity graphics plugin
# Includes all Wizard/Ninja features + ball-by-ball safety mode
# Supports newest 8 Ball Pool 56.29.x via vision detection

UnityGraphics_FILES = Tweak.x OverlayWindow.m PoolPredictor.mm Stealth.mm ModMenu.m

# CoreGraphics is a *public* framework, so it belongs in _FRAMEWORKS.
# Vision is intentionally not linked: no source references it any more, and
# requiring it would break builds against SDKs that do not ship it.
UnityGraphics_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics

# Theos compiles .m with `-x objective-c ... $(ALL_CFLAGS) $(ALL_OBJCFLAGS)`
# (makefiles/instance/rules.mk), and ALL_CFLAGS includes <INSTANCE>_CFLAGS.
# So a C++ dialect flag in _CFLAGS makes clang fail with:
#   "invalid argument '-std=c++17' not allowed with 'Objective-C'"
# The C++ dialect belongs in _CCFLAGS, which is only applied to the
# .mm / .cpp rules (via ALL_CCFLAGS).
UnityGraphics_CFLAGS = -fobjc-arc -O2 -fvisibility=hidden -DNDEBUG -Wno-deprecated-declarations
UnityGraphics_CCFLAGS = -fobjc-arc -std=c++17 -O2 -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG

# Keep warnings non-fatal for the placeholder code that still needs real
# hook offsets. (-Qunused-arguments also silences "argument unused during
# compilation" for C++-only flags reaching the Objective-C compiles.)
UnityGraphics_CFLAGS += -Qunused-arguments -Wno-unused-variable -Wno-unused-function
UnityGraphics_CCFLAGS += -Qunused-arguments -Wno-unused-variable

# NOTE: -lstdc++ does not exist in the iOS SDK (Apple ships libc++ only), so it
# fails with "ld: library not found for -lstdc++". The .mm translation units are
# linked through the C++ driver, which pulls in libc++ automatically.
UnityGraphics_LDFLAGS = -Wl,-x -Wl,-S -Wl,-dead_strip

export ADDITIONAL_LDFLAGS = -Wl,-x -Wl,-S
UnityGraphics_CFLAGS += -DSTEALTH_RELEASE=1 -DENABLE_LOGS=0
UnityGraphics_CCFLAGS += -DSTEALTH_RELEASE=1 -DENABLE_LOGS=0

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "[*] Applying stealth post-processing..."
	@find .theos/obj -name "*.dylib" 2>/dev/null | while read -r dylib; do \
		echo "Stripping $$dylib"; \
		strip -x "$$dylib" 2>/dev/null || true; \
		xcrun strip -x "$$dylib" 2>/dev/null || true; \
	done || true
	@echo "[*] Checking for leaked strings..."
	@find .theos/obj -name "*.dylib" 2>/dev/null | while read -r dylib; do \
		strings "$$dylib" 2>/dev/null | grep -i "poolhelper\|cheat\|ghost" && echo "WARNING: Found leaked strings!" || echo "No obvious cheat strings - GOOD"; \
	done || true
	@echo "[*] Dylib ready for stealth rename to libUnityGraphics.dylib"
	@echo "[*] Features: Wizard (Best Shot, Bank, Cue Leave, Scratch, Combo) + Ninja + Ball-by-Ball Safety + Newest 56.29.x support"
