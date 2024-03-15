//! A filetest-lookalike test suite using Cranelift tooling but built on
//! Wasmtime's code generator.
//!
//! This test will read the `tests/disas/*` directory and interpret all files in
//! that directory as a test. Each test must be in the wasm text format and
//! start with directives that look like:
//!
//! ```wasm
//! ;;! target = "x86_64"
//! ;;! compile = true
//!
//! (module
//!     ;; ...
//! )
//! ```
//!
//! Tests must configure a `target` and then can optionally specify a kind of
//! test:
//!
//! * No specifier - the output CLIF from translation is inspected.
//! * `optimize = true` - CLIF is emitted, then optimized, then inspected.
//! * `compile = true` - backends are run to produce machine code and that's inspected.
//!
//! Tests may also have a `flags` directive which are CLI flags to Wasmtime
//! itself:
//!
//! ```wasm
//! ;;! target = "x86_64"
//! ;;! flags = "-O opt-level=s"
//!
//! (module
//!     ;; ...
//! )
//! ```
//!
//! Flags are parsed by the `wasmtime_cli_flags` crate to build a `Config`.
//!
//! Configuration of tests is prefixed with `;;!` comments and must be present
//! at the start of the file. These comments are then parsed as TOML and
//! deserialized into `TestConfig` in this crate.

use anyhow::{bail, Context, Result};
use clap::Parser;
use cranelift_codegen::ir::{UserExternalName, UserFuncName};
use cranelift_codegen::isa::{lookup_by_name, TargetIsa};
use cranelift_codegen::settings::{Configurable, Flags, SetError};
use cranelift_filetests::test_wasm::{parse_test_config, run_functions, TestKind};
use serde_derive::Deserialize;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tempfile::TempDir;
use wasmtime::{Engine, OptLevel};
use wasmtime_cli_flags::CommonOptions;

fn main() -> Result<()> {
    if cfg!(miri) {
        return Ok(());
    }

    // First discover all tests ...
    let mut tests = Vec::new();
    find_tests("./tests/disas".as_ref(), &mut tests)?;

    // ... then run all tests!
    for test in tests.iter() {
        run_test(&test).with_context(|| format!("failed to run tests {test:?}"))?;
    }

    Ok(())
}

fn find_tests(path: &Path, dst: &mut Vec<PathBuf>) -> Result<()> {
    for file in path
        .read_dir()
        .with_context(|| format!("failed to read {path:?}"))?
    {
        let file = file.context("failed to read directory entry")?;
        let path = file.path();
        if file.file_type()?.is_dir() {
            find_tests(&path, dst)?;
        } else if path.extension().and_then(|s| s.to_str()) == Some("wat") {
            dst.push(path);
        }
    }
    Ok(())
}

fn run_test(path: &Path) -> Result<()> {
    let mut test = Test::new(path)?;
    let clifs = test.generate_clif()?;
    let isa = test.build_target_isa()?;

    // Parse the text format CLIF which is emitted by Wasmtime back into
    // in-memory data structures.
    let mut functions = clifs
        .iter()
        .map(|clif| {
            let mut funcs = cranelift_reader::parse_functions(clif)?;
            if funcs.len() != 1 {
                bail!("expected one function per clif");
            }
            Ok(funcs.remove(0))
        })
        .collect::<Result<Vec<_>>>()?;
    functions.sort_by_key(|f| match f.name {
        UserFuncName::User(UserExternalName { namespace, index }) => (namespace, index),
        UserFuncName::Testcase(_) => unreachable!(),
    });

    // And finally, use `cranelift_filetests` to perform the rest of the test.
    run_functions(
        &test.path,
        &test.contents,
        &*isa,
        test.config.test,
        &functions,
    )?;

    Ok(())
}
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct TestConfig {
    target: String,
    #[serde(default)]
    test: TestKind,
    flags: Option<TestConfigFlags>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum TestConfigFlags {
    SpaceSeparated(String),
    List(Vec<String>),
}

struct Test {
    path: PathBuf,
    contents: String,
    opts: CommonOptions,
    config: TestConfig,
}

impl Test {
    /// Parse the contents of `path` looking for directive-based comments
    /// starting with `;;!` near the top of the file.
    fn new(path: &Path) -> Result<Test> {
        let contents =
            std::fs::read_to_string(path).with_context(|| format!("failed to read {path:?}"))?;
        let config: TestConfig =
            parse_test_config(&contents).context("failed to parse test configuration as TOML")?;
        let mut flags = vec!["wasmtime"];
        match &config.flags {
            Some(TestConfigFlags::SpaceSeparated(s)) => flags.extend(s.split_whitespace()),
            Some(TestConfigFlags::List(s)) => flags.extend(s.iter().map(|s| s.as_str())),
            None => {}
        }
        let opts = wasmtime_cli_flags::CommonOptions::try_parse_from(&flags)?;

        Ok(Test {
            path: path.to_path_buf(),
            config,
            opts,
            contents,
        })
    }

    /// Generates CLIF for all the wasm functions in this test.
    fn generate_clif(&mut self) -> Result<Vec<String>> {
        // Use wasmtime::Config with its `emit_clif` option to get Wasmtime's
        // code generator to jettison CLIF out the back.
        let tempdir = TempDir::new().context("failed to make a tempdir")?;
        let mut config = self.opts.config(Some(&self.config.target))?;
        config.emit_clif(tempdir.path());
        let engine = Engine::new(&config).context("failed to create engine")?;
        let module = wat::parse_file(&self.path)?;
        engine
            .precompile_module(&module)
            .context("failed to compile module")?;

        // Read all `*.clif` files from the clif directory that the compilation
        // process just emitted.
        let mut clifs = Vec::new();
        for entry in tempdir
            .path()
            .read_dir()
            .context("failed to read tempdir")?
        {
            let entry = entry.context("failed to iterate over tempdir")?;
            let path = entry.path();
            let clif = std::fs::read_to_string(&path)
                .with_context(|| format!("failed to read clif file {path:?}"))?;
            clifs.push(clif);
        }
        Ok(clifs)
    }

    /// Use the test configuration present with CLI flags to build a
    /// `TargetIsa` to compile/optimize the CLIF.
    fn build_target_isa(&self) -> Result<Arc<dyn TargetIsa>> {
        let mut builder = lookup_by_name(&self.config.target)?;
        let mut flags = cranelift_codegen::settings::builder();
        let opt_level = match self.opts.opts.opt_level {
            None | Some(OptLevel::Speed) => "speed",
            Some(OptLevel::SpeedAndSize) => "speed_and_size",
            Some(OptLevel::None) => "none",
            _ => unreachable!(),
        };
        flags.set("opt_level", opt_level)?;
        for (key, val) in self.opts.codegen.cranelift.iter() {
            let key = &key.replace("-", "_");
            let target_res = match val {
                Some(val) => builder.set(key, val),
                None => builder.enable(key),
            };
            match target_res {
                Ok(()) => continue,
                Err(SetError::BadName(_)) => {}
                Err(e) => bail!(e),
            }
            match val {
                Some(val) => flags.set(key, val)?,
                None => flags.enable(key)?,
            }
        }
        let isa = builder.finish(Flags::new(flags))?;
        Ok(isa)
    }
}
