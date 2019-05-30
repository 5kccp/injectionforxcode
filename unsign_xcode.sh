#!/usr/bin/env bash
set -euo pipefail
set +e
xcrun xcodebuild -version > /dev/null 2>/dev/null
RESULT="$?"
set -e
if [ $RESULT != 0 ]; then
  sudo xcode-select --reset
fi

PLUGINS_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins"
echo "插件位置:${PLUGINS_DIR}"
APP="/Applications/Xcode.app"
CERT_PASS="xcodesigner"

running=$(pgrep Xcode || true)
if [ "$running" != "" ]; then
  echo "先退出xcode再执行脚本"
  exit 1
fi


if [ ! -f "$APP/Contents/Info.plist" ]; then
  echo "$APP下面没有发现xcode"
  exit 1
fi

echo "添加xcode的UUID到插件"
DVTUUIDS=$(defaults read $APP/Contents/Info.plist DVTPlugInCompatibilityUUID)
find ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins -name Info.plist -maxdepth 3 | xargs -I{} defaults write {} DVTPlugInCompatibilityUUIDs -array-add $DVTUUIDS

# Install a self-signing cert to enable plugins in Xcode 8
delPem=false
if [ ! -f XcodeSigner2018.pem ]; then
  echo "下载public key..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner2018.pem -o XcodeSigner2018.pem
  delPem=true
fi
delP12=false
if [ ! -f XcodeSigner2018.p12 ]; then
  echo "下载private key..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner2018.p12 -o XcodeSigner2018.p12
  delP12=true
fi
delCert=false
if [ ! -f XcodeSigner2018.cert ]; then
  echo "下载self-signed cert..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner2018.cert -o XcodeSigner2018.cert
  delCert=true
fi

KEYCHAIN=$(tr -d "\"" <<< `security default-keychain`)
echo "$KEYCHAIN"
echo "导入自签名证书到默认keychain, 弹窗时候请选择允许"
security import ./XcodeSigner2018.cert -k ${KEYCHAIN} || true
echo "导入自签名公钥到默认keychain, 弹窗时候请选择允许"
security import ./XcodeSigner2018.pem -k ${KEYCHAIN} || true
echo "导入自签名私钥到默认keychain, 弹窗时候请选择允许"
security import ./XcodeSigner2018.p12 -k $KEYCHAIN -P $CERT_PASS || true
echo "重签名 $APP, 这需要多几分钟，耐心等待"
sudo codesign -f -s XcodeSigner2018 $APP
echo "删除钥匙和证书"
if [ "$delPem" = true ]; then
  rm XcodeSigner2018.pem
fi
if [ "$delP12" = true ]; then
  rm XcodeSigner2018.p12
fi
if [ "$delCert" = true ]; then
  rm XcodeSigner2018.cert
fi
echo "成功重前面和设置uuids到插件. 启动 Xcode..."
open "$APP"