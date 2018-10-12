using UnityEngine;
using System.Collections;
 
public class FlyCamera : MonoBehaviour
{
	[SerializeField]
	Light	m_Sun;

    float mainSpeed = 2.0f;
    float shiftMul = 3.0f;
    float camSens = 0.25f;
    Vector3 lastMouse;

	private void Start ()
	{
		Reset();
	}

	private void Reset ()
	{
		lastMouse =  Input.mousePosition;
	}

	void Update ()
	{
		if (Input.GetMouseButtonDown(0) || Input.GetMouseButtonDown(1))
			Reset();

		if (Input.GetMouseButton(0) || Input.GetMouseButton(1))
		{
			var t = Input.GetMouseButton(0) ? m_Sun.transform : transform;

			lastMouse = Input.mousePosition - lastMouse;
			if (Input.GetMouseButton(0))
				lastMouse.y *= -1;
			lastMouse = new Vector3(-lastMouse.y * camSens, lastMouse.x * camSens, 0 );
			lastMouse = new Vector3(t.eulerAngles.x + lastMouse.x , t.eulerAngles.y + lastMouse.y, 0);
			t.eulerAngles = lastMouse;
			
			Cursor.visible = false;
			Cursor.lockState = CursorLockMode.Confined;
		}
		else
		{
			Cursor.visible = true;
			Cursor.lockState = CursorLockMode.None;
		}
        lastMouse =  Input.mousePosition;

		float speed = mainSpeed * (Input.GetKey(KeyCode.LeftShift) ? shiftMul : 1);
       
		if (Input.GetKey(KeyCode.W))
			transform.position += transform.forward * speed * Time.deltaTime;
		if (Input.GetKey(KeyCode.S))
			transform.position -= transform.forward * speed * Time.deltaTime;

		if (Input.GetKey(KeyCode.D))
			transform.position += transform.right * speed * Time.deltaTime;
		if (Input.GetKey(KeyCode.A))
			transform.position -= transform.right * speed * Time.deltaTime;

		if (Input.GetKey(KeyCode.E))
			transform.position += transform.up * speed * Time.deltaTime;
		if (Input.GetKey(KeyCode.Q))
			transform.position -= transform.up * speed * Time.deltaTime;
       
    }
}