#!/bin/bash
# inject.sh - Inject dylib into IPA for Sideloadly / ESign / TrollStore
# Usage: ./inject.sh 8BallPool.ipa libPoolHelper.dylib

IPA=$1
DYLIB=$2

if [ -z "$IPA" ] || [ -z "$DYLIB" ]; then
  echo "Usage: ./inject.sh <path_to_8ballpool.ipa> <path_to_libPoolHelper.dylib>"
  echo "Example: ./inject.sh 8BallPool.ipa .theos/obj/debug/libPoolHelper.dylib"
  exit 1
fi

echo "[*] Unzipping IPA..."
rm -rf Payload
unzip -q "$IPA"

APP=$(ls Payload/*.app)
echo "[*] Found app: $APP"

echo "[*] Copying dylib to $APP/"
cp "$DYLIB" "$APP/"

# Use optool or insert_dylib to inject
if command -v optool &> /dev/null; then
  echo "[*] Using optool to inject..."
  optool install -c load -p "@executable_path/$(basename $DYLIB)" -t "$APP/$(basename $APP .app)" 
else
  echo "[!] optool not found, trying insert_dylib..."
  if command -v insert_dylib &> /dev/null; then
    insert_dylib --inplace --all-yes "@executable_path/$(basename $DYLIB)" "$APP/$(basename $APP .app)"
  else
    echo "[!] Please install optool: brew install optool"
    echo "[!] Or use Azula app on iPhone to inject dylib without Mac"
    exit 1
  fi
fi

echo "[*] Repackaging IPA..."
zip -qr "8BallPool-Patched.ipa" Payload

echo "[+] Done! Patched IPA: 8BallPool-Patched.ipa"
echo "[*] Now sideload with Sideloadly or ESign"
echo "[*] Or use TrollFools: No need to repack, just inject directly on device"

# Cleanup
rm -rf Payload
