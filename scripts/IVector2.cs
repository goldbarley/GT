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

    public void Set(int x, int y)
    {
        this.x = x;
        this.y = y;
    }

    public void Scale(int s)
    {
        this.x *= s;
        this.y *= s;
    }

    public void RotateAcl(float angle)
    {
        float s = MathF.Sin(angle);
        float c = MathF.Cos(angle);

        int ogx = this.x;
        int ogy = this.y;

        this.x = (int)MathF.Round(ogx * c - ogy * s);
        this.y = (int)MathF.Round(ogx * s + ogy * c);
    }

    public void RotateCl(float angle)
    {
        RotateAcl(-angle);
    }
}
