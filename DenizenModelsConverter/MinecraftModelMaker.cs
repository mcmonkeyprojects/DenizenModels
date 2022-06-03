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
    public class MinecraftModelMaker
    {
        public static string CreateModelFor(BBModel model, BBModel.Outliner outline)
        {
            JObject jout = new(), textures = new(), group = new(), display = new(), head = new();
            JArray groups = new(), elements = new();
            JArray childrenList = new();
            int texId = 0;
            foreach (BBModel.Texture texture in model.Textures)
            {
                textures.Add((texId++).ToString(), texture.CorrectedFullPath);
                if (texture.Particle)
                {
                    textures.Add("particle", texture.CorrectedFullPath);
                }
            }
            int id = 0;
            bool any = false;
            foreach (BBModel.Element element in model.Elements)
            {
                if (outline.Children.Contains(element.UUID))
                {
                    any = true;
                    JObject jElement = new();
                    jElement.Add("name", element.Name);
                    jElement.Add("from", DVecToArray(element.From - outline.Origin));
                    jElement.Add("to", DVecToArray(element.To - outline.Origin));
                    JObject rotation = new();
                    rotation.Add("origin", DVecToArray(element.Origin - outline.Origin));
                    if (element.Rotation.X != 0)
                    {
                        rotation.Add("angle", element.Rotation.X);
                        rotation.Add("axis", "x");
                    }
                    else if (element.Rotation.Z != 0)
                    {
                        rotation.Add("angle", element.Rotation.Z);
                        rotation.Add("axis", "z");
                    }
                    else
                    {
                        rotation.Add("angle", element.Rotation.Y);
                        rotation.Add("axis", "y");
                    }
                    jElement.Add("rotation", rotation);
                    JObject faces = new();
                    faces.Add("north", FaceToJObj(element.North, model));
                    faces.Add("south", FaceToJObj(element.South, model));
                    faces.Add("east", FaceToJObj(element.East, model));
                    faces.Add("west", FaceToJObj(element.West, model));
                    faces.Add("up", FaceToJObj(element.Up, model));
                    faces.Add("down", FaceToJObj(element.Down, model));
                    jElement.Add("faces", faces);
                    elements.Add(jElement);
                    childrenList.Add(id++);
                }
            }
            if (!any)
            {
                return null;
            }
            group.Add("name", outline.Name);
            group.Add("origin", DVecToArray(outline.Origin));
            group.Add("color", 0);
            group.Add("children", childrenList);
            groups.Add(group);
            head.Add("translation", new JArray(8 * Program.SCALE, 3.75 * Program.SCALE, 8 * Program.SCALE));
            head.Add("scale", new JArray(Program.SCALE, Program.SCALE, Program.SCALE));
            display.Add("head", head);
            jout.Add("textures", textures);
            jout.Add("elements", elements);
            jout.Add("groups", groups);
            jout.Add("display", display);
            return jout.ToString();
        }

        public static JObject FaceToJObj(BBModel.Element.Face face, BBModel model)
        {
            float relativeU = 16f / model.ResolutionX;
            float relativeV = 16f / model.ResolutionY;
            JObject output = new();
            output.Add("uv", new JArray(face.TexCoord.ULow * relativeU, face.TexCoord.VLow * relativeV, face.TexCoord.UHigh * relativeU, face.TexCoord.VHigh * relativeV));
            output.Add("texture", $"#{face.TextureID}");
            return output;
        }

        public static JArray DVecToArray(DoubleVector dvec)
        {
            return new JArray(dvec.X, dvec.Y, dvec.Z);
        }
    }
}
