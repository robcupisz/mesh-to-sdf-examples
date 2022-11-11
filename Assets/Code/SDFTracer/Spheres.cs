using UnityEngine;

[ExecuteAlways]
public class Spheres : MonoBehaviour
{
    public Transform m_AnimRef;
    Vector3 m_AnimRefPrev = Vector3.zero;

    [Range(0, 1)]
    public float m_JiggleForce = 0.1f;
    [Range(0, 1)]
    public float m_ReturnForce = 0.1f;
    [Range(0, 1)]
    public float m_Damping = 0.1f;
    public float m_DistanceFalloffMult = 1;
    public float m_DistanceFalloffPower = 1;

    Vector4[] m_Spheres;
    Vector3[] m_StartPositions;
    Vector3[] m_Velocities;

    public Vector4[] spheres { get { return m_Spheres; } }

    void OnEnable()
    {
        Transform t = transform;
        int count = t.childCount;
        m_Spheres = new Vector4[count];
        m_StartPositions = new Vector3[count];
        m_Velocities = new Vector3[count];

        for (int i = 0; i < count; i++)
        {
            Transform sphereTransform = t.GetChild(i);
            Vector3 p = sphereTransform.position;
            m_Spheres[i] = new Vector4(p.x, p.y, p.z, sphereTransform.localScale.x * 0.5f);
            m_StartPositions[i] = p;
            m_Velocities[i] = Vector3.zero;
        }

        m_AnimRefPrev = m_AnimRef.position;
    }

    void Update()
    {
        Vector3 refPos = m_AnimRef.position;
        Vector3 jiggleForce = (refPos - m_AnimRefPrev) * m_JiggleForce;

        for (int i = 0; i < m_Spheres.Length; i++)
        {
            Vector4 sphere = m_Spheres[i];
            Vector3 pos = new Vector3(sphere.x, sphere.y, sphere.z);
            Vector3 v = m_Velocities[i];
            float falloff = Mathf.Pow(m_DistanceFalloffMult / ((pos - refPos).magnitude + 0.1f), m_DistanceFalloffPower);

            v += jiggleForce * falloff;
            v += (m_StartPositions[i] - pos) * m_ReturnForce;
            v *= 1 - m_Damping;
            pos += v;

            sphere.x = pos.x;
            sphere.y = pos.y;
            sphere.z = pos.z;
            m_Spheres[i] = sphere;
            m_Velocities[i] = v;
        }

        m_AnimRefPrev = refPos;
    }
}
