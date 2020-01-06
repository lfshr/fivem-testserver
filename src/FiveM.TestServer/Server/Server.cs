using System;
using System.Configuration;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;

namespace Server
{
    internal class Server
    {
        private WebClient _webClient;

        public Server()
        {
            _webClient = new WebClient();
        }

        public void Start(string[] args)
        {
            var fxServerDownloadUri = ConfigurationManager.AppSettings["fxServerDownloadUri"];
            var fxServerDataDownloadUri = ConfigurationManager.AppSettings["fxServerDataDownloadUri"];

            if (!Directory.Exists("server"))
                DoAction("Downloading FXServer", () => DownloadAndExtractTo(fxServerDownloadUri, "server"));

            if (!Directory.Exists(@"server-data\resources\[local]"))
            {
                var tempPath = Path.Join(Path.GetTempPath(), Guid.NewGuid().ToString());
                Directory.CreateDirectory(tempPath);

                if (!Directory.Exists(@"server-data\resources"))
                    Directory.CreateDirectory(@"server-data\resources");

                try
                {
                    DoAction("Downloading Server Data", () => DownloadAndExtractTo(fxServerDataDownloadUri, tempPath));

                    var children = Directory.GetDirectories(Path.Join(tempPath, @"cfx-server-data-master\resources"));
                    foreach (var child in children)
                    {
                        var dirName = new DirectoryInfo(child).Name;
                        Directory.Move(child, $@"server-data\resources\{dirName}");
                    }
                }
                finally
                {
                    Directory.Delete(tempPath, true);
                }
            }

            Directory.SetCurrentDirectory("server-data");

            var process = new Process();
            process.StartInfo = new ProcessStartInfo(@"..\server\run.cmd",
                string.Join(' ', args))
            {
                UseShellExecute = false
            };
            process.Start();
            process.WaitForExit();
        }

        // Purdy console
        void DoAction(string message, Action action)
        {
            Console.Write(message + "...");
            action();
            Console.WriteLine(" Done!");
        }

        void DownloadAndExtractTo(string uri, string extractPath)
        {
            var filename = Path.GetTempFileName() + ".zip";
            try
            {
                _webClient.DownloadFile(uri, filename);
                ZipFile.ExtractToDirectory(filename, extractPath);
            }
            finally
            {
                File.Delete(filename);
            }
        }
    }
}
