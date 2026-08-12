#!/usr/bin/env python3
"""Generate a minimal but valid Xcode project for ThunderFighter.

The app is a pure-SwiftUI + SpriteKit iOS game with no third-party
dependencies, so a hand-built .pbxproj is enough: one application target
with all .swift sources, the 13 PNGs copied into the bundle, and a unit-test
target (ThunderFighterTests) that runs against the app as its test host.

Run:  python3 generate_project.py
Then:  open ThunderFighter.xcodeproj   (Xcode: pick a device/Sim, Cmd+U)
Or:    xcodebuild test -project ThunderFighter.xcodeproj \
                     -scheme ThunderFighter \
                     -destination 'platform=iOS Simulator,id=<booted-sim>'
"""
import os
import random

ROOT = os.path.dirname(os.path.abspath(__file__))
APP_NAME = "ThunderFighter"
TEST_NAME = "ThunderFighterTests"


def gid():
    return "".join(random.choice("0123456789ABCDEF") for _ in range(24))


def q(s):
    return '"%s"' % s


# Collect sources. App sources are everything except the Resources folder and
# the Tests folder; the Tests folder holds the unit tests (compiled only into
# the test target, never the app).
swift_files = []          # app sources
test_swift_files = []     # unit-test sources
for dp, dn, fn in os.walk(ROOT):
    base = os.path.basename(dp)
    if base == "Resources" or base == "Tests":
        continue
    for f in fn:
        if not f.endswith(".swift"):
            continue
        rel = os.path.relpath(os.path.join(dp, f), ROOT)
        # os.walk still recurses into subdirs of Tests even when we skip the
        # top-level Tests dir above, so filter by path prefix as well.
        if rel.startswith("Tests"):
            continue
        swift_files.append(rel)
swift_files.sort()

for dp, dn, fn in os.walk(os.path.join(ROOT, "Tests")):
    for f in fn:
        if f.endswith(".swift"):
            rel = os.path.relpath(os.path.join(dp, f), ROOT)
            test_swift_files.append(rel)
test_swift_files.sort()

png_files = sorted(
    f for f in os.listdir(os.path.join(ROOT, "Resources")) if f.endswith(".png")
)

# IDs
main_group = gid()
products_group = gid()
proj = gid()
target = gid()
app_product = gid()
sources_phase = gid()
resources_phase = gid()
frameworks_phase = gid()
proj_config_list = gid()
tgt_config_list = gid()
proj_debug = gid()
proj_release = gid()
tgt_debug = gid()
tgt_release = gid()

# Test-target IDs
test_target = gid()
test_product = gid()
test_sources_phase = gid()
test_frameworks_phase = gid()
test_config_list = gid()
test_debug = gid()
test_release = gid()
test_app_proxy = gid()
test_app_dependency = gid()
xctest_ref = gid()
xctest_bf = gid()

fileref = {}
buildfile = {}
for rel in swift_files:
    fileref[rel] = gid()
    buildfile[rel] = gid()

pngref = {}
pngbf = {}
for p in png_files:
    pngref[p] = gid()
    pngbf[p] = gid()

test_fileref = {}
test_buildfile = {}
for rel in test_swift_files:
    test_fileref[rel] = gid()
    test_buildfile[rel] = gid()

L = []
a = L.append


def obj(uid, body):
    a("\t\t%s = {" % uid)
    for line in body:
        a("\t\t\t" + line)
    a("\t\t};")


# ---- header
a("// !$*UTF8*$!")
a("{")
a("\tarchiveVersion = 1;")
a("\tclasses = {")
a("\t};")
a("\tobjectVersion = 56;")
a("\tobjects = {")

# ---- file references (app)
for rel in swift_files:
    obj(fileref[rel], [
        "isa = PBXFileReference;",
        "lastKnownFileType = sourcecode.swift;",
        "path = %s;" % q(rel),
        "sourceTree = \"<group>\";",
    ])
for p in png_files:
    obj(pngref[p], [
        "isa = PBXFileReference;",
        "lastKnownFileType = image.png;",
        "path = %s;" % q("Resources/" + p),
        "sourceTree = \"<group>\";",
    ])

# ---- file references (test)
for rel in test_swift_files:
    obj(test_fileref[rel], [
        "isa = PBXFileReference;",
        "lastKnownFileType = sourcecode.swift;",
        "path = %s;" % q(rel),
        "sourceTree = \"<group>\";",
    ])

# ---- product references
obj(app_product, [
    "isa = PBXFileReference;",
    "explicitFileType = wrapper.application;",
    "path = %s.app;" % APP_NAME,
    "sourceTree = BUILT_PRODUCTS_DIR;",
])
obj(test_product, [
    "isa = PBXFileReference;",
    "explicitFileType = wrapper.cfbundle;",
    "path = %s.xctest;" % TEST_NAME,
    "sourceTree = BUILT_PRODUCTS_DIR;",
])

# ---- build files
for rel in swift_files:
    obj(buildfile[rel], [
        "isa = PBXBuildFile;",
        "fileRef = %s;" % fileref[rel],
    ])
for p in png_files:
    obj(pngbf[p], [
        "isa = PBXBuildFile;",
        "fileRef = %s;" % pngref[p],
    ])
for rel in test_swift_files:
    obj(test_buildfile[rel], [
        "isa = PBXBuildFile;",
        "fileRef = %s;" % test_fileref[rel],
    ])

# XCTest is linked explicitly into the test bundle (Xcode normally injects it
# for unit-test targets, but a hand-built pbxproj has to name it).
obj(xctest_ref, [
    "isa = PBXFileReference;",
    "lastKnownFileType = wrapper.framework;",
    "name = XCTest.framework;",
    "path = Developer/Library/Frameworks/XCTest.framework;",
    "sourceTree = SDKROOT;",
])
obj(xctest_bf, [
    "isa = PBXBuildFile;",
    "fileRef = %s;" % xctest_ref,
])

# ---- groups
main_children = (
    [fileref[r] for r in swift_files]
    + [test_fileref[r] for r in test_swift_files]
    + [pngref[p] for p in png_files]
    + [products_group]
)
obj(main_group, [
    "isa = PBXGroup;",
    "children = (%s);" % ", ".join(main_children),
    "sourceTree = \"<group>\";",
])
obj(products_group, [
    "isa = PBXGroup;",
    "children = (%s, %s);" % (app_product, test_product),
    "name = Products;",
    "sourceTree = \"<group>\";",
])

# ---- build phases
obj(sources_phase, [
    "isa = PBXSourcesBuildPhase;",
    "buildActionMask = 2147483647;",
    "files = (%s);" % ", ".join(buildfile[r] for r in swift_files),
    "runOnlyForDeploymentPostprocessing = 0;",
])
obj(resources_phase, [
    "isa = PBXResourcesBuildPhase;",
    "buildActionMask = 2147483647;",
    "files = (%s);" % ", ".join(pngbf[p] for p in png_files),
    "runOnlyForDeploymentPostprocessing = 0;",
])
obj(frameworks_phase, [
    "isa = PBXFrameworksBuildPhase;",
    "buildActionMask = 2147483647;",
    "files = ();",
    "runOnlyForDeploymentPostprocessing = 0;",
])
obj(test_sources_phase, [
    "isa = PBXSourcesBuildPhase;",
    "buildActionMask = 2147483647;",
    "files = (%s);" % ", ".join(test_buildfile[r] for r in test_swift_files),
    "runOnlyForDeploymentPostprocessing = 0;",
])
obj(test_frameworks_phase, [
    "isa = PBXFrameworksBuildPhase;",
    "buildActionMask = 2147483647;",
    "files = (%s);" % xctest_bf,
    "runOnlyForDeploymentPostprocessing = 0;",
])

# ---- native targets
obj(target, [
    "isa = PBXNativeTarget;",
    "buildConfigurationList = %s;" % tgt_config_list,
    "buildPhases = (%s, %s, %s);" % (sources_phase, resources_phase, frameworks_phase),
    "buildRules = ();",
    "dependencies = ();",
    "name = %s;" % APP_NAME,
    "productName = %s;" % APP_NAME,
    "productReference = %s;" % app_product,
    "productType = \"com.apple.product-type.application\";",
])

# Test target depends on the app as its test host.
obj(test_app_proxy, [
    "isa = PBXContainerItemProxy;",
    "containerPortal = %s;" % proj,
    "proxyType = 1;",
    "remoteGlobalIDString = %s;" % target,
    "remoteInfo = \"%s\";" % APP_NAME,
])
obj(test_app_dependency, [
    "isa = PBXTargetDependency;",
    "target = %s;" % target,
    "targetProxy = %s;" % test_app_proxy,
])
obj(test_target, [
    "isa = PBXNativeTarget;",
    "buildConfigurationList = %s;" % test_config_list,
    "buildPhases = (%s, %s);" % (test_sources_phase, test_frameworks_phase),
    "buildRules = ();",
    "dependencies = (%s);" % test_app_dependency,
    "name = %s;" % TEST_NAME,
    "productName = %s;" % TEST_NAME,
    "productReference = %s;" % test_product,
    "productType = \"com.apple.product-type.bundle.unit-test\";",
])

# ---- project
obj(proj, [
    "isa = PBXProject;",
    "attributes = {",
    "\t\t\t\tLastSwiftUpdateCheck = 2600;",
    "\t\t\t\tLastUpgradeCheck = 2600;",
    "\t\t\t\tTargetAttributes = {",
    "\t\t\t\t\t%s = {" % target,
    "\t\t\t\t\t\tCreatedOnToolsVersion = \"26.6\";",
    "\t\t\t\t\t};",
    "\t\t\t\t\t%s = {" % test_target,
    "\t\t\t\t\t\tCreatedOnToolsVersion = \"26.6\";",
    "\t\t\t\t\t\tTestTargetID = %s;" % target,
    "\t\t\t\t\t};",
    "\t\t\t\t};",
    "\t\t\t};",
    "buildConfigurationList = %s;" % proj_config_list,
    "compatibilityVersion = \"Xcode 15.0\";",
    "developmentRegion = en;",
    "hasScannedForEncodings = 0;",
    "knownRegions = (en, Base);",
    "mainGroup = %s;" % main_group,
    "productRefGroup = %s;" % products_group,
    "projectDirPath = \"\";",
    "projectRoot = \"\";",
    "targets = (%s, %s);" % (target, test_target),
])

# ---- build configurations
COMMON_TARGET = [
    "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = YES;",
    "CODE_SIGN_STYLE = Automatic;",
    "CURRENT_PROJECT_VERSION = 1;",
    "ENABLE_BITCODE = NO;",
    "GENERATE_INFOPLIST_FILE = YES;",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
    "LD_RUNPATH_SEARCH_PATHS = \"@executable_path/Frameworks\";",
    "MARKETING_VERSION = 1.0;",
    "PRODUCT_BUNDLE_IDENTIFIER = com.example.thunderfighter;",
    "PRODUCT_NAME = \"$(TARGET_NAME)\";",
    "SWIFT_EMIT_LOC_STRINGS = YES;",
    "SWIFT_VERSION = 5.0;",
    "TARGETED_DEVICE_FAMILY = \"1,2\";",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    "SDKROOT = iphoneos;",
]

proj_debug_bs = [
    "CLANG_ANALYZER_NONNULL = YES;",
    "CLANG_ENABLE_MODULES = YES;",
    "CLANG_ENABLE_OBJC_ARC = YES;",
    "COPY_PHASE_STRIP = NO;",
    "DEBUG_INFORMATION_FORMAT = dwarf;",
    "ENABLE_STRICT_OBJC_MSGSEND = YES;",
    "ENABLE_TESTABILITY = YES;",
    "GCC_DYNAMIC_NO_PIC = NO;",
    "GCC_OPTIMIZATION_LEVEL = 0;",
    "GCC_PREPROCESSOR_DEFINITIONS = (\"DEBUG=1\", \"$(inherited)\");",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
    "MTL_FAST_MATH = YES;",
    "ONLY_ACTIVE_ARCH = YES;",
    "SDKROOT = iphoneos;",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;",
    "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
]
proj_release_bs = [
    "CLANG_ANALYZER_NONNULL = YES;",
    "CLANG_ENABLE_MODULES = YES;",
    "CLANG_ENABLE_OBJC_ARC = YES;",
    "COPY_PHASE_STRIP = NO;",
    "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
    "ENABLE_NS_ASSERTIONS = NO;",
    "ENABLE_STRICT_OBJC_MSGSEND = YES;",
    "GCC_OPTIMIZATION_LEVEL = s;",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    "MTL_ENABLE_DEBUG_INFO = NO;",
    "MTL_FAST_MATH = YES;",
    "SDKROOT = iphoneos;",
    "SWIFT_COMPILATION_MODE = wholemodule;",
    "SWIFT_OPTIMIZATION_LEVEL = \"-O\";",
    "VALIDATE_PRODUCT = YES;",
]
tgt_debug_bs = COMMON_TARGET + [
    "DEBUG_INFORMATION_FORMAT = dwarf;",
    "ENABLE_TESTABILITY = YES;",
    "GCC_DYNAMIC_NO_PIC = NO;",
    "GCC_OPTIMIZATION_LEVEL = 0;",
    "GCC_PREPROCESSOR_DEFINITIONS = (\"DEBUG=1\", \"$(inherited)\");",
    "ONLY_ACTIVE_ARCH = YES;",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;",
    "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
]
tgt_release_bs = COMMON_TARGET + [
    "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
    "ENABLE_NS_ASSERTIONS = NO;",
    "ENABLE_TESTABILITY = YES;",
    "GCC_OPTIMIZATION_LEVEL = s;",
    "SWIFT_COMPILATION_MODE = wholemodule;",
    "SWIFT_OPTIMIZATION_LEVEL = \"-O\";",
    "VALIDATE_PRODUCT = YES;",
]

# Test target settings: it is a unit-test bundle hosted by the app.
COMMON_TEST = [
    "CODE_SIGN_STYLE = Automatic;",
    "CURRENT_PROJECT_VERSION = 1;",
    "GENERATE_INFOPLIST_FILE = YES;",
    "PRODUCT_BUNDLE_IDENTIFIER = com.example.thunderfighter.tests;",
    "PRODUCT_NAME = \"$(TARGET_NAME)\";",
    "SWIFT_EMIT_LOC_STRINGS = NO;",
    "SWIFT_VERSION = 5.0;",
    "TARGETED_DEVICE_FAMILY = \"1,2\";",
    "IPHONEOS_DEPLOYMENT_TARGET = 17.0;",
    "SDKROOT = iphoneos;",
    "TEST_HOST = \"$(BUILT_PRODUCTS_DIR)/%s.app/%s\";" % (APP_NAME, APP_NAME),
    "BUNDLE_LOADER = \"$(TEST_HOST)\";",
    "ENABLE_TESTABILITY = YES;",
    "LD_RUNPATH_SEARCH_PATHS = \"@executable_path/Frameworks @loader_path/Frameworks\";",
]
test_debug_bs = COMMON_TEST + [
    "DEBUG_INFORMATION_FORMAT = dwarf;",
    "GCC_OPTIMIZATION_LEVEL = 0;",
    "ONLY_ACTIVE_ARCH = YES;",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;",
    "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
]
test_release_bs = COMMON_TEST + [
    "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
    "SWIFT_OPTIMIZATION_LEVEL = \"-O\";",
]


def xcconfig(uid, name, bs):
    obj(uid, [
        "isa = XCBuildConfiguration;",
        "buildSettings = {",
    ] + ["\t\t\t\t" + l for l in bs] + [
        "\t\t\t};",
        "name = %s;" % q(name),
    ])


xcconfig(proj_debug, "Debug", proj_debug_bs)
xcconfig(proj_release, "Release", proj_release_bs)
xcconfig(tgt_debug, "Debug", tgt_debug_bs)
xcconfig(tgt_release, "Release", tgt_release_bs)
xcconfig(test_debug, "Debug", test_debug_bs)
xcconfig(test_release, "Release", test_release_bs)

obj(proj_config_list, [
    "isa = XCConfigurationList;",
    "buildConfigurations = (%s, %s);" % (proj_debug, proj_release),
    "defaultConfigurationName = Release;",
])
obj(tgt_config_list, [
    "isa = XCConfigurationList;",
    "buildConfigurations = (%s, %s);" % (tgt_debug, tgt_release),
    "defaultConfigurationName = Release;",
])
obj(test_config_list, [
    "isa = XCConfigurationList;",
    "buildConfigurations = (%s, %s);" % (test_debug, test_release),
    "defaultConfigurationName = Release;",
])

# ---- footer
a("\t};")
a("\trootObject = %s;" % proj)
a("}")

pbx = "\n".join(L) + "\n"
out = os.path.join(ROOT, "%s.xcodeproj" % APP_NAME, "project.pbxproj")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as f:
    f.write(pbx)
print("wrote", out)

# ---- shared scheme (so Cmd+U and `xcodebuild test` both pick up the tests)
scheme_dir = os.path.join(ROOT, "%s.xcodeproj" % APP_NAME,
                          "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
scheme_path = os.path.join(scheme_dir, "%s.xcscheme" % APP_NAME)
container = "container:%s.xcodeproj" % APP_NAME
scheme_xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{APP_NAME}.app" BlueprintName="{APP_NAME}" ReferencedContainer="{container}">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="{TEST_NAME}.xctest" BlueprintName="{TEST_NAME}" ReferencedContainer="{container}">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" codeCoverageEnabled="NO">
      <Testables>
         <TestableReference skipped="NO">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="{TEST_NAME}.xctest" BlueprintName="{TEST_NAME}" ReferencedContainer="{container}">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{APP_NAME}.app" BlueprintName="{APP_NAME}" ReferencedContainer="{container}">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{APP_NAME}.app" BlueprintName="{APP_NAME}" ReferencedContainer="{container}">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
'''
with open(scheme_path, "w") as f:
    f.write(scheme_xml)
print("wrote", scheme_path)

print("app swift sources:", len(swift_files),
      "| test swift sources:", len(test_swift_files),
      "| png resources:", len(png_files))
