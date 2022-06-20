namespace MPipeline.Custom_Data.BasicDataTypes.Global_Properties
{
    /// <summary>
    /// Descriptor used to initialize a ShaderProperty struct.
    /// </summary>
    public struct PropDescriptor
    {
        public PropDescriptor(string tag, int usage, int space = 0)
        {
            this.Tag = tag;
            this.Usage = usage;
            this.Space = space;
        }

        public string Tag { get; set; }
        public int Usage { get; set; }
        public int Space { get; set; }
    }
}