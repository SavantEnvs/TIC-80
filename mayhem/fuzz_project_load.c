// Project (text) cart parser: tic_project_load for every registered script language.
// The first input byte picks the language, the rest is the project file.
#include "script.h"
#include "studio/project.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    if(size < 1)
        return -1;

    s32 count = 0;
    for(const tic_script** it = tic_scripts(); *it; it++)
        count++;

    const tic_script* script = tic_scripts()[data[0] % count];

    char name[64];
    snprintf(name, sizeof name, "cart.%s", script->fileExtension);

    tic_cartridge* cart = calloc(1, sizeof(tic_cartridge));
    bool ok = tic_project_load(name, (const char*)data + 1, (s32)size - 1, cart);
    free(cart);

    return ok ? 0 : -1;
}
