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
    public static class BBModelReader
    {
        public static bool Verbose = false;

        public static void Debug(string text)
        {
            if (Verbose)
            {
                Console.WriteLine($"[Debug] {text}");
            }
        }

        public static BBModel Interpret(string fileContent)
        {
            Debug("Start read...");
            JObject data = JObject.Parse(fileContent);
            Debug("Parsed! Start proc...");
            JObject meta = data["meta"] as JObject;
            BBModel result = new()
            {
                JsonRoot = data,
                Name = (string)data.GetRequired("name"),
                FormatVersion = (string)meta.GetRequired("format_version"),
                CreationTime = DateTimeOffset.FromUnixTimeSeconds((long)meta.GetRequired("creation_time")).ToLocalTime()
            };
            Debug("Core read, start body...");
            JArray elements = (JArray)data["elements"];
            JArray textures = (JArray)data["textures"];
            JArray animations = (JArray)data["animations"];
            if (elements is not null)
            {
                Debug("Contains elements");
                foreach (JObject jElement in elements)
                {
                    JObject jFaces = (JObject)jElement["faces"];
                    string name = (string)jElement.GetRequired("name");
                    string type = jElement.GetString("type", "cube");
                    if (type != "cube")
                    {
                        Debug($"Skip element of type '{type}' with name '{name}'");
                        continue;
                    }
                    BBModel.Element element = new()
                    {
                        Name = name,
                        Rescale = jElement.GetBool("rescale", false),
                        Locked = jElement.GetBool("locked", false),
                        From = ParseIVecFromJson(jElement.GetRequired("from")),
                        To = ParseIVecFromJson(jElement.GetRequired("to")),
                        AutoUV = (int)jElement.GetRequired("autouv"),
                        Color = (int)jElement.GetRequired("color"),
                        Origin = ParseIVecFromJson(jElement.GetRequired("origin")),
                        North = ParseFaceFromJson(jFaces.GetRequired("north")),
                        South = ParseFaceFromJson(jFaces.GetRequired("south")),
                        East = ParseFaceFromJson(jFaces.GetRequired("east")),
                        West = ParseFaceFromJson(jFaces.GetRequired("west")),
                        Up = ParseFaceFromJson(jFaces.GetRequired("up")),
                        Down = ParseFaceFromJson(jFaces.GetRequired("down")),
                        Type = type,
                        UUID = Guid.Parse((string)jElement.GetRequired("uuid"))
                    };
                    Debug($"Read element {element.Name}");
                    result.Elements.Add(element);
                }
            }
            if (textures is not null)
            {
                Debug("Contains textures");
                foreach (JObject jTexture in textures)
                {
                    BBModel.Texture texture = new()
                    {
                        Path = (string)jTexture.GetRequired("path"),
                        Name = (string)jTexture.GetRequired("name"),
                        Folder = (string)jTexture.GetRequired("folder"),
                        Namespace = (string)jTexture.GetRequired("namespace"),
                        ID = (string)jTexture.GetRequired("id"),
                        Mode = (string)jTexture.GetRequired("mode"),
                        Particle = jTexture.GetBool("particle", false),
                        Visible = jTexture.GetBool("visible", true),
                        // Ignore 'saved'
                        UUID = Guid.Parse((string)jTexture.GetRequired("uuid"))
                    };
                    string sourceTex = (string)jTexture.GetRequired("source");
                    if (!sourceTex.StartsWith("data:image/png;base64,"))
                    {
                        throw new Exception($"Cannot read model - texture {texture.Name} contains source data that isn't the expected base64 png.");
                    }
                    texture.RawImageBytes = Convert.FromBase64String(sourceTex.After("data:image/png;base64,"));
                    Debug($"Read texture {texture.Name}");
                    result.Textures.Add(texture);
                }
            }
            if (animations is not null)
            {
                Debug("Contains animations");
                foreach (JObject jAnimation in animations)
                {
                    BBModel.Animation animation = new()
                    {
                        UUID = Guid.Parse((string)jAnimation.GetRequired("uuid")),
                        Name = (string)jAnimation.GetRequired("name"),
                        Loop = jAnimation.GetRequiredEnum<BBModel.Animation.LoopType>("loop"),
                        Override = jAnimation.GetBool("override", false),
                        AnimTimeUpdate = (string)jAnimation.GetRequired("anim_time_update"),
                        BlendWeight = (string)jAnimation.GetRequired("blend_weight"),
                        Length = (double)jAnimation.GetRequired("length"),
                        Snapping = (int)jAnimation.GetRequired("snapping")
                        // Ignored 'selected', 'saved', 'path'
                    };
                    foreach (KeyValuePair<string, JToken> jAnimatorPair in (JObject)jAnimation.GetRequired("animators"))
                    {
                        JObject jAnimator = (JObject)jAnimatorPair.Value;
                        BBModel.Animation.Animator animator = new()
                        {
                            UUID = Guid.Parse(jAnimatorPair.Key),
                            Name = (string)jAnimator.GetRequired("name")
                        };
                        foreach (JObject jFrame in jAnimator.GetRequired("keyframes"))
                        {
                            BBModel.Animation.Keyframe keyframe = new()
                            {
                                Channel = jFrame.GetRequiredEnum<BBModel.Animation.Keyframe.ChannelType>("channel"),
                                DataPoint = ParseDVecFromJson(jFrame.GetRequired("data_points").First),
                                UUID = Guid.Parse((string)jFrame.GetRequired("uuid")),
                                Time = (double)jFrame.GetRequired("time"),
                                Color = (int)jFrame.GetRequired("color"),
                                Interpolation = jFrame.GetRequiredEnum<BBModel.Animation.Keyframe.InterpolationType>("interpolation")
                            };
                            animator.Keyframes.Add(keyframe);
                        }
                        animation.Animators.Add(animator);
                    }
                    Debug($"Read Animation {animation.Name} with {animation.Animators.Count} animators");
                    result.Animations.Add(animation);
                }
            }
            return result;
        }

        public static DoubleVector ParseDVecFromJson(JToken jVal)
        {
            JObject jObj = (JObject)jVal;
            return new DoubleVector((double)jObj.GetRequired("x"), (double)jObj.GetRequired("y"), (double)jObj.GetRequired("z"));
        }

        public static IntegerVector ParseIVecFromJson(JToken jVal)
        {
            JArray jArr = (JArray)jVal;
            return new IntegerVector((int)jArr[0], (int)jArr[1], (int)jArr[2]);
        }

        public static BBModel.Element.Face ParseFaceFromJson(JToken jVal)
        {
            JObject jObj = (JObject)jVal;
            JArray uv = (JArray)jObj.GetRequired("uv");
            return new()
            {
                TextureID = (int)jObj.GetRequired("texture"),
                TexCoord = new BBModel.Element.Face.UV()
                {
                    ULow = (int)uv[0], // TODO: Validate this ordering
                    VLow = (int)uv[1],
                    UHigh = (int)uv[2],
                    VHigh = (int)uv[3]
                }
            };
        }
    }
}
