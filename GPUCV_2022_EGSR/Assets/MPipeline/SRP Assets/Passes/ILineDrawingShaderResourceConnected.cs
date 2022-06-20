using MPipeline.Custom_Data.PerCameraData;
using MPipeline.SRP_Assets.Passes;

namespace Assets.MPipeline.SRP_Assets.Passes
{
    public interface ILineDrawingShaderResourceConnected
    {
        void ConnectToLineDrawingResources(
            LineDrawingBuffers buffers = null,
            LineDrawingTextures textures = null);

        void DisconnectFromLineDrawingResources();
    }
}