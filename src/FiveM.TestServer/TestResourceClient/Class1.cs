using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using CitizenFX.Core;
using static CitizenFX.Core.Native.API;

namespace TestResourceClient
{
    public class Class1 : BaseScript
    {
        public Class1()
        {
            EventHandlers["onClientResourceStart"] += new Action<string>(OnClientResourceStart);
        }

        void Say(
            string message,
            int red = 255,
            int green = 255,
            int blue = 222)
        {
            TriggerEvent("chat:addMessage", new
            {
                color = new[] { red, green, blue },
                args = new[] { "[TestResourceClient]", message }
            });
        }
        private void OnClientResourceStart(string resourceName)
        {
            Say("Hello world!");
        }
    }
}
