#!/bin/bash
echo "Starting macOS build..."
./tools/build_macos.sh
echo "Starting iOS build..."
./tools/build_ios.sh
echo "Starting Android build..."
./tools/build_android.sh
echo "All builds completed."
