#!/usr/bin/env node

var commander = require('commander')
  , bundle    = require('../');

commander
  .version('0.0.1')
  .usage('[command]');

commander
  .command("list")
  .description("  Print the names of all installed bundles")
  .action(function() {
    bundle.list(function(err, names) {
      var _ref = names.sort();
      console.log("\nInstalled bundles:\n");
      for (var _i = 0, _len = _ref.length; _i < _len; _i++) {
        var name = _ref[_i];
        console.log("  * " + name + " (" + (bundle(name).version) + ")");
      }
      console.log("");
      process.exit();
    });
  });

commander
  .command("install <name>")
  .description("  Install the bundle.")
  .action(function(name) {
    bundle.install(name, function(err) {
      console.log("");
      if (err) {
        console.log("  " + err.message);
      } else {
        console.log("  install : " + name + "@" + (bundle(name).version));
      }
      console.log("");
      process.exit();
    });
  });

commander
  .command("uninstall <name>")
  .description("  Uninstall the bundle.")
  .action(function(name) {
    bundle.uninstall(name, function(err) {
      console.log("");
      if (err) {
        console.log("  " + err.message);
      } else {
        console.log("  uninstall : " + name);
      }
      console.log("");
      process.exit();
    });
  });

commander
  .command("update <name>")
  .description("  Update the bundle.")
  .action(function(name) {
    bundle.update(name, function(err) {
      console.log("");
      if (err) {
        console.log("  " + err.message);
      } else {
        console.log("  update : " + name + "@" + (bundle(name).version));
      }
      console.log("");
      process.exit();
    });
  });

commander
  .command("show <name>")
  .description("  Print the path to the bundle.")
  .action(function(name) {
    var b = bundle(name);
    console.log("");
    console.log("  " + name + "@" + b.version);
    console.log("");
    console.log("  * author - " + b.author);
    console.log("  * path   - " + b.path);
    console.log("  * url    - " + b.url);
    console.log("");
    process.exit();
  });

commander
  .command("test [name]")
  .description("  Check whether or not the given bundle is valid,\n\
  or validate all bundles if no name or path is specified.\n")
  .action(function(name) {
    function test(bundleName) {
      var err, path;
      path = bundlePath(bundleName);
      err = bundle.test(path);
      if (err) {
        console.error("  ✖ " + bundleName);
        return console.error(err.message);
      } else {
        return console.log("  ✔ " + bundleName);
      }
    }
    
    function bundlePath(bundleName) {
      if (~bundleName.indexOf("/")) {
        return bundleName;
      } else {
        return "" + bundle.dir + "/" + bundleName;
      }
    }
    
    console.log("");
    if (name) {
      test(name);
      console.log("");
      process.exit();
    } else {
      return bundle.list(function(err, names) {
        var _ref = names.sort();
        for (var _i = 0, _len = _ref.length; _i < _len; _i++) {
          var name = _ref[_i];
          test(name);
        }
        console.log("");
        process.exit();
      });
    }
  });

commander
  .command("setup")
  .description("Install a bunch of common bundles.")
  .action(function() {
    bundle.setup(function(err) {
      if (err) {
        console.log("Error");
        throw err;
      } else {
        console.log("Success");
      }
      process.exit();
    });
  });

commander.parse(process.argv);
