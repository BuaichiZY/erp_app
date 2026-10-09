#!/usr/bin/env python3
"""Run the geometry regression tests on macOS without launching the app."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
build = root.parent / "build/ios/layout-check"
build.mkdir(parents=True, exist_ok=True)
developer = subprocess.check_output(["xcode-select", "-p"], text=True).strip()
frameworks = f"{developer}/Platforms/MacOSX.platform/Developer/Library/Frameworks"
libraries = f"{developer}/Platforms/MacOSX.platform/Developer/usr/lib"
runner = build / "main.swift"
runner.write_text('''import XCTest
let suite = XCTestSuite(name: "ERP layout and feature rules")
suite.addTest(XCTestSuite(forTestCaseClass: LayoutMetricsTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: FeatureRulesTests.self))
suite.run()
guard let result = suite.testRun, result.executionCount == 31, result.hasSucceeded else { exit(1) }
print("PASS: 31 layout and feature tests, including 1,321 continuous window widths")
''')
executable = build / "layout-tests"
subprocess.run([
    "xcrun", "swiftc", "-D", "LAYOUT_CHECK", "-module-cache-path", str(build / "ModuleCache"),
    "-F", frameworks, "-I", libraries, "-L", libraries,
    "-Xlinker", "-rpath", "-Xlinker", frameworks, "-Xlinker", "-rpath", "-Xlinker", libraries,
    str(root / "ERP/LayoutMetrics.swift"), str(root / "ERPTests/LayoutMetricsTests.swift"),
    str(root / "ERP/JSON.swift"), str(root / "ERP/FeatureRules.swift"), str(root / "ERPTests/FeatureRulesTests.swift"),
    str(runner), "-o", str(executable)
], check=True)
subprocess.run([str(executable)], check=True)
