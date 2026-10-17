using System;

public class IVector2
{
	public int x;
	public int y;

	public IVector2(int x, int y)
	{
		this.x = x;
		this.y = y;
	}

	public IVector Scale(float s)
	{
		return new IVector2((int)(s * this.x), (int)(s * this.y));
	}

	public IVector RotateAcl(float angle)
	{
		float s = MathF.sin(angle);
		float c = MathF.cos(angle)

		return new IVector2((int)(this.x * c - this.y * s),
				    (int)(this.x * s + this.y * c));
	}

	public IVector RotateCl(float angle)
	{
		return RotateAcl(-angle);
	}
}
