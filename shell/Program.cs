using Avalonia;

namespace CyborgroidDashboard;

internal static class Program
{
    // Native Wayland under Lomiri and GNOME; X11 where there is no compositor.
    [STAThread]
    public static void Main(string[] args) =>
        AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .UseWaylandWithFallback()
            .StartWithClassicDesktopLifetime(args);
}
