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
        [EventHandler("onClientResourceStart")]
        private void OnClientResourceStart(string resourceName)
        {
            TriggerEvent("chat:addMessage", new
            {
                color = new[] { 255, 255, 255 },
                args = new[] { "[TestResourceClient]", "Hello World!" }
            });
        }
    }
}
