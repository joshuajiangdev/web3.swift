#!/bin/bash
​
# secp256k1 uses @_exported import libsecp256k1 which means it ends up in the generated
# swiftinterface but cannot be found by clients. This generates an empty modulemap to resolve
# the Swift missing import error in clients.
libsecp256k1_modulemap="
module libsecp256k1 {
    export *
}
"
​
keccaktiny_modulemap="
module keccaktiny {
    export *
}
"
​
# Setup cleanup
git checkout
rm -fr out
mkdir out
​
# Generates xcodeproj and changes TARGET_NAME for BigInt -> BigInt_Swift due to known swift interface issue:
# https://bugs.swift.org/browse/SR-898
swift package generate-xcodeproj
sed -i '' 's/TARGET_NAME = "BigInt"/TARGET_NAME = "BigInt_Swift"/g' web3.swift.xcodeproj/project.pbxproj
# Because we're changing the target name we need to only change the import statements used to compile.
git grep --name-only "import BigInt$" | tr "\n" "\0" | xargs -0 sed -i '' -e 's/import BigInt/import BigInt_Swift/g'
​
# Archive steps
xcodebuild archive -scheme web3.swift-Package -sdk iphoneos BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO IPHONEOS_DEPLOYMENT_TARGET=11.0 -archivePath web3.swift-iphoneos.xcarchive
xcodebuild archive -scheme web3.swift-Package -sdk iphonesimulator BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO IPHONEOS_DEPLOYMENT_TARGET=11.0 -archivePath web3.swift-iphonesimulator.xcarchive
​
# Copy modulemap from above into Modules/ dir.
mkdir web3.swift-iphonesimulator.xcarchive/Products/Library/Frameworks/libsecp256k1.framework/Modules
mkdir web3.swift-iphoneos.xcarchive/Products/Library/Frameworks/libsecp256k1.framework/Modules
mkdir web3.swift-iphonesimulator.xcarchive/Products/Library/Frameworks/keccaktiny.framework/Modules
mkdir web3.swift-iphoneos.xcarchive/Products/Library/Frameworks/keccaktiny.framework/Modules
echo "$libsecp256k1_modulemap" > web3.swift-iphoneos.xcarchive/Products/Library/Frameworks/libsecp256k1.framework/Modules/module.modulemap
echo "$libsecp256k1_modulemap" > web3.swift-iphonesimulator.xcarchive/Products/Library/Frameworks/libsecp256k1.framework/Modules/module.modulemap
echo "$keccaktiny_modulemap" > web3.swift-iphoneos.xcarchive/Products/Library/Frameworks/keccaktiny.framework/Modules/module.modulemap
echo "$keccaktiny_modulemap" > web3.swift-iphonesimulator.xcarchive/Products/Library/Frameworks/keccaktiny.framework/Modules/module.modulemap
​
# Generate xcframeworks.
frameworks=$(find web3.swift-iphonesimulator.xcarchive -name "*.framework" -exec basename {} \;)
for f in $frameworks; do
    xcframework_name="$(echo $f | sed s/framework/xcframework/g)"
    xcodebuild -create-xcframework -framework web3.swift-iphonesimulator.xcarchive/Products/Library/Frameworks/$f -framework web3.swift-iphoneos.xcarchive/Products/Library/Frameworks/$f -output out/$xcframework_name
done
​
# cleanup
git checkout .