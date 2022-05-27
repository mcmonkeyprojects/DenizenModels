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
        public static void Main(string[] args)
        {
            SpecialTools.Internationalize();
            HashSet<string> flags = args.Where(s => s.StartsWith("--")).Select(s => s.After("--").ToLowerFast()).ToHashSet();
            string[] realArgs = args.Where(s => !s.StartsWith("--")).ToArray();
            BBModelReader.Verbose = flags.Contains("verbose");
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
                    // TODO
                    return;
                    // TODO: Other commands
                default:
                    Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} help -- Shows this help output.");
                    Console.WriteLine($"{AppDomain.CurrentDomain.FriendlyName} test [file] -- Does a test scan of a bbmodel file and outputs parsed content.");
                    Console.WriteLine($"Add '--verbose' to enable verbose debugging output.");
                    // TODO
                    return;
            }
        }
    }
}
