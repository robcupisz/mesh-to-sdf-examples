using UnityEngine;

[ExecuteAlways]
public class SDFTracer : MonoBehaviour
{
    public SDFTexture m_SDFTexture;
    public Transform m_Box;
    public Spheres m_Spheres;
    [Range(0, 1)]
    public float m_Margin = 0.0f;
    public int m_Seed = 0;
    public float m_SphereRadius = 0.15f;
    public float m_BlendDistance = 0.08f;
    MeshRenderer m_MeshRenderer;
    MaterialPropertyBlock m_Props;

    public enum Mode
    {
        Box,
        Spheres
    }

    public Mode m_Mode = Mode.Box;

    [Header("Shading")]
    public Light m_Light;
    [ColorUsage(showAlpha: false)]
    public Color m_Ambient = Color.black;
    [ColorUsage(showAlpha: false)]
    public Color m_Albedo = Color.white;
    [ColorUsage(showAlpha: false, hdr: true)]
    public Color m_Sky = Color.white;

    [Header("Sky scatter")]
    public float m_ScatterAmount = 1.0f;
    public float m_ScatterStart = 0.05f;
    public int m_ScatterIterations = 100;
    public float m_ScatterMaxDepth = 1.0f;

    [Header("Directional scatter")]
    public float m_DirScatterAmount = 1.0f;
    public float m_ExtinctionCoeff = 1.0f;
    [Range(0, 1)]
    public float m_Anisotropy = 0.5f;
    public int m_DirScatterIterations = 20;
    public int m_DirScatterIterationsSecondary = 10;

    ComputeBuffer m_SpheresCB;
    Vector4[] m_SpheresData;

    static class Uniforms
    {
        internal static int _Color = Shader.PropertyToID("_Color");
        internal static int _BoxSize = Shader.PropertyToID("_BoxSize");
        internal static int _BoxPos = Shader.PropertyToID("_BoxPos");
        internal static int _WorldToSDFSpace = Shader.PropertyToID("_WorldToSDFSpace");
        internal static int _SDF = Shader.PropertyToID("_SDF");
        internal static int _Margin = Shader.PropertyToID("_Margin");
        internal static int _ScatterParams = Shader.PropertyToID("_ScatterParams");
        internal static int _LightColor = Shader.PropertyToID("_LightColor");
        internal static int _LightDir = Shader.PropertyToID("_LightDir");
        internal static int _Ambient = Shader.PropertyToID("_Ambient");
        internal static int _Albedo = Shader.PropertyToID("_Albedo");
        internal static int _Sky = Shader.PropertyToID("_Sky");
        internal static int _DirScatterAmount = Shader.PropertyToID("_DirScatterAmount");
        internal static int _DirScatterMaxIterations = Shader.PropertyToID("_DirScatterMaxIterations");
        internal static int _DirScatterMaxIterationsSecondary = Shader.PropertyToID("_DirScatterMaxIterationsSecondary");
        internal static int _ExtinctionCoeff = Shader.PropertyToID("_ExtinctionCoeff");
        internal static int _Anisotropy = Shader.PropertyToID("_Anisotropy");
        internal static int _Spheres = Shader.PropertyToID("_Spheres");
        internal static int _BlendDistance = Shader.PropertyToID("_BlendDistance");
        internal static int _Mode = Shader.PropertyToID("_Mode");
    }

    void OnValidate()
    {
        m_ScatterAmount = Mathf.Max(m_ScatterAmount, 0.0f);
        m_ScatterStart = Mathf.Max(m_ScatterStart, 0.0001f);
        m_ScatterIterations = Mathf.Max(m_ScatterIterations, 10);
        m_ScatterMaxDepth = Mathf.Max(m_ScatterMaxDepth, 0.1f);

        m_DirScatterAmount = Mathf.Max(m_DirScatterAmount, 0.0f);
        m_ExtinctionCoeff = Mathf.Max(m_ExtinctionCoeff, 0.0f);
    }

    void Start()
    {
        m_MeshRenderer = GetComponent<MeshRenderer>();
    }

    void Update()
    {
        if (m_SDFTexture == null || m_SDFTexture.mode == SDFTexture.Mode.None)
            return;

        if (m_Props == null)
            m_Props = new MaterialPropertyBlock();

        m_Props.Clear();
        m_Props.SetColor(Uniforms._Color, Color.red);
        m_Props.SetVector(Uniforms._BoxSize, m_Box.transform.localScale * 0.5f);
        m_Props.SetVector(Uniforms._BoxPos, m_Box.transform.position);

        m_Props.SetMatrix(Uniforms._WorldToSDFSpace, m_SDFTexture.worldToSDFTexCoords);
        m_Props.SetTexture(Uniforms._SDF, m_SDFTexture.sdf);
        m_Props.SetFloat(Uniforms._Margin, m_Margin * m_SDFTexture.voxelBounds.size.magnitude);

        m_Props.SetVector(Uniforms._ScatterParams, new Vector4(m_ScatterAmount * 50.0f, m_ScatterStart, m_ScatterMaxDepth/(float)m_ScatterIterations, m_ScatterMaxDepth));
        m_Props.SetVector(Uniforms._LightColor, m_Light.color);
        Transform lightTransform = m_Light.transform;
        Vector4 lightDirPos = lightTransform.forward;

        // TODO: proper support for non-directional light types
        if (m_Light.type != LightType.Directional)
            lightDirPos = (transform.position - m_Light.transform.position).normalized;
        
        m_Props.SetVector(Uniforms._LightDir, lightDirPos);
        m_Props.SetColor(Uniforms._Ambient, m_Ambient);
        m_Props.SetColor(Uniforms._Albedo, m_Albedo);
        m_Props.SetColor(Uniforms._Sky, m_Sky);
        m_Props.SetFloat(Uniforms._DirScatterAmount, m_DirScatterAmount * 0.001f);
        m_Props.SetInt(Uniforms._DirScatterMaxIterations, m_DirScatterIterations);
        m_Props.SetInt(Uniforms._DirScatterMaxIterationsSecondary, m_DirScatterIterationsSecondary);
        m_Props.SetFloat(Uniforms._ExtinctionCoeff, m_ExtinctionCoeff);
        m_Props.SetFloat(Uniforms._Anisotropy, Mathf.Min(m_Anisotropy, 0.99f));
        m_Props.SetFloat(Uniforms._BlendDistance, m_BlendDistance);
        m_Props.SetInt(Uniforms._Mode, (int)m_Mode);

        Vector4[] spheres = m_Spheres.spheres;

        if (spheres != null && spheres.Length > 0)
        {
            CreateComputeBuffer(ref m_SpheresCB, spheres.Length, 4 * sizeof(float));
            m_SpheresCB.SetData(spheres);
            m_Props.SetBuffer(Uniforms._Spheres, m_SpheresCB);
        }

        m_MeshRenderer.SetPropertyBlock(m_Props);
    }

    void OnDestroy()
    {
        ReleaseComputeBuffer(m_SpheresCB);
    }

    static void CreateComputeBuffer(ref ComputeBuffer cb, int length, int stride)
    {
        if (cb != null && cb.count == length && cb.stride == stride)
            return;

        ReleaseComputeBuffer(cb);
        cb = new ComputeBuffer(length, stride);
    }

    static void ReleaseComputeBuffer(ComputeBuffer cb)
    {
        if (cb != null)
            cb.Release();
    }

#if UNITY_EDITOR
    void OnEnable() => UnityEditor.AssemblyReloadEvents.beforeAssemblyReload += OnBeforeAssemblyReload; 
    void OnDisable() => UnityEditor.AssemblyReloadEvents.beforeAssemblyReload -= OnBeforeAssemblyReload;
    void OnBeforeAssemblyReload() => OnDestroy();
#endif
}
