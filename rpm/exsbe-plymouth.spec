Name:           exsbe-plymouth
Version:        1.0
Release:        1
Summary:        Exsbe Plymouth boot theme
License:        MIT
BuildArch:      noarch
Requires:       plymouth-plugin-script

%description
Dark textured background with the breathing Exsbe logo.

%install
install -Dm644 %{_sourcedir}/exsbe/background.png %{buildroot}/usr/share/plymouth/themes/exsbe/background.png
install -Dm644 %{_sourcedir}/exsbe/logo.png       %{buildroot}/usr/share/plymouth/themes/exsbe/logo.png
install -Dm644 %{_sourcedir}/exsbe/exsbe.script   %{buildroot}/usr/share/plymouth/themes/exsbe/exsbe.script
install -Dm644 %{_sourcedir}/exsbe/exsbe.plymouth %{buildroot}/usr/share/plymouth/themes/exsbe/exsbe.plymouth

%files
/usr/share/plymouth/themes/exsbe/
