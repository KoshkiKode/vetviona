#!/bin/bash
echo "Starting iOS build..."
../tools/build_ios.sh
echo "Starting Android build..."
../tools/build_android.sh
echo "Mobile builds completed."
