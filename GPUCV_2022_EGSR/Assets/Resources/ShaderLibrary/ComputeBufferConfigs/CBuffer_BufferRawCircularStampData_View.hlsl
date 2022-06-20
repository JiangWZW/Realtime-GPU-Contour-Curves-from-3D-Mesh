#ifndef CBUFFER_BUFFERRAWCIRCULARSTAMPDATA_VIEW_INCLUDED
#define CBUFFER_BUFFERRAWCIRCULARSTAMPDATA_VIEW_INCLUDED

    #include "../ComputeAddressingDefs.hlsl"
    #include "../CustomShaderInputs.hlsl"

    #define LINKAGE_BUFFER_SIZE ((2 * MAX_CIRCULAR_STAMP_COUNT) << BITS_BLOCK_OFFSET)
    uint CBuffer_BufferRawCircularStampLinkage_AddrAt(uint subbuff, uint id){
        return (((MAX_CIRCULAR_STAMP_COUNT * subbuff + id) << BITS_BLOCK_OFFSET));
    }

    #define STAMP_TO_CIRCULAR_BUFFER_SIZE ((MAX_STAMP_COUNT << BITS_WORD_OFFSET))
    #define STAMP_TO_CIRCULAR_BUFFER_ADDR ((LINKAGE_BUFFER_SIZE))
    uint CBuffer_BufferRawStampToCircularStamp_AddrAt(uint id){
        return 
        (
            STAMP_TO_CIRCULAR_BUFFER_ADDR + 
            (id << BITS_WORD_OFFSET)
        );
    }

    #define CIRCULAR_TO_STAMP_BUFFER_SIZE (MAX_CIRCULAR_STAMP_COUNT << BITS_WORD_OFFSET)
    #define CIRCULAR_TO_STAMP_BUFFER_ADDR (STAMP_TO_CIRCULAR_BUFFER_ADDR + STAMP_TO_CIRCULAR_BUFFER_SIZE) 
    uint CBuffer_BufferRawCircularStampToStamp_AddrAt(uint id){
        return 
        (
            CIRCULAR_TO_STAMP_BUFFER_ADDR + 
            (id << BITS_WORD_OFFSET)
        );
    }

    #include "./CBuffer_BufferRawStampLinkage_View.hlsl"

    LinkDataRT CircularStampPointerJumping_Dbg(
        uint stampId, uint StampCount, uint pingpongFlag, 
        RWByteAddressBuffer LinkageBuffer,
        out bool isRedundant
    )
    {
        LinkDataRT link = ExtractLinkage(
            LinkageBuffer.Load4(
                CBuffer_BufferRawCircularStampLinkage_AddrAt(
                    pingpongFlag, stampId)));
        LinkDataRT linkNew = link; 

        // If this pixel is deleted in previous thinning passes,
        isRedundant = (link.link0 == NULL_STAMP_LINKPTR);
        // or this thread is a "trash thread", just ignore it;
        isRedundant = (stampId >= StampCount) || isRedundant;

        LinkDataRT link0 = ExtractLinkage(
            LinkageBuffer.Load4(
                CBuffer_BufferRawCircularStampLinkage_AddrAt(
                    pingpongFlag, link.link0)));

        bool isStrokeEnd = (link0.link0 == link.link0 || link0.link1 == link.link0);
        bool updateAt0   = (link0.link0 != stampId);

        linkNew.link0 = isStrokeEnd ? link.link0 : (updateAt0 ? link0.link0 : link0.link1);
        linkNew.rank0 += isStrokeEnd ?         0 : (updateAt0 ? link0.rank0 : link0.rank1);
        linkNew.maxID = max(linkNew.maxID, link0.maxID);

        LinkDataRT link1 = 
            ExtractLinkage(LinkageBuffer.Load4(
                CBuffer_BufferRawCircularStampLinkage_AddrAt(
                    pingpongFlag, link.link1)));

        isStrokeEnd = (link1.link0 == link.link1 || link1.link1 == link.link1);
        updateAt0 = (link1.link0 != stampId);
        linkNew.link1 = isStrokeEnd ? link.link1 : (updateAt0 ? link1.link0 : link1.link1);
        linkNew.rank1 += isStrokeEnd ?         0 : (updateAt0 ? link1.rank0 : link1.rank1);
        linkNew.maxID = max(linkNew.maxID, link1.maxID);

    
        LinkageBuffer.Store4(
            CBuffer_BufferRawCircularStampLinkage_AddrAt(
                (pingpongFlag + 1) % 2, stampId
            ),
            isRedundant ? PackLinkageRT(link) : PackLinkageRT(linkNew)
        );

        return linkNew;
    }
#endif /* CBUFFER_BUFFERRAWCIRCULARSTAMPDATA_VIEW_INCLUDED */
