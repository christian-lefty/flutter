// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/dart/dependencies.dart';
import 'package:flutter_tools/src/dependency_checker.dart';
import 'package:test/test.dart';
import 'src/common.dart';
import 'src/context.dart';

void main()  {
  group('DependencyChecker', () {
    final String basePath = fs.path.dirname(fs.path.fromUri(platform.script));
    final String dataPath = fs.path.join(basePath, 'data', 'dart_dependencies_test');
    FileSystem testFileSystem;

    setUp(() {
      Cache.disableLocking();
      testFileSystem = new MemoryFileSystem();
    });

    testUsingContext('good', () {
      final String testPath = fs.path.join(dataPath, 'good');
      final String mainPath = fs.path.join(testPath, 'main.dart');
      final String fooPath = fs.path.join(testPath, 'foo.dart');
      final String barPath = fs.path.join(testPath, 'lib', 'bar.dart');
      final String packagesPath = fs.path.join(testPath, '.packages');
      DartDependencySetBuilder builder =
          new DartDependencySetBuilder(mainPath, testPath, packagesPath);
      DependencyChecker dependencyChecker =
          new DependencyChecker(builder, null);

      // Set file modification time on all dependencies to be in the past.
      DateTime baseTime = new DateTime.now();
      updateFileModificationTime(packagesPath, baseTime, -10);
      updateFileModificationTime(mainPath, baseTime, -10);
      updateFileModificationTime(fooPath, baseTime, -10);
      updateFileModificationTime(barPath, baseTime, -10);
      expect(dependencyChecker.check(baseTime), isFalse);

      // Set .packages file modification time to be in the future.
      updateFileModificationTime(packagesPath, baseTime, 20);
      expect(dependencyChecker.check(baseTime), isTrue);

      // Reset .packages file modification time.
      updateFileModificationTime(packagesPath, baseTime, 0);
      expect(dependencyChecker.check(baseTime), isFalse);

      // Set 'package:self/bar.dart' file modification time to be in the future.
      updateFileModificationTime(barPath, baseTime, 10);
      expect(dependencyChecker.check(baseTime), isTrue);
    }, skip: io.Platform.isWindows); // TODO(goderbauer): enable when sky_snapshot is ready on Windows

    testUsingContext('syntax error', () {
      final String testPath = fs.path.join(dataPath, 'syntax_error');
      final String mainPath = fs.path.join(testPath, 'main.dart');
      final String fooPath = fs.path.join(testPath, 'foo.dart');
      final String packagesPath = fs.path.join(testPath, '.packages');

      DartDependencySetBuilder builder =
          new DartDependencySetBuilder(mainPath, testPath, packagesPath);
      DependencyChecker dependencyChecker =
          new DependencyChecker(builder, null);

      DateTime baseTime = new DateTime.now();

      // Set file modification time on all dependencies to be in the past.
      updateFileModificationTime(packagesPath, baseTime, -10);
      updateFileModificationTime(mainPath, baseTime, -10);
      updateFileModificationTime(fooPath, baseTime, -10);

      // Dependencies are considered dirty because there is a syntax error in
      // the .dart file.
      expect(dependencyChecker.check(baseTime), isTrue);
    });

    /// Test a flutter tool move.
    ///
    /// Tests that the flutter tool doesn't crash and displays a warning when its own location
    /// changed since it was last referenced to in a package's .packages file.
    testUsingContext('moved flutter sdk', () async {
      Directory destinationPath = fs.systemTempDirectory.createTempSync('dependency_checker_test_');
      // Copy the golden input and let the test run in an isolated temporary in-memory file system.
      LocalFileSystem localFileSystem = const LocalFileSystem();
      Directory sourcePath =  localFileSystem.directory(localFileSystem.path.join(dataPath, 'changed_sdk_location'));
      copyDirectorySync(sourcePath, destinationPath);
      fs.currentDirectory = destinationPath;

      // Doesn't matter what commands we run. Arbitrarily list devices here.
      await createTestCommandRunner(new DevicesCommand()).run(<String>['devices']);
      expect(testLogger.errorText, contains('.packages'));
    }, overrides: <Type, Generator>{
      FileSystem: () => testFileSystem,
    });
  });
}
