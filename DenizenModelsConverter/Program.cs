using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Threading.Tasks;
using FreneticUtilities.FreneticExtensions;
using FreneticUtilities.FreneticToolkit;

namespace DenizenModelsConverter
{
    public static class Program
    {
        public static AsciiMatcher PATH_CHARS = new(AsciiMatcher.LowercaseLetters + AsciiMatcher.Digits + "_/");

        public const double SCALE = 1.5f;

        public static bool Verbose = false;

        public static void Debug(string text)
        {
            if (Verbose)
            {
                Console.WriteLine($"[Debug] {text}");
            }
        }

        public static void Main(string[] args)
        {
            SpecialTools.Internationalize();
            HashSet<string> flags = args.Where(s => s.StartsWith("--")).Select(s => s.After("--").ToLowerFast()).ToHashSet();
            string[] realArgs = args.Where(s => !s.StartsWith("--")).ToArray();
            Verbose = flags.Contains("verbose");
            switch (realArgs.Length == 0 ? "help" : realArgs[0].ToLowerFast())
            {
                case "test":
                    {
                        if (realArgs.Length != 2)
                        {
                            Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} test [file] -- Does a test scan of a bbmodel file and outputs parsed content.");
                            return;
                        }
                        if (!File.Exists(realArgs[1]))
                        {
                            Console.WriteLine("Invalid file path.");
                            return;
                        }
                        string content = File.ReadAllText(realArgs[1]);
                        if (!content.StartsWith("{"))
                        {
                            Console.WriteLine("File doesn't look like a BBModel file.");
                            return;
                        }
                        try
                        {
                            BBModel model = BBModelReader.Interpret(content);
                            Console.WriteLine($"Parsed... Name: {model.Name}, Format version: {model.FormatVersion}, Creation time: {model.CreationTime}"
                                + $", elements: {model.Elements.Count}, textures: {model.Textures.Count}, animations: {model.Animations.Count}");
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Failed to parse model: {ex}");
                        }
                    }
                    return;
                case "make_pack":
                    {
                        if (realArgs.Length != 5)
                        {
                            Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} make_pack [bbmodel_file] [pack_path] [model_path] [texture_path] -- Puts a model into a resource pack, must specify model and texture path within the pack.");
                            Console.WriteLine("If the pack contains a specific item you want to override, use '--item:stick' ... otherwise, will use arrow as the default item.");
                            Console.WriteLine("Example: make_pack goat.bbmodel creaturepack creatures/goat creatures/goat -- This example parses a 'goat' model and puts it in reasonable paths, using arrow as the item to add onto.");
                            return;
                        }
                        if (!File.Exists(realArgs[1]))
                        {
                            Console.WriteLine("Invalid file path.");
                            return;
                        }
                        string filePath = realArgs[1];
                        string content = File.ReadAllText(filePath);
                        if (!content.StartsWith("{"))
                        {
                            Console.WriteLine("File doesn't look like a BBModel file.");
                            return;
                        }
                        BBModel model;
                        try
                        {
                            model = BBModelReader.Interpret(content);
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Failed to parse model: {ex}");
                            return;
                        }
                        Console.WriteLine($"Parsed model '{model.Name}', beginning conversion");
                        string packPath = realArgs[2];
                        string modelPath = realArgs[3];
                        string texturePath = realArgs[4];
                        string item = (flags.FirstOrDefault(s => s.StartsWith("item:")) ?? "item:arrow").After("item:");
                        if (!PATH_CHARS.IsOnlyMatches(modelPath))
                        {
                            Console.WriteLine($"Invalid model path, must be only lowercase a-z, 0-9, _, /");
                            return;
                        }
                        if (!PATH_CHARS.IsOnlyMatches(texturePath))
                        {
                            Console.WriteLine($"Invalid texture path, must be only lowercase a-z, 0-9, _, /");
                            return;
                        }
                        string packPathRoot = $"{packPath}/assets/minecraft/";
                        Directory.CreateDirectory(packPathRoot);
                        Console.WriteLine($"Will export pack to: {packPathRoot}");
                        PackMaker.BuildPack(filePath, model, item, packPathRoot, modelPath, texturePath);
                    }
                    return;
                default:
                    Console.WriteLine($"DenizenModelsConverter, a program that converts BlockBench 'bbmodel' files to resource packs + animation files for Denizen"
                        + "... execute any command listed with any other arguments to see full usage info for it.");
                    Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} help -- Shows this command list.");
                    Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} test -- Does a test scan of a bbmodel file and outputs parsed content.");
                    Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} make_pack -- Adds a model to a resource pack (or makes a new one if needed).");
                    Console.WriteLine($"Add '--verbose' to enable verbose debugging output.");
                    // TODO: More commands?
                    return;
            }
        }
    }
}
