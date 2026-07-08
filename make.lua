require( "ggbuild.gen_ninja" )
require( "ggbuild.git_version" )

-- Detect OS and architecture
local target_arch = io.popen("uname -m"):read("*l")
local is_macos_arm64 = (OS == "macos" and target_arch == "arm64")

-- Helper: check if file exists
local function file_exists(path)
	local f = io.open(path, "r")
	if f then f:close(); return true end
	return false
end

-- Helper: get all .a files in a directory and reorder them
local function get_reordered_luau_libs(dir)
	local libs = {}
	local f = io.popen("find " .. dir .. " -maxdepth 1 -name '*.a' -type f 2>/dev/null")
	for line in f:lines() do
		table.insert(libs, line)
	end
	f:close()
	local priority = { "VM", "Ast", "Common" }
	local ordered = {}
	local rest = {}
	local priority_set = {}
	for _, p in ipairs(priority) do priority_set[p] = true end

	for _, lib in ipairs(libs) do
		local found = false
		for _, p in ipairs(priority) do
			if string.find(lib, p) then
				table.insert(ordered, lib)
				found = true
				break
			end
		end
		if not found then
			table.insert(rest, lib)
		end
	end
	for _, lib in ipairs(rest) do
		table.insert(ordered, lib)
	end
	return ordered
end

global_cxxflags( "-I source -I libs" )

-- -------------------------------------------------------------------------
-- macOS ARM64: external libraries
-- -------------------------------------------------------------------------
local external_cflags = ""
local external_ldflags = ""

if is_macos_arm64 then
	local brew_lib = "/opt/homebrew/lib"
	local brew_include = "/opt/homebrew/include"
	local luau_dir = "/Users/caesar/cocainediesel/libs/luau/macos-debug"

	-- Ensure libraries exist
	if not file_exists(brew_lib .. "/libSDL3.0.dylib") then
		error("SDL3 library not found. Install: brew install sdl3")
	end
	if not file_exists(brew_lib .. "/libopenal.dylib") then
		error("libopenal.dylib not found. Install: brew install openal-soft")
	end
	if not file_exists(brew_lib .. "/libfreetype.dylib") then
		error("libfreetype.dylib not found. Install: brew install freetype")
	end

	-- Luau: collect and reorder .a files
	local luau_libs = get_reordered_luau_libs(luau_dir)
	if #luau_libs == 0 then
		error("No Luau static libraries found in " .. luau_dir .. ". Copy them from your Luau build.")
	end

	-- Compiler flags
	external_cflags = "-I" .. brew_include .. " -I" .. brew_include .. "/SDL3"
	external_cflags = external_cflags .. " -DAL_ALEXT_PROTOTYPES"

	-- Linker flags: system libraries first, then Luau static libs
	external_ldflags = "-L" .. brew_lib .. " -lSDL3 -lopenal -lfreetype -lc++"
	for _, lib in ipairs(luau_libs) do
		external_ldflags = external_ldflags .. " " .. lib
	end

	-- Native ARM64 compiler flags
	gcc_global_cxxflags( "-arch arm64 -mmacosx-version-min=11.0" )
	gcc_global_cxxflags( "-DDISCORD=0" )
end

-- -------------------------------------------------------------------------
-- Common MSVC / GCC flags
-- -------------------------------------------------------------------------
msvc_global_cxxflags( "/std:c++20 /W4 /wd4100 /wd4146 /wd4189 /wd4201 /wd4307 /wd4324 /wd4351 /wd4127 /wd4505 /wd4530 /wd4702 /wd4706 /D_CRT_SECURE_NO_WARNINGS" )
msvc_global_cxxflags( "/wd4244 /wd4267" )
msvc_global_cxxflags( "/wd4611" )
msvc_global_cxxflags( "/wd5030" )
msvc_global_cxxflags( "/we4130" )
msvc_global_cxxflags( "/GR- /EHs-c-" )

gcc_global_cxxflags( "-std=c++20 -fno-exceptions -fno-rtti -fno-strict-aliasing -fno-strict-overflow -fno-math-errno -fvisibility=hidden" )
gcc_global_cxxflags( "-Wall -Wextra -Wcast-align -Wvla -Wformat-security -Wimplicit-fallthrough" )
gcc_global_cxxflags( "-Werror=format -Werror=implicit-fallthrough" )
gcc_global_cxxflags( "-Wno-unused-parameter -Wno-missing-field-initializers" )
gcc_global_cxxflags( "-Wno-switch" )
gcc_global_cxxflags( "-D_LIBCPP_REMOVE_TRANSITIVE_INCLUDES" )

if OS == "linux" and target_arch == "x86_64" then
	gcc_global_cxxflags( "-msse4.2 -mpopcnt" )
end

if config == "release" then
	global_cxxflags( "-DPUBLIC_BUILD" )
	gcc_global_cxxflags( "-Werror" )
	gcc_global_cxxflags( "-Wno-error=switch -Wno-error=sign-compare -Wno-error=dynamic-class-memaccess" )
else
	global_cxxflags( "-DTRACY_ENABLE" )
end

if is_macos_arm64 then
	global_cxxflags( external_cflags )
end

-- -------------------------------------------------------------------------
-- Internal libraries – skip SDL, OpenAL, Freetype, Discord on ARM64
-- -------------------------------------------------------------------------
require( "libs.cgltf" )
require( "libs.clay" )
require( "libs.curl" )
if not is_macos_arm64 then require( "libs.discord" ) end
require( "libs.dr_mp3" )
if not is_macos_arm64 then require( "libs.freetype" ) end
require( "libs.gg" )
require( "libs.glad" )
require( "libs.imgui" )
require( "libs.jsmn" )
-- Luau: we link the .a files manually; no require needed
require( "libs.mbedtls" )
require( "libs.meshoptimizer" )
require( "libs.monocypher" )
require( "libs.msdfgen" )
if not is_macos_arm64 then require( "libs.openal" ) end
require( "libs.picohttpparser" )
require( "libs.rgbcx" )
if not is_macos_arm64 then require( "libs.sdl" ) end
require( "libs.stb" )
require( "libs.tracy" )
require( "libs.zstd" )

require( "source.tools.bc4" )
require( "source.tools.dieselfont" )
require( "source.tools.dieselmap" )

local platform_curl_libs = {
	{ OS ~= "macos" and "curl" or nil },
	{ OS == "linux" and "mbedtls" or nil },
}

obj_cxxflags( "source/client/cl_imgui.cpp", "-I libs/sdl" )
obj_cxxflags( "source/client/cl_menus.cpp", "-I libs/sdl" )
obj_cxxflags( "source/client/cl_sdl.cpp", "-I libs/sdl" )
obj_cxxflags( "source/client/keys.cpp", "-I libs/sdl" )
obj_cxxflags( "source/client/renderer/backend.cpp", "-I libs/sdl" )
obj_cxxflags( "source/qcommon/linear_algebra_kernels.cpp", "-O2" )

-- -------------------------------------------------------------------------
-- Client binary (do block)
-- -------------------------------------------------------------------------
do
	-- Source list: the glob includes discord_stub.cpp and missing_stubs.cpp
	local client_srcs = {
		"source/cgame/*.cpp",
		"source/client/**.cpp",
		"source/game/**.cpp",
		"source/gameshared/*.cpp",
		"source/qcommon/**.cpp",
		"source/server/sv_*.cpp",
	}
	-- missing_stubs.cpp is already included by "source/client/**.cpp"

	local client_libs = {
		"imgui",
		"cgltf",
		"clay",
		"dr_mp3",
		"ggentropy",
		"ggformat",
		"ggtime",
		"glad",
		"jsmn",
		"monocypher",
		"picohttpparser",
		"stb_image",
		"stb_image_write",
		"stb_rect_pack",
		"stb_vorbis",
		"tracy",
		"zstd",
		platform_curl_libs,
	}

	local macos_ld = "-lcurl -framework AudioToolbox -framework Cocoa -framework CoreAudio -framework CoreHaptics -framework CoreVideo -framework IOKit -framework GameController -framework ForceFeedback -framework Carbon -framework UniformTypeIdentifiers -framework QuartzCore"

	if is_macos_arm64 then
		macos_ld = macos_ld .. " " .. external_ldflags
	end

	bin( "client", {
		srcs = client_srcs,
		libs = client_libs,
		rc = "source/client/platform/client",
		windows_ldflags = "shell32.lib gdi32.lib ole32.lib oleaut32.lib ws2_32.lib crypt32.lib winmm.lib version.lib imm32.lib advapi32.lib setupapi.lib /SUBSYSTEM:WINDOWS",
		macos_ldflags = macos_ld,
		linux_ldflags = "-lm -lpthread -ldl",
		no_static_link = true,
	} )
end  -- <-- This 'end' closes the client do block

-- -------------------------------------------------------------------------
-- Server binary (do block)
-- -------------------------------------------------------------------------
do
	bin( "server", {
		srcs = {
			"source/game/**.cpp",
			"source/gameshared/*.cpp",
			"source/qcommon/**.cpp",
			"source/server/**.cpp",
		},
		libs = {
			"cgltf",
			"ggentropy",
			"ggformat",
			"ggtime",
			"monocypher",
			"picohttpparser",
			"tracy",
			"zstd",
		},
		windows_ldflags = "ole32.lib ws2_32.lib crypt32.lib shell32.lib user32.lib advapi32.lib",
		linux_ldflags = "-lm -lpthread",
	} )
end  -- <-- This 'end' closes the server do block

write_ninja_script()
