using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Drawing;
using System.Drawing.Imaging;
using FreneticUtilities.FreneticExtensions;
using FreneticUtilities.FreneticToolkit;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DenizenModelsConverter
{
    public static class BBModelReader
    {
        public static void Debug(string text)
        {
            Program.Debug(text);
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
            JArray outliners = (JArray)data["outliner"];
            JArray animations = (JArray)data["animations"];
            Dictionary<string, int> elementNames = new(), outlineNames = new();
            if (elements is not null)
            {
                Debug("Contains elements");
                foreach (JObject jElement in elements)
                {
                    JObject jFaces = (JObject)jElement["faces"];
                    string name = (string)jElement.GetRequired("name");
                    string type = jElement.GetString("type", "cube");
                    Guid id = Guid.Parse((string)jElement.GetRequired("uuid"));
                    if (type != "cube")
                    {
                        Debug($"Skip element of type '{type}' with name '{name}' and id {id}");
                        result.DiscardedIDs.Add(id);
                        continue;
                    }
                    int nameUsed = elementNames.GetValueOrDefault(name, 0);
                    elementNames[name] = nameUsed + 1;
                    if (nameUsed > 0)
                    {
                        name += (nameUsed + 1);
                    }
                    BBModel.Element element = new()
                    {
                        Name = name,
                        Rescale = jElement.GetBool("rescale", false),
                        Locked = jElement.GetBool("locked", false),
                        From = ParseDVecFromArr(jElement.GetRequired("from")),
                        To = ParseDVecFromArr(jElement.GetRequired("to")),
                        AutoUV = (int)jElement.GetRequired("autouv"),
                        Color = (int)jElement.GetRequired("color"),
                        Rotation = jElement.ContainsKey("rotation") ? ParseDVecFromArr(jElement.GetRequired("rotation")) : new DoubleVector(),
                        Origin = ParseDVecFromArr(jElement.GetRequired("origin")),
                        North = ParseFaceFromJson(jFaces.GetRequired("north")),
                        South = ParseFaceFromJson(jFaces.GetRequired("south")),
                        East = ParseFaceFromJson(jFaces.GetRequired("east")),
                        West = ParseFaceFromJson(jFaces.GetRequired("west")),
                        Up = ParseFaceFromJson(jFaces.GetRequired("up")),
                        Down = ParseFaceFromJson(jFaces.GetRequired("down")),
                        Type = type,
                        UUID = id
                    };
                    Debug($"Read element {element.Name} as id {element.UUID}");
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
#pragma warning disable CA1416 // Validate platform compatibility
                    using (Image image = Image.FromStream(new MemoryStream(texture.RawImageBytes)))
                    {
                        texture.Width = image.Width;
                        texture.Height = image.Height;
                    }
#pragma warning restore CA1416 // Validate platform compatibility
                    Debug($"Read texture {texture.Name}");
                    result.Textures.Add(texture);
                }
            }
            if (outliners is not null)
            {
                BBModel.Outliner rootOutline = null;
                Debug("contains outliners");
                foreach (JToken jOutliner in outliners)
                {
                    if (jOutliner.Type == JTokenType.String)
                    {
                        if (rootOutline is null)
                        {
                            rootOutline = new()
                            {
                                Name = "__root__",
                                Origin = new DoubleVector(),
                                Rotation = new DoubleVector(),
                                UUID = Guid.NewGuid()
                            };
                            result.Outlines.Add(rootOutline);
                        }
                        AddOutlineChild(result, rootOutline, jOutliner, outlineNames);
                    }
                    else
                    {
                        ReadOutliner(result, (JObject)jOutliner, outlineNames);
                    }
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
                                DataPoint = ParseDVecFromObj(jFrame.GetRequired("data_points").First),
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

        public static HashSet<double> AcceptableRotations = new() { 0, 22.5, 45, -22.5, -45 };

        public static void AddOutlineChild(BBModel model, BBModel.Outliner outline, JToken child, Dictionary<string, int> names)
        {
            if (child.Type == JTokenType.String)
            {
                Guid id = Guid.Parse((string)child);
                BBModel.Element element = model.GetElement(id);
                if (element is null)
                {
                    if (model.DiscardedIDs.Contains(id))
                    {
                        return;
                    }
                    throw new Exception($"Cannot find required element {id} for outline {outline.Name}");
                }
                if (element.Outline is not null)
                {
                    throw new Exception($"Cannot add required element {id} for outline {outline.Name} because it is already in other outline {element.Outline.Name}");
                }
                if (AcceptableRotations.Contains(element.Rotation.X) && AcceptableRotations.Contains(element.Rotation.Y) && AcceptableRotations.Contains(element.Rotation.Z)
                    && ((element.Rotation.X == 0 ? 0 : 1) + (element.Rotation.Y == 0 ? 0 : 1) + (element.Rotation.Z == 0 ? 0 : 1)) < 2)
                {
                    outline.Children.Add(id);
                    element.Outline = outline;
                }
                else
                {
                    BBModel.Outliner specialSideOutline = new()
                    {
                        Name = $"{outline.Name}_auto_{element.Name}",
                        Origin = element.Origin,
                        Rotation = element.Rotation,
                        UUID = Guid.NewGuid(),
                    };
                    element.Rotation = new DoubleVector();
                    element.Origin = new DoubleVector();
                    element.Outline = specialSideOutline;
                    specialSideOutline.Parent = outline.UUID;
                    specialSideOutline.Children.Add(element.UUID);
                    model.Outlines.Add(specialSideOutline);
                }
            }
            else
            {
                BBModel.Outliner subLine = ReadOutliner(model, (JObject)child, names);
                subLine.Parent = outline.UUID;
            }
        }

        public static BBModel.Outliner ReadOutliner(BBModel model, JObject jOutliner, Dictionary<string, int> names)
        {
            string name = (string)jOutliner.GetRequired("name");
            int nameUsed = names.GetValueOrDefault(name, 0);
            names[name] = nameUsed + 1;
            if (nameUsed > 0)
            {
                name += (nameUsed + 1);
            }
            BBModel.Outliner outline = new()
            {
                Name = name,
                Origin = ParseDVecFromArr(jOutliner.GetRequired("origin")),
                UUID = Guid.Parse((string)jOutliner.GetRequired("uuid")),
                // Ignore ik_enabled, ik_chain_length, export, isOpen, locked, visibility, autouv
            };
            foreach (JToken child in (JArray)jOutliner.GetRequired("children"))
            {
                AddOutlineChild(model, outline, child, names);
            }
            Debug($"Read outliner {outline.Name}");
            model.Outlines.Add(outline);
            return outline;
        }

        public static DoubleVector ParseDVecFromObj(JToken jVal)
        {
            JObject jObj = (JObject)jVal;
            return new DoubleVector((double)jObj.GetRequired("x"), (double)jObj.GetRequired("y"), (double)jObj.GetRequired("z"));
        }

        public static DoubleVector ParseDVecFromArr(JToken jVal)
        {
            JArray jArr = (JArray)jVal;
            return new DoubleVector((double)jArr[0], (double)jArr[1], (double)jArr[2]);
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
                    ULow = (int)uv[0],
                    VLow = (int)uv[1],
                    UHigh = (int)uv[2],
                    VHigh = (int)uv[3]
                }
            };
        }
    }
}
