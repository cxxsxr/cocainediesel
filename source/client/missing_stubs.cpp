// Lua stub – no extern "C" to match C++ caller
struct lua_State;
void lua_pushlightuserdata(lua_State* L, void* p) {
    (void)L; (void)p;
}

// OpenAL and SDL stubs – headers declare these as extern "C"
extern "C" {
    typedef unsigned int ALuint;
    typedef int ALenum;
    typedef void ALvoid;
    typedef int ALsizei;
    void alBufferDataStatic(ALuint buffer, ALenum format, const ALvoid* data, ALsizei size, ALsizei frequency) {
        (void)buffer; (void)format; (void)data; (void)size; (void)frequency;
    }

    typedef unsigned int SDL_DisplayID;
    int SDL_GetDisplayIndex(SDL_DisplayID displayID) {
        (void)displayID;
        return 0;
    }
}