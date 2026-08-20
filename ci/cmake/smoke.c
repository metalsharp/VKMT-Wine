#include <stdint.h>
#include <stdio.h>

int main(void)
{
    const uint32_t contract = UINT32_C(0x564b4d54);

    if (contract != UINT32_C(0x564b4d54))
        return 1;

    puts("VKMT_CMAKE_SMOKE_OK");
    return 0;
}
