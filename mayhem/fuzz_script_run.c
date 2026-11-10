// A cart's code run by the embedded interpreters through the core's tick, the way a player does.
// The first input byte picks the language (the code's own `script:` metatag may still override it),
// the rest is the cart's code.
#include "api.h"
#include "script.h"

#include <stdint.h>
#include <string.h>

static u64 Ticks;

static u64 counter(void* data)
{
    (void)data;
    return Ticks++;
}

static u64 freq(void* data)
{
    (void)data;
    return 1000;
}

static void trace(void* data, const char* text, u8 color)
{
    (void)data, (void)text, (void)color;
}

static void error(void* data, const char* info)
{
    (void)data, (void)info;
}

static void quit(void* data)
{
    (void)data;
}

int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    if(size < 1)
        return -1;

    s32 count = 0;
    for(const tic_script** it = tic_scripts(); *it; it++)
        count++;

    const tic_script* script = tic_scripts()[data[0] % count];

    Ticks = 0;
    tic_mem* tic = tic_core_create(TIC80_SAMPLERATE, TIC80_PIXEL_COLOR_RGBA8888);

    size_t codeSize = size - 1 < sizeof(tic->cart.code.data) - 1 ? size - 1 : sizeof(tic->cart.code.data) - 1;
    memcpy(tic->cart.code.data, data + 1, codeSize);
    tic->cart.lang = script->id;

    tic_tick_data tick = {
        .error = error,
        .trace = trace,
        .exit = quit,
        .counter = counter,
        .freq = freq,
        .data = tic,
    };

    int result = 0;

    for(int frame = 0; frame < 3; frame++)
    {
        tic_core_tick_start(tic);
        tic_core_tick(tic, &tick);
        tic_core_tick_end(tic);
        tic_core_blit(tic);

        if(frame == 0 && !tic_core_script_ready(tic))
        {
            result = -1;
            break;
        }
    }

    tic_core_close(tic);
    return result;
}
