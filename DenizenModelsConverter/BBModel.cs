using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using FreneticUtilities.FreneticExtensions;
using FreneticUtilities.FreneticToolkit;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DenizenModelsConverter
{
    public class BBModel
    {
        public JObject JsonRoot;

        public string Name;

        public string FormatVersion;

        public int ResolutionX, ResolutionY;

        public DateTimeOffset CreationTime;

        public List<Element> Elements = new();

        public List<Texture> Textures = new();

        public List<Animation> Animations = new();

        public List<Outliner> Outlines = new();

        public HashSet<Guid> DiscardedIDs = new();

        public Element GetElement(Guid id)
        {
            return Elements.FirstOrDefault(e => e.UUID == id);
        }

        public class Element
        {
            public string Name;

            public DoubleVector From, To, Origin, Rotation;

            public string Type;

            public Guid UUID;

            public bool Locked, Rescale;

            public int AutoUV, Color;

            public Face North, South, East, West, Up, Down;

            public Outliner Outline;

            public class Face
            {
                public int TextureID;

                public UV TexCoord;

                public class UV
                {
                    public float ULow, UHigh, VLow, VHigh;
                }
            }
        }

        public class Texture
        {
            public string Path, Name, Folder, Namespace, ID, RenderMode, Mode;

            public bool Particle, Visible = true;

            public Guid UUID;

            public byte[] RawImageBytes;

            public string CorrectedFullPath;
        }

        public class Outliner
        {
            public string Name;

            public DoubleVector Origin;

            public DoubleVector Rotation;

            public Guid UUID;

            public List<Guid> Children = new();

            public Guid? Parent;
        }

        public class Animation
        {

            public Guid UUID;

            public string Name;

            public enum LoopType
            {
                LOOP,
                ONCE,
                HOLD
            }

            public LoopType Loop;

            public bool Override;

            public string AnimTimeUpdate, BlendWeight;

            public double Length;
            
            public int Snapping;

            public List<Animator> Animators = new();

            public class Animator
            {
                public Guid UUID;

                public string Name;

                public List<Keyframe> Keyframes = new();
            }

            public class Keyframe
            {
                public enum ChannelType
                {
                    POSITION,
                    ROTATION
                }

                public ChannelType Channel;

                public DoubleVector DataPoint;

                public Guid UUID;

                public double Time;

                public int Color;

                public enum InterpolationType
                {
                    LINEAR,
                    CATMULLROM, // AKA "Smooth"
                    STEP
                }

                public InterpolationType Interpolation;
            }
        }
    }
}
