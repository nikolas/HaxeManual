package;

import sys.FileSystem;
import sys.io.File;
using StringTools;

@:enum
abstract Target(String) from String to String
{
	var Swf = "swf";
	var As3 = "as3";
	var Js = "js";
	var Neko = "neko";
	var Cpp = "cpp";
	var Cppia = "cppia";
	var Cs = "cs";
	var Java = "java";
	var Python = "python";
	var Hl = "hl";
	var Lua = "lua";
}

@:enum
abstract ExitCode(Int) from Int to Int
{
	var Success = 0;
	var Failure = 1;

	@:from
	static function fromBool(b:Bool):ExitCode {
		return b ? ExitCode.Success : ExitCode.Failure;
	}

	@:to
	function toColor():Color {
		return (this == ExitCode.Success) ? Color.Green : Color.Red;
	}
}

@:enum
abstract Color(Int)
{
	var None = 0;
	var Red = 31;
	var Green = 32;
}

enum InsertIn
{
	Function;
	Module;
}

class RunTravis
{
	/** Examples that are expected to fail / *should* produce a compiler error. */
	static var requiredFailures = [
		"AbstractExposeTypeOperations.hx",
		"DynamicInferenceIssue.hx",
		"ExprOf.hx",
		"Extractor5.hx",
		"FunctionTypeParameter.hx",
		"GetterSetter2.hx",
		"ImplicitTransitiveCast.hx",
		"Property4.hx",
		"SelectiveFunction.hx",
		"SwitchEnum.hx",
		"Test.hx",
		"Variance.hx",
		"Visibility.hx",
		"Visibility2.hx",
		"BindOptional.hx",
		#if (haxe_ver >= 4)
		"DynamicResolve.hx", // this fails on Haxe4
		#end
	];

	/** Examples that are not included in the tests. */
	static var excludedExamples = [
		"ClassExpose.hx", // no main()
		"CompletionServer.hx", // sys/socket stuff
		"HelloPHP.hx", // PHP only
		"JSRequireModule.hx",
		"JSRequireObject.hx",
		"RestAndEitherType.hx", // requires an extern
		"SwitchStatement.hx", // pseudo-code
		"UnitTestCase.hx",
		"UnitTestRunner.hx",
		"UnitTestSetup.hx",
		#if (haxe_ver < 4)
		"AbstractAccessOverload.hx",
		"AbstractEnum2.hx",
		"ArrowFunction.hx",
		"Extension3.hx",
		"Final.hx",
		"FinalMutable.hx",
		"InlineCallsite.hx",
		"ListExample.hx",
		"Markup.hx",
		"PatternMatching4.hx",
		"StaticExtension4.hx",
		"Threads.hx",
		#end
	];

	/** Examples that will not compile on specific targets. */
	static var targetExclusions = [
		Cs => ["ExternNative.hx", "ImplementsDynamic.hx"],
		Cpp => ["ExternNative.hx", "ImplementsDynamic.hx"],
		Hl => ["ExternNative.hx", "ImplementsDynamic.hx"],
		Java => ["ExternNative.hx", "ImplementsDynamic.hx"],
	];

	/** Additional .hx modules needed to compile specific examples. */
	static var additionalModules = [
		"AutoBuilding.hx" => "AutoBuildingMacro.hx",
		"EnumBuilding.hx" => "EnumBuildingMacro.hx",
		"GenericBuild1.hx" => "GenericBuildMacro1.hx",
		"GenericBuild2.hx" => "GenericBuildMacro2.hx",
		"PatternMatching1.hx" => "Tree.hx",
		"PatternMatching2.hx" => "Tree.hx",
		"PatternMatching3.hx" => "Tree.hx",
		"PatternMatching4.hx" => "Tree.hx",
		"PatternMatching5.hx" => "Tree.hx",
		"PatternMatching6.hx" => "Tree.hx",
		"PatternMatching7.hx" => "Tree.hx",
		"PatternMatching8.hx" => "Tree.hx",
		"PatternMatching9.hx" => "Tree.hx",
		"PatternMatching10.hx" => "Tree.hx",
		"PatternMatching11.hx" => "Tree.hx",
		"Point3.hx" => "Point.hx",
		"MathExtensionUsage.hx" => "MathStaticExtension.hx",
		"TypeBuilding.hx" => "TypeBuildingMacro.hx"
	];

	/** Additional imports (for enums) needed to compile specific examples. */
	static var additionalImports = [
		"PatternMatching1.hx" => "Tree",
		"PatternMatching2.hx" => "Tree",
		"PatternMatching3.hx" => "Tree",
		"PatternMatching4.hx" => "Tree",
		"PatternMatching5.hx" => "Tree",
		"PatternMatching6.hx" => "Tree",
		"PatternMatching7.hx" => "Tree",
		"PatternMatching8.hx" => "Tree",
		"PatternMatching9.hx" => "Tree",
		"PatternMatching10.hx" => "Tree",
		"PatternMatching11.hx" => "Tree",
	];

	/** Snippets that don't compile on their own */
	static var incompleteSnippets = [
		"AbstractEnum2.hx" => Module,
		"Color.hx" => Module,
		"Tree.hx" => Module,
		"PatternMatching1.hx" => Function,
		"PatternMatching2.hx" => Function,
		"PatternMatching3.hx" => Function,
		"PatternMatching4.hx" => Function,
		"PatternMatching5.hx" => Function,
		"PatternMatching6.hx" => Function,
		"PatternMatching7.hx" => Function,
		"PatternMatching8.hx" => Function,
		"PatternMatching9.hx" => Function,
		"PatternMatching10.hx" => Function,
		"PatternMatching11.hx" => Function,
		"Point.hx" => Module,
		"Point3.hx" => Module,
		"StringInterpolation.hx" => Function,
		"StructureField.hx" => Module,
		"WhileLoop.hx" => Function
	];

	static var haxelibs = [
		"HaxelibRandom.hx" => ["random"]
	];

	static var helperFile:String;

	public static function main():Void {
		var target:Target = Sys.args()[0];
		if (target == null) {
			Sys.println("No target argument found. Defaulting to neko.");
			target = Target.Neko;
		}

		for (additionalModule in additionalModules)
			excludedExamples.push(additionalModule);
		// special case, both needed as an additional module and needs to compile on its own
		excludedExamples.remove("Point.hx");

		if (targetExclusions.exists(target))
			excludedExamples = excludedExamples.concat(targetExclusions[target]);

		helperFile = File.getContent("Helper.hx");

		Sys.exit(getResult([
			setupHxcpp(target),
			buildExamples(target, Sys.args().slice(1))
		]));
	}

	static function setupHxcpp(target:Target):ExitCode {
		if (target != Target.Cpp)
			return ExitCode.Success;

		#if (haxe_ver >= "3.3")
		var hxcppDir = Sys.getEnv("HOME") + "/haxe/lib/hxcpp/git/";
		return getResult([
			Sys.command("haxelib", ["git", "hxcpp", "https://github.com/HaxeFoundation/hxcpp"]),
			runCommandInDir(hxcppDir + "tools/run", "haxe", ["compile.hxml"]),
			runCommandInDir(hxcppDir + "tools/hxcpp", "haxe", ["compile.hxml"]),
			runCommandInDir(hxcppDir + "project", "neko", ["build.n"])
		]);
		#else
		return Sys.command("haxelib", ["install", "hxcpp"]);
		#end
	}

	static function runCommandInDir(dir:String, cmd:String, args:Array<String>):ExitCode {
		return runInDir(dir, function() return Sys.command(cmd, args));
	}

	static function buildExamples(target:Target, ?included:Array<String>):ExitCode {
		Sys.println("\nBuilding Haxe Manual examples...\n");
		Sys.setCwd("../assets");

		var examples = FileSystem.readDirectory(".").filter(function(f) {
			return f.endsWith(".hx") && excludedExamples.indexOf(f) == -1;
		}).filter(function(f) {
			return included.length == 0 || included.indexOf(f) != -1;
		});

		FileSystem.createDirectory("bin");
		for (additionalModule in additionalModules)
			File.copy(additionalModule, 'bin/$additionalModule');

		var results = [for (example in examples) compile(example, target)];
		var successCount = results.filter(function(e) return e == ExitCode.Success).length;
		var totalCount = examples.length;
		var exitCode:ExitCode = !(successCount < totalCount);
		Sys.println("");
		printWithColor([for (i in 0...50) "-"].join(""), exitCode);
		printWithColor('$successCount/$totalCount examples built successfully.', exitCode);

		return exitCode;
	}

	static function compile(file:String, target:Target):ExitCode {
		var dir = "bin/" + getFileName(file);
		FileSystem.createDirectory(dir);
		Sys.println('Testing $file on $target');

		var insertIn = incompleteSnippets.get(file);
		var additionalImport = additionalImports.get(file);
		if (insertIn != null) {
			var fileContent = File.getContent(file);
			File.saveContent('$dir/Main.hx', helperFile
				.replace("<imports>", (additionalImport != null) ? 'import $additionalImport;' : "")
				.replace("<module>", (insertIn == Module) ? fileContent : "")
				.replace("<function>", (insertIn == Function) ? fileContent : ""));
		} else {
			// workaround for "Module [name] does not define type [name]"
			File.copy(file, '$dir/Main.hx');
		}

		var additional = additionalModules.get(file);
		if (additional != null)
			File.copy(additional, '$dir/$additional');

		return runInDir(dir, function() {
			return hasExpectedResult(file, target);
		});
	}

	static function hasExpectedResult(file:String, target:Target):ExitCode {
		var expectedResult:ExitCode = requiredFailures.indexOf(file) == -1;
		var compileResult = Sys.command("haxe", getCompileArgs(file, target));

		var result = compileResult == expectedResult;
		if (!result)
			printWithColor('Unexpected result for $file:' +
				'$compileResult, expected $expectedResult', Color.Red);
		return result;
	}

	static function getCompileArgs(file:String, target:Target):Array<String> {
		var compileArgs = ["-main", "Main", '-$target', target];
		var haxelibs = haxelibs[file];
		if (haxelibs != null) {
			for (haxelib in haxelibs) {
				compileArgs.push("-lib");
				compileArgs.push(haxelib);
			}
		}
		return compileArgs;
	}

	static function getResult(results:Array<ExitCode>):ExitCode {
		for (result in results)
			if (result != ExitCode.Success)
			return ExitCode.Failure;
		return ExitCode.Success;
	}

	static function printWithColor(message:String, color:Color):Void {
		setColor(color);
		Sys.println(message);
		setColor(Color.None);
	}

	static function setColor(color:Color):Void {
		if (Sys.systemName() == "Linux" || Sys.systemName() == "Mac") {
			var id = (color == Color.None) ? "" : ';$color';
			Sys.stderr().writeString("\033[0" + id + "m");
		}
	}

	static function runInDir(dir:String, func:Void->ExitCode):ExitCode {
		var oldCwd = Sys.getCwd();
		Sys.setCwd(dir);
		var result = func();
		Sys.setCwd(oldCwd);
		return result;
	}

	static function getFileName(file:String):String {
		var dotIndex = file.lastIndexOf(".");
		return file.substring(0, dotIndex);
	}
}
