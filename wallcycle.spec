%global debug_package %{nil}

Name:           wallcycle
Version:        %{?_version}%{!?_version:1.0.0}
Release:        1%{?dist}
Summary:        Desktop wallpaper slideshow with real-time clock overlay and BT.709 filter

License:        Apache-2.0
URL:            https://github.com/TUO_UTENTE/wallcycle

%if 0%{?suse_version}
Requires:       libgtk-2_0-0
Requires:       curl
%else
Requires:       gtk2
Requires:       curl
%endif

%description
WallCycle esegue slideshow automatici di sfondi desktop da cartelle locali e
WallHaven.cc con filtro di luminanza ITU-R BT.709, overlay Data e Ora in tempo
reale e supporto per GNOME, KDE Plasma, XFCE, Hyprland, Sway, Niri e Umbriel.

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
* Mon Nov 23 2026 WallCycle Maintainers <noreply@example.com> - 1.0.0-1
- Initial RPM release for Fedora and openSUSE
