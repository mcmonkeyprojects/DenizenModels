using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DenizenModelsConverter
{
    public struct IntegerVector
    {
        public int X, Y, Z;

        public IntegerVector()
        {
            X = 0;
            Y = 0;
            Z = 0;
        }

        public IntegerVector(int x, int y, int z)
        {
            X = x;
            Y = y;
            Z = z;
        }
    }
}
