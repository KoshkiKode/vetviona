#!/bin/bash
echo "Building Vetviona for Linux and Windows"
echo "Note: Linux must be built on a Linux machine, and Windows on a Windows machine."

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Detected Linux. Building Linux target..."
  flutter build linux
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  echo "Detected Windows. Building Windows target..."
  flutter build windows
else
  echo "Current OS is $OSTYPE. To build for Linux, run this script on a Linux machine."
  echo "To build for Windows, run this script on a Windows machine."
  echo "Commands that will be run on respective OS:"
  echo "  - Linux: flutter build linux"
  echo "  - Windows: flutter build windows"
fi
