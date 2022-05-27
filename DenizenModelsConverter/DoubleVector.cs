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
    }
}
