using UnityEngine;
using System.Collections;
using System.Collections.Generic;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
[AddComponentMenu("Effects/SDFGI")]
public class SDFGI : SceneViewFilter
{
    [SerializeField]
    private Shader _EffectShader;
	[SerializeField]
	Light			m_Sun;
	[SerializeField] [Range(0, 16)]
	float			m_SunSize;
	[SerializeField]
	ReflectionProbe	m_ReflectionProbe;
	[Header("Camera Parameters")]
	[SerializeField]
	float			m_LensWidth = 0.5f;
	[SerializeField]
	float			m_LensDistance = 0.25f;
	[SerializeField] [Range(0, 1)]
	float			m_Aperture;
	[SerializeField]
	bool			m_ShouldReset;
	

	Vector3			m_CameraPrevPos;
	Quaternion		m_CameraPrevRot;
	float			m_SunPrevIntensity;
	Color			m_SunPrevColor;
	Vector3			m_SunPrevDir;
	Vector4			m_PrevCameraParams;
	float			m_SunPrevSize;

	RenderTexture	m_Render;

	int				m_IntegrationCount;

	private void Start ()
	{
		Application.targetFrameRate = 9999;
	}

	private void OnValidate ()
	{
		m_ShouldReset = true;
	}

	public Material EffectMaterial
    {
        get
        {
            if (!_EffectMaterial && _EffectShader)
            {
                _EffectMaterial = new Material(_EffectShader);
                _EffectMaterial.hideFlags = HideFlags.HideAndDontSave;
            }

            return _EffectMaterial;
        }
    }
    private Material _EffectMaterial;

    public Camera currentCamera
    {
        get
        {
            if (!_CurrentCamera)
                _CurrentCamera = GetComponent<Camera>();
            return _CurrentCamera;
        }
    }
    private Camera _CurrentCamera;

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!EffectMaterial)
        {
            Graphics.Blit(source, destination); // do nothing
            return;
        }

		var cameraParams = new Vector4(currentCamera.sensorSize.x, currentCamera.sensorSize.y, currentCamera.focalLength, m_Aperture);

		if (currentCamera.transform.position != m_CameraPrevPos ||
			currentCamera.transform.rotation != m_CameraPrevRot ||
			m_Render == null ||
			m_Render.width  != destination.width ||
			m_Render.height != destination.height ||
			m_ShouldReset ||
			m_Sun.intensity != m_SunPrevIntensity ||
			m_Sun.color != m_SunPrevColor ||
			m_Sun.transform.forward != m_SunPrevDir || 
			cameraParams != m_PrevCameraParams ||
			m_SunSize != m_SunPrevSize)
		{
			// Reset renderer
			//Debug.Log("Resetting renderer...");

			if (m_Render == null ||
				m_Render.width  != destination.width ||
				m_Render.height != destination.height)
			{
				m_Render = new RenderTexture(destination.width, destination.height, 0, RenderTextureFormat.ARGBFloat);
			}

			m_CameraPrevPos = currentCamera.transform.position;
			m_CameraPrevRot = currentCamera.transform.rotation;

			m_SunPrevIntensity = m_Sun.intensity;
			m_SunPrevColor = m_Sun.color;
			m_SunPrevDir = m_Sun.transform.forward;
			m_SunPrevSize = m_SunSize;

			m_PrevCameraParams = cameraParams;

			m_IntegrationCount = 0;

			m_ShouldReset = false;
		}

		if (m_Sun)
		{
			Vector3 sunColor = new Vector3(m_Sun.color.r, m_Sun.color.g, m_Sun.color.b) * m_Sun.intensity;
			EffectMaterial.SetVector("_SunColor",	sunColor);
			EffectMaterial.SetVector("_SunDir",		m_Sun.transform.forward);
			EffectMaterial.SetFloat("_SunSize",		m_SunSize);
		}

		if (m_ReflectionProbe)
		{
			m_ReflectionProbe.RenderProbe();
			EffectMaterial.SetTexture("_IBLTex", m_ReflectionProbe.texture);
		}
		
		EffectMaterial.SetVector("_CameraRight",	currentCamera.transform.right);
		EffectMaterial.SetVector("_CameraUp",		currentCamera.transform.up);
		EffectMaterial.SetVector("_CameraForward",	currentCamera.transform.forward);
		EffectMaterial.SetVector("_CameraParams",	cameraParams);
		EffectMaterial.SetFloat("_IntegrationCount", m_IntegrationCount);

		EffectMaterial.SetVector("_Random", new Vector4(Random.Range(-1f, 1f), Random.Range(-1f, 1f), Random.Range(-1f, 1f), Random.Range(-1f, 1f)));

		Graphics.Blit(source, m_Render, EffectMaterial, 0);

		m_IntegrationCount++;

        Graphics.Blit(m_Render, destination);
    }
}