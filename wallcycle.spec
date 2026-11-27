%global debug_package %{nil}

Name:           wallcycle
Version:        %{?_version}%{!?_version:1.0.0}
Release:        1%{?dist}
Summary:        Desktop wallpaper slideshow with real-time clock overlay and BT.709 filter

License:        Apache-2.0
URL:            https://github.com/nightranger73/WallCycle

%if 0%{?suse_version}
Requires:       libQt6Pas6
Requires:       curl
%else
Requires:       qt6pas
Requires:       curl
%endif

%description
WallCycle runs an automatic desktop wallpaper slideshow from local folders and
WallHaven.cc with a perceived-luminance filter (ITU-R BT.709), customizable
real-time Date & Time overlay, multi-monitor support, Smart Pause, Favorites,
Blacklist, and backends for GNOME, KDE Plasma, XFCE, Hyprland, Sway, Niri, and Umbriel.

%install
rm -rf %{buildroot}
install -Dm755 %{_sourcedir}/WallCycle %{buildroot}%{_bindir}/wallcycle
install -Dm644 %{_sourcedir}/wallcycle.desktop %{buildroot}%{_datadir}/applications/wallcycle.desktop
install -Dm644 %{_sourcedir}/README.md %{buildroot}%{_docdir}/%{name}/README.md

%files
%{_bindir}/wallcycle
%{_datadir}/applications/wallcycle.desktop
%{_docdir}/%{name}/README.md

%changelog
* Fri Nov 27 2026 WallCycle Maintainers <noreply@example.com> - 1.0.0-1
- Switch RPM runtime dependencies to Qt6 (qt6pas / libQt6Pas6) for Fedora and openSUSE
