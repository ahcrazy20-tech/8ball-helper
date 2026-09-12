THEOS_DEVICE_IP = 127.0.0.1
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

# Stealth build flags
# -O2 optimization, strip symbols, hide symbols, no debug info
# -fvisibility=hidden hides symbols
# -fno-exceptions reduces binary size and detectable patterns

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UnityGraphics

# Use innocent name for stealth - looks like Unity graphics plugin
# Final dylib will be renamed to libUnityGraphics.dylib

UnityGraphics_FILES = Tweak.x OverlayWindow.m PoolPredictor.mm Stealth.mm
UnityGraphics_FRAMEWORKS = UIKit Foundation QuartzCore Vision CoreGraphics
UnityGraphics_PRIVATE_FRAMEWORKS = CoreGraphics
UnityGraphics_CFLAGS = -fobjc-arc -std=c++17 -O2 -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG -Wno-deprecated-declarations -Qunused-arguments
UnityGraphics_CCFLAGS = -O2 -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG -std=c++17
UnityGraphics_LDFLAGS = -lstdc++ -Wl,-x -Wl,-S -Wl,-dead_strip

# Strip all symbols in final package
# This makes reverse engineering harder and hides our function names
export ADDITIONAL_LDFLAGS = -Wl,-x -Wl,-S

# For safety, disable debug logs in final
UnityGraphics_CFLAGS += -DSTEALTH_RELEASE=1 -DENABLE_LOGS=0

include $(THEOS_MAKE_PATH)/tweak.mk

# Post-build stealth steps
after-package::
	@echo "[*] Applying stealth post-processing..."
	@find .theos/obj -name "*.dylib" -exec sh -c 'echo "Stripping $$1"; strip -x "$$1" 2>/dev/null || true; xcrun strip -x "$$1" 2>/dev/null || true' _ {} \; || true
	@echo "[*] Checking for leaked strings..."
	@strings .theos/obj/debug/*.dylib 2>/dev/null | grep -i "poolhelper\|PoolHelper\|cheat\|ghost" && echo "WARNING: Found leaked strings!" || echo "No obvious cheat strings - GOOD"
	@echo "[*] Dylib ready for stealth rename to libUnityGraphics.dylib"

# For building standalone dylib for TrollFools injection
# Output will be at .theos/obj/debug/libUnityGraphics.dylib (or libPoolHelper if old name)
# Rename to innocuous name for injection

# For jailed IPA injection, build dylib only:
# make clean && make FINALPACKAGE=1
# dylib will be at .theos/obj/debug/libUnityGraphics.dylib
