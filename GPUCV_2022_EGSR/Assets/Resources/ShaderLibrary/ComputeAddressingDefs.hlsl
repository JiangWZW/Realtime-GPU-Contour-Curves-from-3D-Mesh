#ifndef COMPUTE_ADDRESSING_DEFS_INCLUDED
    #define COMPUTE_ADDRESSING_DEFS_INCLUDED

    // Byte Addressing Utilities -----------------------------------
    #define BITS_PER_BYTE 8

    #define BYTES_PER_WORD 4
    #define BITS_PER_WORD (BITS_PER_BYTE * BYTES_PER_WORD)
    #define BITS_WORD_OFFSET 2

    #define WORDS_PER_DWORD 2
    #define BITS_DWORD_OFFSET 3

    #define WORDS_PER_BLOCK 4
    #define BYTES_PER_BLOCK (BYTES_PER_WORD * WORDS_PER_BLOCK)
    #define BITS_PER_BLOCK (BITS_PER_WORD * WORDS_PER_BLOCK)
    #define BITS_BLOCK_OFFSET 4

    #define BLOCKS_PER_CHUNK 2
    #define WORDS_PER_CHUNK (WORDS_PER_BLOCK * BLOCKS_PER_CHUNK)
    #define BYTES_PER_CHUNK (BYTES_PER_BLOCK * BLOCKS_PER_CHUNK)
    #define BITS_PER_CHUNK (BITS_PER_BLOCK * BLOCKS_PER_CHUNK)
    #define BITS_CHUNK_OFFSET 5

    #define MOVE_ADDR_WORD(addr) (addr += BYTES_PER_WORD)
    #define MOVE_ADDR_BLOCK(addr) (addr += BYTES_PER_BLOCK)
    #define MOVE_ADDR_CHUNK(addr) (addr += BYTES_PER_CHUNK)
    
    uint MoveAddrSingleWord(uint addr){
        return addr + BYTES_PER_WORD;
    }
    uint MoveAddrSingleBlock(uint addr){
        return addr + BYTES_PER_BLOCK;
    }
    uint MoveAddrSingleChunk(uint addr){
        return addr + BYTES_PER_CHUNK;
    }

    uint MoveAddrByWord(uint addr, uint steps){
        return addr + (BYTES_PER_WORD * steps);
    }
    uint MoveAddrByBlock(uint addr, uint steps){
        return addr + (BYTES_PER_BLOCK * steps);
    }
    uint MoveAddrByChunk(uint addr, uint steps){
        return addr + (BYTES_PER_CHUNK * steps);
    }


#endif