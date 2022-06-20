namespace MPipeline.Custom_Data.HLSL_Data_Types
{
    public interface IConstantBufferDataType
    {
        void Stride();
    }

    public struct CompactionConstants : IStructuredDataType
    {
        public int Stride()
        {
            return 4 + 4;
        }
        
        public uint GroupCount;
        public uint GroupCountRemainder;
    }
}