Name:           exsbe-plymouth
Version:        2.0
Release:        1
Summary:        Exsbe Plymouth boot theme
License:        MIT
BuildArch:      noarch
Requires:       plymouth-plugin-script
Requires:       plymouth-plugin-label

%description
The Exsbe lockup on softly lit graphite: the five bars slide into place, the wordmark rises along
its slant, then a light runs down the bars while the system boots. Themed passphrase prompt and
boot messages.

%install
install -d %{buildroot}/usr/share/plymouth/themes/exsbe
install -m644 %{_sourcedir}/exsbe/*.png %{_sourcedir}/exsbe/exsbe.script %{_sourcedir}/exsbe/exsbe.plymouth \
    %{buildroot}/usr/share/plymouth/themes/exsbe/

%files
/usr/share/plymouth/themes/exsbe/

%changelog
* Sun Nov 15 2026 Exsbe - 2.0-1
- The full Exsbe lockup, an assembling animation and a loading light; passphrase prompt and messages
* Tue Oct 27 2026 Exsbe - 1.0-1
- First release: background and the breathing Exsbe mark
