"""Generate the checked-in Xcode project without XcodeGen or third-party packages."""
from pathlib import Path
import hashlib
import json
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def uid(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()


def plist_text(value, depth=0):
    pad = "\t" * depth
    if isinstance(value, dict):
        return "{\n" + "".join(f"{pad}\t{json.dumps(str(k))} = {plist_text(v, depth + 1)};\n" for k, v in value.items()) + pad + "}"
    if isinstance(value, list):
        return "(\n" + "".join(f"{pad}\t{plist_text(v, depth + 1)},\n" for v in value) + pad + ")"
    return json.dumps(str(value))


def generate():
    config = ROOT / "Config"
    config.mkdir(exist_ok=True)
    base_info = {
        "CFBundleDevelopmentRegion": "en", "CFBundleDisplayName": "ParkCast",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)", "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0", "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1",
        "LSRequiresIPhoneOS": True, "UILaunchScreen": {},
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": True},
        "UIBackgroundModes": ["audio"],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
    }
    (config / "Info.plist").write_bytes(plistlib.dumps(base_info))
    car_info = dict(base_info)
    car_info["CFBundleDisplayName"] = "ParkCast Car"
    car_info["UIApplicationSceneManifest"] = {
        "UIApplicationSupportsMultipleScenes": True,
        "UISceneConfigurations": {"CPTemplateApplicationSceneSessionRoleApplication": [{
            "UISceneClassName": "CPTemplateApplicationScene", "UISceneConfigurationName": "CarPlay",
            "UISceneDelegateClassName": "$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate",
        }]},
    }
    (config / "CarPlay-Info.plist").write_bytes(plistlib.dumps(car_info))
    (config / "CarPlay.entitlements").write_bytes(plistlib.dumps({"com.apple.developer.carplay-video": True}))

    objects = {}

    def obj(label, isa, **fields):
        key = uid(label)
        objects[key] = dict(isa=isa, **fields)
        return key

    sources = sorted((ROOT / "ParkCast").glob("*.swift")) + sorted((ROOT / "Sources/ParkCastCore").glob("*.swift"))
    refs = [obj("file:" + str(f.relative_to(ROOT)), "PBXFileReference", lastKnownFileType="sourcecode.swift",
                path=f.relative_to(ROOT).as_posix(), sourceTree="SOURCE_ROOT") for f in sources]
    configs = [obj("file:" + f.name, "PBXFileReference", lastKnownFileType="text.plist.xml",
                   path=f.relative_to(ROOT).as_posix(), sourceTree="SOURCE_ROOT") for f in sorted(config.glob("*"))]
    products = []
    targets = []
    for name, carplay in [("ParkCast", False), ("ParkCastCarPlay", True)]:
        product = obj(name + ":product", "PBXFileReference", explicitFileType="wrapper.application",
                      includeInIndex=0, path=name + ".app", sourceTree="BUILT_PRODUCTS_DIR")
        products.append(product)
        builds = [obj(name + ":build:" + ref, "PBXBuildFile", fileRef=ref) for ref in refs]
        phases = [obj(name + ":sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0),
                  obj(name + ":frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0),
                  obj(name + ":resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)]
        build_configs = []
        for mode in ["Debug", "Release"]:
            settings = {
                "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_MODULE_NAME": "ParkCast",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.example.parkcast" + (".carplay" if carplay else ""),
                "INFOPLIST_FILE": "Config/CarPlay-Info.plist" if carplay else "Config/Info.plist",
                "GENERATE_INFOPLIST_FILE": "NO", "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "",
                "SDKROOT": "iphoneos", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
                "IPHONEOS_DEPLOYMENT_TARGET": "27.0" if carplay else "17.0",
                "TARGETED_DEVICE_FAMILY": "1,2", "SUPPORTS_MACCATALYST": "NO",
                "SWIFT_VERSION": "5.0", "SWIFT_STRICT_CONCURRENCY": "targeted",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited)" + (" DEBUG" if mode == "Debug" else "") + (" CARPLAY" if carplay else ""),
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                "ENABLE_TESTABILITY": "YES" if mode == "Debug" else "NO",
                "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym",
                "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            }
            if carplay:
                settings["CODE_SIGN_ENTITLEMENTS"] = "Config/CarPlay.entitlements"
            build_configs.append(obj(name + ":" + mode, "XCBuildConfiguration", name=mode, buildSettings=settings))
        config_list = obj(name + ":configurations", "XCConfigurationList", buildConfigurations=build_configs,
                          defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
        targets.append(obj(name + ":target", "PBXNativeTarget", name=name, productName=name,
                           productReference=product, productType="com.apple.product-type.application",
                           buildConfigurationList=config_list, buildPhases=phases, buildRules=[], dependencies=[]))
    product_group = obj("products", "PBXGroup", name="Products", children=products, sourceTree="<group>")
    main_group = obj("main", "PBXGroup", children=refs + configs + [product_group], sourceTree="<group>")
    project_configs = [obj("project:" + mode, "XCBuildConfiguration", name=mode,
                           buildSettings={"CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
                                          "SWIFT_VERSION": "5.0", "SDKROOT": "iphoneos"}) for mode in ["Debug", "Release"]]
    project_config_list = obj("project:configurations", "XCConfigurationList", buildConfigurations=project_configs,
                              defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    project = obj("project", "PBXProject", attributes={"BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1500"},
                  buildConfigurationList=project_config_list, compatibilityVersion="Xcode 14.0",
                  developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en", "Base"],
                  mainGroup=main_group, productRefGroup=product_group, projectDirPath="", projectRoot="", targets=targets)
    document = {"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}
    project_dir = ROOT / "ParkCast.xcodeproj"
    project_dir.mkdir(exist_ok=True)
    (project_dir / "project.pbxproj").write_text("// !$*UTF8*$!\n" + plist_text(document) + "\n", encoding="utf-8")
    scheme_dir = project_dir / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    for name in ["ParkCast", "ParkCastCarPlay"]:
        scheme = ET.Element("Scheme", LastUpgradeVersion="1500", version="1.3")
        build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
        entries = ET.SubElement(build, "BuildActionEntries")
        entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
        reference = {"BuildableIdentifier": "primary", "BlueprintIdentifier": uid(name + ":target"),
                     "BuildableName": name + ".app", "BlueprintName": name, "ReferencedContainer": "container:ParkCast.xcodeproj"}
        ET.SubElement(entry, "BuildableReference", **reference)
        ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
        launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
        run = ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0")
        ET.SubElement(run, "BuildableReference", **reference)
        profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
        ET.SubElement(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), "BuildableReference", **reference)
        ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
        ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
        ET.indent(scheme, space="  ")
        ET.ElementTree(scheme).write(scheme_dir / (name + ".xcscheme"), encoding="utf-8", xml_declaration=True)
    print(f"Generated {len(sources)} source references and 2 shared Xcode schemes.")
    return document


if __name__ == "__main__":
    generate()
