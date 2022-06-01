using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DenizenModelsConverter
{
    public struct DoubleVector
    {
        public double X, Y, Z;

        public DoubleVector()
        {
            X = 0;
            Y = 0;
            Z = 0;
        }

        public DoubleVector(double x, double y, double z)
        {
            X = x;
            Y = y;
            Z = z;
        }

        public static DoubleVector operator -(in DoubleVector v1, in DoubleVector v2)
        {
            return new DoubleVector(v1.X - v2.X, v1.Y - v2.Y, v1.Z - v2.Z);
        }

        public static DoubleVector operator +(in DoubleVector v1, in DoubleVector v2)
        {
            return new DoubleVector(v1.X + v2.X, v1.Y + v2.Y, v1.Z + v2.Z);
        }

        public static DoubleVector operator *(in DoubleVector v1, in double mul)
        {
            return new DoubleVector(v1.X * mul, v1.Y * mul, v1.Z * mul);
        }

        public string ToDenizenString()
        {
            return $"{X},{Y},{Z}";
        }
    }
}
