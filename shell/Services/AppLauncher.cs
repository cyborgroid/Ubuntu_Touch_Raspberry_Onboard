using System.Diagnostics;

namespace CyborgroidDashboard.Services;

public static class AppLauncher
{
    public static bool IsInstalled(string executable)
    {
        var path = Environment.GetEnvironmentVariable("PATH") ?? "";
        return path.Split(':').Any(dir => File.Exists(Path.Combine(dir, executable)));
    }

    public static void Launch(string executable)
    {
        Process.Start(new ProcessStartInfo(executable) { UseShellExecute = false })?.Dispose();
    }
}
