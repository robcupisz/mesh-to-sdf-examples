using UnityEngine;

[ExecuteAlways]
public class SDFDeform : MonoBehaviour
{
    public SDFTexture m_SDFTexture;
    [Min(0)]
    public float m_Margin = 0.3f;
    Renderer m_Renderer;
    MaterialPropertyBlock m_Props;

    static class Uniforms
    {
        internal static int _SDF = Shader.PropertyToID("_SDF");
        internal static int _WorldToSDF = Shader.PropertyToID("_WorldToSDF");
        internal static int _Margin = Shader.PropertyToID("_Margin");
    }

    void Update()
    {
        if (m_SDFTexture == null)
            return;
        
        if (m_Renderer == null)
            m_Renderer = GetComponent<Renderer>();

        if (m_Props == null)
            m_Props = new MaterialPropertyBlock();
        
        m_Props.Clear();
        m_Props.SetTexture(Uniforms._SDF, m_SDFTexture.sdf);
        m_Props.SetMatrix(Uniforms._WorldToSDF, m_SDFTexture.worldToSDFTexCoords);
        m_Props.SetFloat(Uniforms._Margin, m_Margin);
        m_Renderer.SetPropertyBlock(m_Props);
    }
}
