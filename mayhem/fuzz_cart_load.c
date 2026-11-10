// Cartridge loader: chunk, PNG-wrapped and legacy carts through tic_cart_load, then the saver.
#include "cart.h"

#include <stdint.h>
#include <stdlib.h>

int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    // tic_cart_load memcmp()s a 4-byte PNG magic without checking size; libFuzzer's startup
    // empty-input probe would abort every run on it (mayhem/known-findings/cart-short-input).
    if (size < 4) return -1;

    tic_cartridge* cart = malloc(sizeof(tic_cartridge));
    u8* saved = malloc(TIC_CART_SAVE_SIZE);

    tic_cart_load(cart, data, (s32)size);

    // What the studio does with a loaded cart: write it back out and read that again.
    s32 savedSize = tic_cart_save(cart, saved);
    tic_cart_load(cart, saved, savedSize);

    free(saved);
    free(cart);
    return 0;
}
