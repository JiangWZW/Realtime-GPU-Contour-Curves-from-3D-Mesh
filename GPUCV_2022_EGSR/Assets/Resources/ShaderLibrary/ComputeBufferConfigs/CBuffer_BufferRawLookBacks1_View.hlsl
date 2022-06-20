#ifndef CBUFFER_BUFFERRAWLOOKBACKS1_INCLUDED
#define CBUFFER_BUFFERRAWLOOKBACKS1_INCLUDED

#ifdef USE_LOOK_BACK_TABLE_KERNEL_SEGMENTVISIBILITY_DEPTHTEST
    //////////////////////////////////////////////////////
    #define MAX_LOOKBACKS 256
    // Setup for depth test kernel
    #define SEG_VISIBILITY_READY    1
    #define SEG_VISIBILITY_INVALID  0

    #define SEG_VISIBLE             1
    #define SEG_INVISIBLE           0

    #define SCAN_PREFIX_READY       2
    #define SCAN_AGGREGATE_READY    1
    #define SCAN_RES_INVALID        0       
    // Data layout:
    // [31, ..., 2]    [1]    [0]
    // [<-- 0s -->]  visible ready
    // Decoding
    #define VISIBILITY_LOOKBACK_OFFSET 0
    #define IS_SEG_VISIBILITY_READY(code) ((SEG_VISIBILITY_READY == ((code) & 1)))
    #define IS_SEG_VISIBILITY_INVALID(code) ((SEG_VISIBILITY_INVALID == ((code) & 1)))
    #define IS_SEG_VISIBLE(code) (SEG_VISIBLE == (((code) >> 1) & 1))

    // Data layout: (with offset)
    // [31, ..., ..., ..., ..., ...,2]    [1, 0]
    // [<-- per-block scan result -->]  scan state
    #define SCAN_LOOKBACK_OFFSET    VISIBILITY_LOOKBACK_OFFSET + MAX_LOOKBACKS
    #define IS_SCAN_NOT_READY(code) (((code) & 0x00000003) == 0)
    #define ENCODE_SCAN_DATA(flag, data) ((((data) << 2) | flag))
    #define DECODE_SCAN_DATA(code)  (((code) >> 2))

    // Encoding
    uint Encode_Seg_Visibility_Code(uint ready, uint visible){
        visible = visible << 1;
        return visible | ready;
    }
#endif /* USE_LOOK_BACK_TABLE_KERNEL_SEGMENTVISIBILITY_DEPTHTEST */

#endif /* CBUFFER_BUFFERRAWLOOKBACKS1_INCLUDED */
