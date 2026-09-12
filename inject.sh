#!/bin/bash
# inject.sh - Inject stealth dylib into IPA for Sideloadly / ESign / TrollStore
# Usage: ./inject.sh 8BallPool.ipa libUnityGraphics.dylib
# Stealth version: renames dylib to innocent name, strips, checks

IPA=$1
DYLIB=$2

if [ -z "$IPA" ] || [ -z "$DYLIB" ]; then
  echo "Usage: ./inject.sh <path_to_8ballpool.ipa> <path_to_dylib>"
  echo "Example: ./inject.sh 8BallPool.ipa artifact/libUnityGraphics.dylib"
  echo ""
  echo "Stealth tip: Use innocent name like libUnityGraphics.dylib"
  exit 1
fi

# Check files
if [ ! -f "$IPA" ]; then
  echo "[!] IPA not found: $IPA"
  exit 1
fi
if [ ! -f "$DYLIB" ]; then
  echo "[!] Dylib not found: $DYLIB"
  exit 1
fi

# Stealth rename - ensure innocent name
BASENAME=$(basename "$DYLIB")
if [[ "$BASENAME" == *"PoolHelper"* ]] || [[ "$BASENAME" == *"cheat"* ]] || [[ "$BASENAME" == *"hack"* ]]; then
  echo "[!] WARNING: Dylib name $BASENAME is obvious and detectable!"
  echo "[*] Renaming to libUnityGraphics.dylib for stealth..."
  cp "$DYLIB" /tmp/libUnityGraphics.dylib
  DYLIB="/tmp/libUnityGraphics.dylib"
  BASENAME="libUnityGraphics.dylib"
fi

echo "[*] Unzipping IPA..."
rm -rf Payload
unzip -q "$IPA"

APP=$(ls -d Payload/*.app 2>/dev/null | head -1)
if [ -z "$APP" ]; then
  echo "[!] No .app found in IPA"
  exit 1
fi
echo "[*] Found app: $APP"

echo "[*] Checking dylib for leaked strings (stealth check)..."
if strings "$DYLIB" | grep -qi "poolhelper\|cheat\|hack\|ghost.*helper"; then
  echo "[!] WARNING: Dylib contains obvious cheat strings!"
  echo "    Consider rebuilding with stealth flags"
else
  echo "[+] No obvious cheat strings - GOOD"
fi

echo "[*] Stripping dylib for stealth..."
strip -x "$DYLIB" 2>/dev/null || xcrun strip -x "$DYLIB" 2>/dev/null || echo "[!] Strip failed, continuing"

echo "[*] Copying dylib to $APP/"
cp "$DYLIB" "$APP/$BASENAME"

# Use optool or insert_dylib to inject
if command -v optool &> /dev/null; then
  echo "[*] Using optool to inject..."
  optool install -c load -p "@executable_path/$BASENAME" -t "$APP/$(basename $APP .app)" 
elif command -v insert_dylib &> /dev/null; then
  echo "[*] Using insert_dylib..."
  insert_dylib --inplace --all-yes "@executable_path/$BASENAME" "$APP/$(basename $APP .app)"
else
  echo "[!] optool/insert_dylib not found"
  echo "[*] Trying to install optool..."
  if command -v brew &> /dev/null; then
    brew install optool 2>/dev/null && optool install -c load -p "@executable_path/$BASENAME" -t "$APP/$(basename $APP .app)" || {
      echo "[!] Please install manually: brew install optool"
      echo "[!] Or use Azula app on iPhone to inject without Mac"
      exit 1
    }
  else
    echo "[!] Please install optool: brew install optool"
    echo "[!] Or use Azula app on iPhone"
    exit 1
  fi
fi

echo "[*] Verifying injection..."
if otool -L "$APP/$(basename $APP .app)" | grep -q "$BASENAME"; then
  echo "[+] Injection verified!"
else
  echo "[!] Injection may have failed, check manually"
fi

echo "[*] Repackaging IPA..."
zip -qr "8BallPool-Patched-Stealth.ipa" Payload

echo ""
echo "[+] Done! Patched IPA: 8BallPool-Patched-Stealth.ipa"
echo "[*] Dylib injected as: $BASENAME (stealth name)"
echo ""
echo "Next steps:"
echo "1. Sideload with Sideloadly: Drag IPA to Sideloadly -> Apple ID -> Start"
echo "2. Or with ESign / TrollStore"
echo "3. Trust in Settings -> General -> VPN & Device Management"
echo ""
echo "Stealth tips:"
echo "- Only use in Play With Friends"
echo "- Panic gesture: 3-finger double tap to hide"
echo "- Tiny dot at top-left to toggle"

# Cleanup
rm -rf Payload
rm -f /tmp/libUnityGraphics.dylib
