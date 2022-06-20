using UnityEngine.Rendering;

namespace Assets.MPipeline.SRP_Assets.Passes
{
    public interface ICommandBufferConnected
    {
        void ConnectToCmd(
            CommandBuffer cmd);

        void DisconnectCmd();
    }
}