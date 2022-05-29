using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Threading.Tasks;
using FreneticUtilities.FreneticExtensions;
using FreneticUtilities.FreneticToolkit;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DenizenModelsConverter
{
    public static class PackMaker
    {
        public static void Debug(string text)
        {
            Program.Debug(text);
        }

        public const string ArrowRef = "{\"parent\": \"minecraft:item/generated\",\"textures\": {\"layer0\": \"minecraft:item/arrow\"}}";

        public static void BuildPack(string rawModelPath, BBModel model, string item, string packPathRoot, string modelPath, string texturePath)
        {
            modelPath = $"item/{modelPath}";
            string fullModelPath = $"{packPathRoot}/models/{modelPath}";
            Directory.CreateDirectory(fullModelPath);
            Console.WriteLine($"Will export models to: {fullModelPath}");
            string fullTexturePath = $"{packPathRoot}/textures/{texturePath}";
            Directory.CreateDirectory(fullTexturePath);
            Console.WriteLine($"Will export textures to: {fullTexturePath}");
            Debug("Export textures...");
            foreach (BBModel.Texture texture in model.Textures)
            {
                texture.CorrectedFullPath = $"{texturePath}/{texture.Folder}/{texture.Name}";
                Debug($"Exporting texture {texture.CorrectedFullPath}...");
                Directory.CreateDirectory($"{fullTexturePath}/{texture.Folder}/");
                File.WriteAllBytes($"{fullTexturePath}/{texture.Folder}/{texture.Name}.png", texture.RawImageBytes);
            }
            string itemFilePath = $"{packPathRoot}/models/item/{item}.json";
            string itemFile;
            if (File.Exists(itemFilePath))
            {
                Debug($"Will use existing item file at {itemFilePath}");
                itemFile = File.ReadAllText(itemFilePath);
            }
            else
            {
                if (item == "arrow")
                {
                    Debug("Will use default arrow file reference");
                    itemFile = ArrowRef;
                }
                else
                {
                    throw new Exception("Cannot create pack - item given does not exist in pack. Add the item, or leave the item specifier off.");
                }
            }
            Debug("Textures done, scanning item override...");
            JObject itemOverride = JObject.Parse(itemFile);
            JArray overrides = itemOverride.ContainsKey("overrides") ? (JArray)itemOverride.GetRequired("overrides") : new JArray();
            int min = 1000;
            Dictionary<string, int> existingCmd = new();
            foreach (JObject obj in overrides)
            {
                string modelName = (string)obj.GetRequired("model");
                JObject predicate = obj.GetRequired("predicate") as JObject; 
                if (predicate.ContainsKey("custom_model_data"))
                {
                    int cmd = (int)predicate.GetRequired("custom_model_data");
                    existingCmd[modelName] = cmd;
                    if (cmd >= min)
                    {
                        min = cmd + 1;
                    }
                }
            }
            Debug($"Will use {item}[custom_model_data={min}] as the starting ID. Beginning model export...");
            JObject modelSet = new();
            foreach (BBModel.Outliner outline in model.Outlines)
            {
                string modelText = MinecraftModelMaker.CreateModelFor(model, outline);
                if (modelText is null)
                {
                    Debug("Skip this model outline entry - no content");
                    JObject skippedEntry = new();
                    skippedEntry.Add("name", outline.Name);
                    skippedEntry.Add("empty", true);
                    skippedEntry.Add("parent", outline.Parent == null ? "none" : outline.Parent.ToString());
                    modelSet.Add(outline.UUID.ToString(), skippedEntry);
                    continue;
                }
                string modelName = $"{modelPath}/{outline.Name}";
                bool reused = existingCmd.TryGetValue(modelName, out int id);
                if (!reused)
                {
                    Debug($"Adding new custom_model_data for {modelName} as {min}");
                    id = min++;
                    JObject overrideEntry = new();
                    overrideEntry.Add("model", $"{modelPath}/{outline.Name}");
                    JObject predicate = new();
                    predicate.Add("custom_model_data", id);
                    overrideEntry.Add("predicate", predicate);
                    overrides.Add(overrideEntry);
                }
                Debug($"Creating model for {modelName} as {item}[custom_model_data={id}]");
                File.WriteAllText($"{fullModelPath}/{outline.Name}.json", modelText);
                JObject modelEntry = new();
                modelEntry.Add("name", outline.Name);
                modelEntry.Add("item", $"{item}[custom_model_data={id}]");
                modelEntry.Add("origin", outline.Origin.ToDenizenString());
                modelEntry.Add("rotation", outline.Rotation.ToDenizenString());
                modelEntry.Add("parent", outline.Parent == null ? "none" : outline.Parent.ToString());
                modelSet.Add(outline.UUID.ToString(), modelEntry);
            }
            Debug("Models done. Outputting new item override...");
            itemOverride.Remove("overrides");
            itemOverride.Add("overrides", overrides);
            File.WriteAllText(itemFilePath, itemOverride.ToString());
            Debug("Overrides done. Building animation data...");
            JObject animations = new();
            foreach (BBModel.Animation animation in model.Animations)
            {
                Debug($"Start processing animation {animation.Name}");
                if (animations.ContainsKey(animation.Name))
                {
                    throw new Exception($"Cannot output functional model - duplicate animation name '{animation.Name}'");
                }
                JObject jAnimation = new();
                jAnimation.Add("loop", animation.Loop.ToString());
                jAnimation.Add("override", animation.Override);
                jAnimation.Add("anim_time_update", animation.AnimTimeUpdate);
                jAnimation.Add("blend_weight", animation.BlendWeight);
                jAnimation.Add("length", animation.Length);
                JObject jAnimators = new();
                foreach (BBModel.Animation.Animator animator in animation.Animators)
                {
                    JObject jAnimator = new();
                    JArray keyframes = new();
                    foreach (BBModel.Animation.Keyframe frame in animator.Keyframes)
                    {
                        JObject jFrame = new();
                        jFrame.Add("channel", frame.Channel.ToString());
                        jFrame.Add("data", frame.DataPoint.ToDenizenString());
                        jFrame.Add("time", frame.Time);
                        jFrame.Add("interpolation", frame.Interpolation.ToString());
                        keyframes.Add(jFrame);
                    }
                    jAnimator.Add("frames", keyframes);
                    jAnimators.Add(animator.UUID.ToString(), jAnimator);
                }
                jAnimation.Add("animators", jAnimators);
                animations.Add(animation.Name, jAnimation);
            }
            Debug("Animations done. Building Denizen file...");
            JArray partsOrder = new();
            BuildPartsOrder(model, null, partsOrder);
            if (partsOrder.Count != model.Outlines.Count)
            {
                throw new Exception($"Failed to build parts order, listed {partsOrder.Count} but expected {model.Outlines.Count} ... are bone parents wrong?");
            }
            JObject denizenFile = new();
            denizenFile.Add("order", partsOrder);
            denizenFile.Add("models", modelSet);
            denizenFile.Add("animations", animations);
            File.WriteAllText($"{rawModelPath.Replace(".bbmodel", "")}.dmodel.yml", denizenFile.ToString());
            Console.WriteLine("Exported full bbmodel.");
        }

        public static void BuildPartsOrder(BBModel model, Guid? id, JArray output)
        {
            List<BBModel.Outliner> partsToAdd = new();
            foreach (BBModel.Outliner outline in model.Outlines)
            {
                if (outline.Parent == id)
                {
                    partsToAdd.Add(outline);
                }
            }
            if (partsToAdd.IsEmpty())
            {
                return;
            }
            foreach (BBModel.Outliner part in partsToAdd)
            {
                output.Add(part.UUID.ToString());
            }
            foreach (BBModel.Outliner part in partsToAdd)
            {
                BuildPartsOrder(model, part.UUID, output);
            }
        }
    }
}
