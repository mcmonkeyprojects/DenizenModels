using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace DenizenModelsConverter
{
    public static class JSONExtensions
    {
        public static JToken GetRequired(this JObject obj, string name)
        {
            JToken tok = obj[name];
            if (tok == null)
            {
                throw new Exception($"JSON parse failed: expected key '{name}' but was null");
            }
            return tok;
        }

        public static bool GetBool(this JObject obj, string name, bool defVal)
        {
            JToken tok = obj[name];
            if (tok == null)
            {
                return defVal;
            }
            return (bool)tok;
        }

        public static string GetString(this JObject obj, string name, string defVal)
        {
            JToken tok = obj[name];
            if (tok == null)
            {
                return defVal;
            }
            return (string)tok;
        }

        public static T GetRequiredEnum<T>(this JObject obj, string name) where T : struct
        {
            JToken tok = obj.GetRequired(name);
            string text = (string)tok;
            return Enum.Parse<T>(text, true);
        }
    }
}
