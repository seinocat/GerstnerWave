using System;
using UnityEngine;
using UnityEngine.Rendering;

public class Bloom : PostProcessBase
{
        public Shader BloomShader;

        private Material BloomMaterial;

        public Material material => this.CreateMaterial(BloomShader, BloomMaterial);
        
        //高斯模糊迭代次数
        [Range(0, 4)]
        public int iterations = 3;

        //模糊范围取值
        [Range(0.2f, 3.0f)]
        public float blurSpread = 0.6f;

        
        [Range(1, 3)]
        public int downSample = 2;

        //亮度阈值
        [Range(0.0f, 4.0f)]
        public float luminanceThreshold = 0.6f;


        private CommandBuffer cmd;

        private int LuminanceRT = Shader.PropertyToID("Luminance");
        
        internal static readonly int BlurOffset = Shader.PropertyToID("_Offset");
        internal static readonly int BufferRT1 = Shader.PropertyToID("_BufferRT1");
        internal static readonly int BufferRT2 = Shader.PropertyToID("_BufferRT2");

        private void Awake()
        { 
             cmd = new CommandBuffer();
        }

        
        
        private void OnRenderImage(RenderTexture src, RenderTexture dest)
        {
            if (material != null)
            {
                material.SetFloat(BlurOffset, blurSpread);
                int rWidth = src.width / downSample;
                int rHeight = src.height / downSample;
                RenderTextureDescriptor RTDescripotr =
                    new RenderTextureDescriptor(rWidth, rHeight, RenderTextureFormat.ARGB32, 0);

                var rt1 = RenderTexture.GetTemporary(RTDescripotr);
                
                Graphics.Blit(src, rt1);

                for (int i = 0; i < this.iterations; i++)
                {
                    var rt2 = RenderTexture.GetTemporary(RTDescripotr);
                    Graphics.Blit(rt1, rt2, material, 0);
                    rt1 = rt2;
                }
                
                Graphics.Blit(rt1, dest);
                // RenderTextureDescriptor RTDescripotr =
                //     new RenderTextureDescriptor(rWidth, rHeight, RenderTextureFormat.ARGB32, 0);
                // cmd.GetTemporaryRT(LuminanceRT, RTDescripotr);
                // cmd.GetTemporaryRT(BufferRT1, RTDescripotr);
                // cmd.GetTemporaryRT(BufferRT2, RTDescripotr);
                //
                //
                // RenderTargetIdentifier lastDown = src;
                // for (int i = 0; i < this.iterations; i++)
                // {
                //     cmd.Blit(lastDown, BufferRT1, material, 0);
                //     lastDown = BufferRT1;
                //     rWidth = Mathf.Max(rWidth / 2, 1);
                //     rHeight = Mathf.Max(rHeight / 2, 1);
                // }
                //
                // cmd.Blit(lastDown, dest);
            }
        }
}