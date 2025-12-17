using UnityEngine;

public class AudioRaytrace : MonoBehaviour
{
    public ComputeShader computeShader;
    public RenderTexture renderTexture;
    private int kernelHandle;

void Start() {
    kernelHandle = computeShader.FindKernel("CSMain");

    renderTexture = new RenderTexture(1920, 1080, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear)
    {
        enableRandomWrite = true,
    };
    renderTexture.Create();

    computeShader.SetTexture(kernelHandle, "Result", renderTexture);
    computeShader.SetFloats("Resolution", renderTexture.width, renderTexture.height);
}

private void OnRenderImage(RenderTexture src, RenderTexture dest)
{
    computeShader.SetTexture(kernelHandle, "Camera", src);

    computeShader.Dispatch(kernelHandle,
        Mathf.CeilToInt(renderTexture.width / 8f),
        Mathf.CeilToInt(renderTexture.height / 8f),
        1);

    Graphics.Blit(renderTexture, dest);
}

}
