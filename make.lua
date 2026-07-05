require( "ggbuild.gen_ninja" )
require( "ggbuild.git_version" )

-- Detect architecture and set macOS ARM64 flag
local target_arch = io.popen("uname -m"):read("*l")
local is_macos_arm64 = (OS == "macos" and target_arch == "arm64")

global_cxxflags( "-I source -I libs" )
if is_macos_arm64 then
	global_cxxflags( "-I/opt/homebrew/include" ) -- Homebrew headers for ARM64
end

msvc_global_cxxflags( "/std:c++20 /W4 /wd4100 /wd4146 /wd4189 /wd4201 /wd4307 /wd4324 /wd4351 /wd4127 /wd4505 /wd4530 /wd4702 /wd4706 /D_CRT_SECURE_NO_WARNINGS" )
msvc_global_cxxflags( "/wd4244 /wd4267" ) -- silence conversion warnings because there are tons of them
msvc_global_cxxflags( "/wd4611" ) -- setjmp warning
msvc_global_cxxflags( "/wd5030" ) -- unrecognized [[gnu::...]] attribute
msvc_global_cxxflags( "/we4130" ) -- warning C4130: '!=': logical operation on address of string constant
msvc_global_cxxflags( "/GR- /EHs-c-" )

gcc_global_cxxflags( "-std=c++20 -fno-exceptions -fno-rtti -fno-strict-aliasing -fno-strict-overflow -fno-math-errno -fvisibility=hidden" )
gcc_global_cxxflags( "-Wall -Wextra -Wcast-align -Wvla -Wformat-security -Wimplicit-fallthrough" ) -- -Wconversion
gcc_global_cxxflags( "-Werror=format -Werror=implicit-fallthrough" )
gcc_global_cxxflags( "-Wno-unused-parameter -Wno-missing-field-initializers" )
gcc_global_cxxflags( "-Wno-switch" ) -- this is too annoying in practice
gcc_global_cxxflags( "-D_LIBCPP_REMOVE_TRANSITIVE_INCLUDES" )

-- Limit SSE to x86_64 Linux only (skip ARM)
if OS == "linux" and target_arch == "x86_64" then
	gcc_global_cxxflags( "-msse4.2 -mpopcnt" )
end

-- Native Apple Silicon flags and minimum deployment target
if is_macos_arm64 then
	gcc_global_cxxflags( "-arch arm64 -mmacosx-version-min=11.0" )
	gcc_global_cxxflags( "-DDISCORD=0" )   -- <-- disable Discord flag
end

if config == "release" then
	global_cxxflags( "-DPUBLIC_BUILD" )
	gcc_global_cxxflags( "-Werror" ) -- -Werror in dev is too annoying. TODO: make a whitelist instead
	gcc_global_cxxflags( "-Wno-error=switch -Wno-error=sign-compare -Wno-error=dynamic-class-memaccess" ) -- these are difficult to fix
else
	global_cxxflags( "-DTRACY_ENABLE" )
end

require( "libs.cgltf" )
require( "libs.clay" )
require( "libs.curl" )
if not is_macos_arm64 then
	require( "libs.discord" )
end
require( "libs.dr_mp3" )
if not is_macos_arm64 then
	require( "libs.freetype" )
end
require( "libs.gg" )
require( "libs.glad" )
require( "libs.imgui" )
require( "libs.jsmn" )
require( "libs.luau" )
require( "libs.mbedtls" )
require( "libs.meshoptimizer" )
require( "libs.monocypher" )
require( "libs.msdfgen" )
require( "libs.openal" )
require( "libs.picohttpparser" )
require( "libs.rgbcx" )
require( "libs.sdl" )
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

do
	-- Build client libs list, skipping static SDL/OpenAL on macOS ARM64
	local client_libs = {
		"imgui",
		"cgltf",
		"clay",
		-- discord removed for ARM64
		"dr_mp3",
		-- freetype removed for ARM64
		"ggentropy",
		"ggformat",
		"ggtime",
		"glad",
		"jsmn",
		"luau",
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
	if not is_macos_arm64 then
		table.insert( client_libs, "sdl" )
		table.insert( client_libs, "openal" )
		table.insert( client_libs, "discord" )
		table.insert( client_libs, "freetype" )
	end

	-- Base macOS linker flags, extended with Homebrew paths and dynamic libs for ARM64
	local macos_ld = "-lcurl -framework AudioToolbox -framework Cocoa -framework CoreAudio -framework CoreHaptics -framework CoreVideo -framework IOKit -framework GameController -framework ForceFeedback -framework Carbon -framework UniformTypeIdentifiers -framework QuartzCore"
	if is_macos_arm64 then
		macos_ld = macos_ld .. " -L/opt/homebrew/lib -lSDL2 -lopenal -lfreetype"
	end

	bin( "client", {
		srcs = {
			"source/cgame/*.cpp",
			"source/client/**.cpp",
			"source/game/**.cpp",
			"source/gameshared/*.cpp",
			"source/qcommon/**.cpp",
			"source/server/sv_*.cpp",
		},

		libs = client_libs,

		rc = "source/client/platform/client",

		windows_ldflags = "shell32.lib gdi32.lib ole32.lib oleaut32.lib ws2_32.lib crypt32.lib winmm.lib version.lib imm32.lib advapi32.lib setupapi.lib /SUBSYSTEM:WINDOWS",
		macos_ldflags = macos_ld,
		linux_ldflags = "-lm -lpthread -ldl",
		no_static_link = true,
	} )
end

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
end

write_ninja_script()
