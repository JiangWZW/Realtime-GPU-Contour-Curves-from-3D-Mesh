#ifndef CBUFFER_STRUCTUREDKEYVALUEPAIR_VIEW_INCLUDED
#define CBUFFER_STRUCTUREDKEYVALUEPAIR_VIEW_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"
    // ////////////////////////////////////////////////////////////////////
    //                          Data Layout                              //
    // ////////////////////////////////////////////////////////////////////
    #define KV_DIGIT_BUFF_START 0
    #ifndef LOG_KV_DIGIT_BUFF_WIDTH
    #   define LOG_KV_DIGIT_BUFF_WIDTH 17 // Default total 2^20 slots
    #endif
    #define KV_DIGIT_BUFF_WIDTH (1 << LOG_KV_DIGIT_BUFF_WIDTH)
    // |<-KV_DIGIT_BUFF_WIDTH->|
    //  +=====================+  
    //  |     Digit  0-7      | level0 
    //  |_____________________|         Packed digits,
    //  |     Digit  8-15     | level1  each uint32 contains
    //  |_____________________|         x4 8-bit digits,
    //  |     Digit 16-23     | level2  in total 4 layers
    //  |_____________________|         
    //  |     Digit 24-31     | level3
    //  |_____________________|
    #define KV_INDEX_BUFF_START (KV_DIGIT_BUFF_WIDTH << 2)
    //  +==================================================================+
    //  |           Slot-A    Sorted Indices by Radix Sort                 |
    //  +==================================================================+
    //  |           Slot-B    Sorted Indices by Radix Sort                 |
    //  +==================================================================+
    //  |<--KV_INDEX_BUFF_WIDTH ------------------------------------------>|
    #define KV_INDEX_BUFF_WIDTH (KV_DIGIT_BUFF_WIDTH << 2)
    #define LOG_KV_INDEX_BUFF_WIDTH (LOG_KV_DIGIT_BUFF_WIDTH + 2)

    // Addressing Macro(s) for Sorted Indices
    // ----------------------------------------------------
    // Index sub-buffer follows ping-pong fasion fo I/O ops
    // between consequtive radix sort passes.
    // We use an ioflag to indicate usages of each slot:
    // ioflag == 0: Slot-A is input(r), Slot-B is output(w)
    // ioflag == 1: Slot-A is output(r), Slot-B is input(w)
    #define INDEX_ADDR_R(index, ioflag) ( \
        (index + KV_INDEX_BUFF_START + KV_INDEX_BUFF_WIDTH * (ioflag)) \
    #define INDEX_ADDR_W(index, ioflag) ( \
        (index + KV_INDEX_BUFF_START + KV_INDEX_BUFF_WIDTH * ((ioflag) ^ 1)) \


    // Addressing Macro(s) for Morton Code Slices
    // ---------------------------------------------------------
    #define DIGIT_ADDR(level, viewVertex) ( \
        (viewVertex >> 2) + (level << LOG_KV_DIGIT_BUFF_WIDTH)) \


    uint SeparateBy1(uint x) {
        x &= 0x0000ffff;                  // x = ---- ---- ---- ---- fedc ba98 7654 3210
        x = (x ^ (x <<  8)) & 0x00ff00ff; // x = ---- ---- fedc ba98 ---- ---- 7654 3210
        x = (x ^ (x <<  4)) & 0x0f0f0f0f; // x = ---- fedc ---- ba98 ---- 7654 ---- 3210
        x = (x ^ (x <<  2)) & 0x33333333; // x = --fe --dc --ba --98 --76 --54 --32 --10
        x = (x ^ (x <<  1)) & 0x55555555; // x = -f-e -d-c -b-a -9-8 -7-6 -5-4 -3-2 -1-0
        return x;
    }

    uint MortonCode2(uint2 xy) {
        return SeparateBy1(xy.x) | (SeparateBy1(xy.y) << 1);
    }

    // Compact same-level digits from 4 input codes
    uint CompactDigits(uint digitLevel, uint4 input){
        //      Code          Digits 
        // C0 = input.x = [03 02 01 00]
        // C1 = input.y = [13 12 11 10]
        // C2 = input.z = [23 22 21 20]
        // C3 = input.w = [33 32 31 30]
        uint mask = 0x000000ff;
        input = input >> (digitLevel * 8);
        uint digits = (
            ((mask & input.w) << 24) | // [30 __ __ __]
            ((mask & input.z) << 16) | // [30 20 __ __]
            ((mask & input.y) << 8) |  // [30 20 10 __]
            ((mask & input.x))         // [30 20 10 00]
        );

        return digits;
    }

#endif /* CBUFFER_STRUCTUREDKEYVALUEPAIR_VIEW_INCLUDED */
