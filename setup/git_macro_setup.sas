filename mysetup url "https://raw.githubusercontent.com/georgebeevers/SAS-Code/master/setup/git_macro_compile.sas";
%inc mysetup;

%git_macro_compile(eg_git_loc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8,assign="Y");