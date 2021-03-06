%global pkg_name %{name}

%{!?python_sitelib: %global python_sitelib %(%{__python} -c "from distutils.sysconfig import get_python_lib; print get_python_lib()")}
%{!?python_sitearch: %global python_sitearch %(%{__python} -c "from distutils.sysconfig import get_python_lib; print get_python_lib(1)")}

Name:           preupgrade-assistant-el6toel7
Version:        0.7.2
Release:        1%{?dist}
Summary:        Set of modules created for upgrade to Red Hat Enterprise Linux 7
Group:          System Environment/Libraries
License:        GPLv3+
URL:            https://github.com/upgrades-migrations/preupgrade-assistant-modules
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRoot:      %{_tmppath}/%{pkg_name}-%{version}-%{release}-root-%(%{__id_u} -n)

Requires:       preupgrade-assistant >= 2.5.0
BuildRequires:  preupgrade-assistant-tools >= 2.5.0

# static data are required by our modules & old contents
# are obsoleted by this package
Obsoletes:      preupgrade-assistant-contents < 0.6.41-6
Provides:       preupgrade-assistant-contents = %{version}-%{release}
Requires:       preupgrade-assistant-el6toel7-data


############################
# Per module requirements #
############################

# * owned by RHEL6_7/packages/pkgdowngrades - this is for the
#   redhat-upgrade-tool hook "fixpkgdowngrades.sh
Requires:       yum, rpm-python

# Why those requirements?
# /usr/bin/python and /usr/bin/python2 are already present.
Requires:       bash
Requires:       python
Requires:       coreutils
Requires:       perl

#do not require php even in presence of php scripts
#dependency filtering: https://fedoraproject.org/wiki/Packaging:AutoProvidesAndRequiresFiltering
%if 0%{?fedora} || 0%{?rhel} > 6
%global __requires_exclude_from ^%{_datadir}
%else
%filter_requires_in %{_datadir}
%filter_setup
%endif

##############################
#  PATCHES HERE
##############################

####### PATCHES END ##########

# We do not want any autogenerated requires/provides based on content
%global __requires_exclude .*
%global __requires_exclude_from .*
%global __provides_exclude .*
%global __provides_exclude_from .*

%description
The package provides a set of modules used for assessment
of the source system for upgrade or migration to Red Hat
Enterprise Linux 7 system.
The modules are used by the preupgrade-assistant package.


%prep
%setup -q -n %{name}-%{version}


%build
# This is all we need here. The RHEL6_7-results dir will be created
# with XCCDF files for Preupgrade Assistant and OpenSCAP
preupg-xccdf-compose RHEL6_7


%install
rm -rf $RPM_BUILD_ROOT

mkdir -p -m 755 $RPM_BUILD_ROOT%{_datadir}/doc/preupgrade-assistant-el6toel7
install -d -m 755 $RPM_BUILD_ROOT%{_datadir}/preupgrade
mv LICENSE $RPM_BUILD_ROOT%{_datadir}/doc/preupgrade-assistant-el6toel7/
mv RHEL6_7-results $RPM_BUILD_ROOT%{_datadir}/preupgrade/RHEL6_7

rm -rf $RPM_BUILD_ROOT/%{_datadir}/preupgrade/common

# General cleanup
find $RPM_BUILD_ROOT%{_datadir}/preupgrade/RHEL6_7 -regex ".*/\(module\|group\)\.ini$" -regextype grep -delete
find $RPM_BUILD_ROOT%{_datadir}/preupgrade/ -name "READY" -delete
find $RPM_BUILD_ROOT -name '.gitignore' -delete
find $RPM_BUILD_ROOT -name 'module_spec' -delete


%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%dir %{_datadir}/doc/preupgrade-assistant-el6toel7/
%doc %{_datadir}/doc/preupgrade-assistant-el6toel7/LICENSE
%dir %{_datadir}/preupgrade/RHEL6_7/
%{_datadir}/preupgrade/RHEL6_7/



%changelog
* Thu Aug 10 2017 Petr Stodulka <pstodulk@redhat.com> - %{version}-%{release}
- Initial spec file created for modules of Preupgrade Assistant for
  upgrade&migration from RHEL 6.x system to RHEL 7.x system

