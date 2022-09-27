using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Blur : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        
        Material m_Mat = new Material(Shader.Find("ShaderLib/DualBlur"));
        
        //当前阶段渲染的颜色RT
        RenderTargetIdentifier m_Source;

        //辅助RT
        RenderTargetHandle m_TemporaryColorTexture;

        //Profiling上显示
        ProfilingSampler m_ProfilingSampler = new ProfilingSampler("URPTest");
 
        
        private int Interation;

        private int downsample;
        
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get("CmdBlur");
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                int tw = renderingData.cameraData.cameraTargetDescriptor.width / this.downsample;
                int th = renderingData.cameraData.cameraTargetDescriptor.height / this.downsample;
                
                RenderTextureDescriptor RTDescripotr = renderingData.cameraData.cameraTargetDescriptor;
                RTDescripotr.depthBufferBits = 0;
                RTDescripotr.width = tw;
                RTDescripotr.height = th;

                RenderTargetIdentifier lastDown = m_Source;
                
                // int down0 = Shader.PropertyToID("Test_0");
                // int down1 = Shader.PropertyToID("Test_1");
                // int down2 = Shader.PropertyToID("Test_2");
                //
                // int[] downs = new int[3] { down0, down1, down2 };
                //
                // int up0 = Shader.PropertyToID("up_0");
                // int up1 = Shader.PropertyToID("up_1");
                // int up2 = Shader.PropertyToID("up_2");
                // int[] ups = new int[3] { up0, up1, up2 };
                //
                // for (int i = 0; i < this.Interation; i++)
                // {
                //     cmd.GetTemporaryRT(downs[i], RTDescripotr, FilterMode.Bilinear);
                //     cmd.GetTemporaryRT(ups[i], RTDescripotr, FilterMode.Bilinear);
                //     Blit(cmd, lastDown, downs[i], m_Mat);
                //     lastDown = downs[i];
                //     RTDescripotr.width = Mathf.Max(1, RTDescripotr.width / 2);
                //     RTDescripotr.height = Mathf.Max(1, RTDescripotr.height / 2);
                // }
                //
                // for (int i = this.Interation - 1; i >= 0; i--)
                // {
                //     Blit(cmd, lastDown, ups[i], m_Mat);
                //     lastDown = ups[i];
                // }
                
                for (int i = 0; i < this.Interation; i++)
                {
                    var rt = Shader.PropertyToID($"Teset{i}");
                    cmd.GetTemporaryRT(rt, RTDescripotr, FilterMode.Bilinear);
                    Blit(cmd, lastDown, rt, m_Mat);
                    lastDown = rt;
                    var rt1 = Shader.PropertyToID($"Tesetss{i}");
                    cmd.GetTemporaryRT(rt1, RTDescripotr, FilterMode.Bilinear);
                    Blit(cmd, lastDown, rt1, m_Mat, 1);
                    lastDown = rt1;
                }
                
                Blit(cmd, lastDown, m_Source);
            }
            
            context.ExecuteCommandBuffer(cmd);
            
            CommandBufferPool.Release(cmd);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            // base.FrameCleanup(cmd);
            //销毁创建的RT
            // cmd.ReleaseTemporaryRT(m_TemporaryColorTexture.id);
        }

        public void SetUp(RenderTargetIdentifier src, float contranst, float saturate, float brightness, float Offset, int Interation, int Downsample)
        {
            m_Source = src;
            m_Mat.SetFloat("_brightness", brightness);
            m_Mat.SetFloat("_saturate", saturate);
            m_Mat.SetFloat("_contranst", contranst);
            m_Mat.SetFloat("_Offset", Offset);
            this.Interation = Interation;
            this.downsample = Downsample;
            // m_Mat.SetFloat("_Offset", offset);
        }
    }

    CustomRenderPass m_ScriptablePass;

    public Color m_Color = Color.red;
    public float contranst;
    public float saturate;
    public float brightness;
    public float Offset;
    [Range(1, 3)]
    public int Interation = 1;
    [Range(1, 8)]
    public int DownSample = 1;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.SetUp(renderer.cameraColorTarget, contranst, saturate, brightness, Offset, Interation, DownSample);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


