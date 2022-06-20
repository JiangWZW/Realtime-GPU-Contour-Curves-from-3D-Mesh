#ifndef CBUFFER_DISPATCHINDIRECTARGS_VIEW_INCLUDED
#define CBUFFER_DISPATCHINDIRECTARGS_VIEW_INCLUDED

    #define ComputeNumGroups(workScale, groupSize, groupSizeBits) \
        (max(1, (workScale + groupSize - 1) >> groupSizeBits)) \

#endif /* CBUFFER_DISPATCHINDIRECTARGS_VIEW_INCLUDED */
