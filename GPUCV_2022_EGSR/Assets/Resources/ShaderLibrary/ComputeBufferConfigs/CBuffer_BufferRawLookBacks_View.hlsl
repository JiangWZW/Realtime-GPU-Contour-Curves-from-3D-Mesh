#ifndef CBUFFER_BUFFERRAWLOOKBACKS_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWLOOKBACKS_VIEW_INCLUDED

#define LOOK_BACK_CAPACITY 2048
#define SUB_LOOKBACK_BUFF(i, offset) (((LOOK_BACK_CAPACITY * i + offset) << 2))
uint SubLookBackBuff(uint subbuff, uint offset){
    return (((LOOK_BACK_CAPACITY * subbuff) + offset) << 2);
}

#ifdef USE_LOOK_BACK_TABLE_KERNEL_SEGMENTSCAN
    /////////////////////////////////////////////////////
    // Default Setup for scan
    #define PREFIX_READY    2
    #define AGGREGATE_READY 1
    #define INVALID         0
    // Data layout:
    // [31, 30] [29, ..., 0]
    // [<flag>] [<- data ->]
    
    // Decoding
    #define DECODE_SCAN_LOOK_BACK_FLAG(code) ((code >> 30) & 3)
    #define DECODE_SCAN_LOOK_BACK_DATA(code) (code & 0x3fffffff)
    #define IS_INVALID_STATE(code) ((code & 0xc0000000) == 0)
    // Encoding
    #define ENCODE_SCAN_LOOK_BACK_CODE(flag, data) ((flag << 30) | (data & 0x3fffffff))
#endif /* USE_LOOK_BACK_TABLE_KERNEL_SEGMENTSCAN */


#ifdef USE_LOOK_BACK_TABLE_KERNEL_VEDGECOMPACTION
    /////////////////////////////////////////////////////
    // Default Setup for scan
    #define PREFIX_READY    2
    #define AGGREGATE_READY 1
    #define INVALID         0
    // Data layout:
    // [31, ..., 2]   [1, 0]
    // [<- data ->] [<-flag->]
    
    // Decoding
    #define DECODE_SCAN_LOOK_BACK_FLAG(code) (((code) & 3))
    #define DECODE_SCAN_LOOK_BACK_DATA(code) (((code) >> 2))
    #define IS_INVALID_STATE(code) ((DECODE_SCAN_LOOK_BACK_FLAG(code)) == (uint)INVALID)
    // Encoding
    #define ENCODE_SCAN_LOOK_BACK_CODE(flag, data) (((data) << 2) | (flag))
#endif /* USE_LOOK_BACK_TABLE_KERNEL_VEDGECOMPACTION */

#ifdef USE_LOOK_BACK_TABLE_KERNEL_STAMPPIXELEXTRACTION
    /////////////////////////////////////////////////////
    // Default Setup for scan
    #define PREFIX_READY    2
    #define AGGREGATE_READY 1
    #define INVALID         0
    // Data layout:
    // [31, ..., 2]   [1, 0]
    // [<- data ->] [<-flag->]
    
    // Decoding
    #define DECODE_SCAN_LOOK_BACK_FLAG(code) (((code) & 3))
    #define DECODE_SCAN_LOOK_BACK_DATA(code) (((code) >> 2))
    #define IS_INVALID_STATE(code) ((DECODE_SCAN_LOOK_BACK_FLAG(code)) == (uint)INVALID)
    // Encoding
    #define ENCODE_SCAN_LOOK_BACK_CODE(flag, data) (((data) << 2) | (flag))
#endif /* USE_LOOK_BACK_TABLE_KERNEL_STAMPPIXELEXTRACTION */


#ifdef USE_LOOK_BACK_TABLE_KERNEL_SELECTCIRCULARSTAMPS
    /////////////////////////////////////////////////////
    // Default Setup for scan
    #define PREFIX_READY    2
    #define AGGREGATE_READY 1
    #define INVALID         0
    // Data layout:
    // [31, ..., 2]   [1, 0]
    // [<- data ->] [<-flag->]
    
    // Decoding
    #define DECODE_SCAN_LOOK_BACK_FLAG(code) (((code) & 3))
    #define DECODE_SCAN_LOOK_BACK_DATA(code) (((code) >> 2))
    #define IS_INVALID_STATE(code) ((DECODE_SCAN_LOOK_BACK_FLAG(code)) == (uint)INVALID)
    // Encoding
    #define ENCODE_SCAN_LOOK_BACK_CODE(flag, data) (((data) << 2) | (flag))
#endif /* USE_LOOK_BACK_TABLE_KERNEL_SELECTCIRCULARSTAMPS */



#endif /* CBUFFER_BUFFERRAWLOOKBACKS_VIEW_INCLUDED */
