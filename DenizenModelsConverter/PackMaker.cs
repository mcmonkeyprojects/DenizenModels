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
            foreach (JObject obj in overrides)
            {
                JObject predicate = obj.GetRequired("predicate") as JObject; 
                if (predicate.ContainsKey("custom_model_data"))
                {
                    int cmd = (int)predicate.GetRequired("custom_model_data");
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
                Debug($"Creating model for {modelPath}/{outline.Name} as {item}[custom_model_data={min}]");
                string modelText = MinecraftModelMaker.CreateModelFor(model, outline);
                if (modelText is null)
                {
                    Debug("Skip this model outline entry - no content");
                    JObject skippedEntry = new();
                    skippedEntry.Add("name", outline.Name);
                    skippedEntry.Add("empty", true);
                    modelSet.Add(outline.UUID.ToString(), skippedEntry);
                    continue;
                }
                File.WriteAllText($"{fullModelPath}/{outline.Name}.json", modelText);
                JObject overrideEntry = new();
                overrideEntry.Add("model", $"{modelPath}/{outline.Name}");
                JObject predicate = new();
                predicate.Add("custom_model_data", min);
                overrideEntry.Add("predicate", predicate);
                overrides.Add(overrideEntry);
                JObject modelEntry = new();
                modelEntry.Add("name", outline.Name);
                modelEntry.Add("item", $"{item}[custom_model_data={min}]");
                modelEntry.Add("origin", outline.Origin.ToDenizenString());
                modelEntry.Add("pairs", new JArray(outline.Paired.Select(p => p.ToString()).ToArray()));
                modelSet.Add(outline.UUID.ToString(), modelEntry);
                min++;
            }
            Debug("Models done. Outputting new item override...");
            itemOverride.Remove("overrides");
            itemOverride.Add("overrides", overrides);
            File.WriteAllText(itemFilePath, itemOverride.ToString());
            Debug("Overrides done. Building Denizen file...");
            JObject denizenFile = new();
            denizenFile.Add("models", modelSet);
            File.WriteAllText($"{rawModelPath.Replace(".bbmodel", "")}.dmodel.yml", denizenFile.ToString());
            Console.WriteLine("Exported full bbmodel.");
        }
    }
}
