#ifndef CBUFFER_STRUCTUREDGLOBALDIGITSTART_VIEW_INCLUDED
#define CBUFFER_STRUCTUREDGLOBALDIGITSTART_VIEW_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"
    // Data Layout
    // |<--- BufferWidth --->|         Starting position for each digit,
    // +=====================+         Computed by firstly counting occurences
    // |     Digit  0- 7     | level0  of each possible digit(8bits/digit, 0~256), 
    // |_____________________|         Then apply a prefix sum upon them.
    // |     Digit  8-15     | level1  
    // |_____________________|         e.g: (2bits/digit, for simplicity)
    // |     Digit 16-23     | level2  Digit 00 01 10 11
    // |_____________________|         Count  2  3  1  5
    // |     Digit 24-31     | level3  Scan  -- -- -- --
    // |_____________________|         Start  0  2  5  6

    #ifndef BITS_PER_DIGIT
    #   define BITS_PER_DIGIT 8
    #endif /*BITS_PER_DIGIT*/

    #define DIGITSTART_BUFF_WIDTH 1 << BITS_PER_DIGIT

    #define ADDR_OF_DIGIT(digitLevel, digit) ((digitLevel << BITS_PER_DIGIT) + digit)

#endif /* CBUFFER_STRUCTUREDGLOBALDIGITSTART_VIEW_INCLUDED */
