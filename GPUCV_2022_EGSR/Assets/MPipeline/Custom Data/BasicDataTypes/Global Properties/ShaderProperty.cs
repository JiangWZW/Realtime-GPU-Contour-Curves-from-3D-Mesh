using UnityEngine;

namespace MPipeline.Custom_Data.BasicDataTypes.Global_Properties
{
    public struct ShaderProperty<T>
        where T : struct
    {
        public ShaderProperty(string name, T dataIn)
        {
            id = Shader.PropertyToID(name);
            data = dataIn;
        }
        public ShaderProperty(int idIn, T dataIn)
        {
            id = idIn;
            data = dataIn;
        }
        public void SetData(T dataIn)
        {
            data = dataIn;
        }
        public int id;
        public T data;
    }
}
