
%% Here are important PSOM variables. Whenever needed, PSOM will call
%% this script to initialize the variables. If PSOM does not behave the way
%% you want, this might be the place to fix that.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The following variables need to be changed to configure the pipeline %%
%% system                                                               %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

gb_psom_command_matlab = 'matlab -nojvm -nosplash'; % how to invoke matlab   

gb_psom_command_octave = 'octave-2.9.9 --silent'; % how to invoke octave

gb_psom_sge_options = ''; % Options for the sge qsub system, example : '-q all.q@yeatman,all.q@zeus' will force qsub to only use the yeatman workstation;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The following variables describe the folders and external tools PSOM is using for various tasks %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

gb_psom_tmp = cat(2,filesep,'tmp',filesep); % where to store temporary files

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The following variables should not be changed %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% PSOM version
gb_psom_version = '0.4'; % 

%% Is the environment Octave or Matlab ?
if exist('OCTAVE_VERSION')    
    gb_psom_language = 'octave'; %% this is octave !
else
    gb_psom_language = 'matlab'; %% this is not octave, so it must be matlab
end

%% Get langage version
if strcmp(gb_psom_language,'octave');
    gb_psom_language_version = OCTAVE_VERSION;
else
    gb_psom_language_version = version;
end 

%% In which path is PSOM ?
str_gb_vars = which('psom_gb_vars');
if isempty(str_gb_vars)
    error('PSOM is not in the path ! (could not find PSOM_GB_VARS)')
end
gb_psom_path_psom = fileparts(str_gb_vars);
gb_psom_path_psom = [gb_psom_path_psom filesep];

%% In which path is the PSOM demo ?
gb_psom_path_demo = cat(2,gb_psom_path_psom,'data_demo',filesep);

%% What is the operating system ?
comp = computer;
tag_unix = {'SOL2','GLNX86','GLNXA64','unix','linux'};
tag_windaub = {'PCWIN','windows'};

if max(ismember(comp,tag_unix))>0
    gb_psom_OS = 'unix';
elseif max(ismember(comp,tag_windaub))>0
    gb_psom_OS = 'windows';
else
    warning('System %s unknown!\n',comp);
    gb_psom_OS = 'unkown';
end

%% getting user name.
switch (gb_psom_OS)
case 'unix'
	gb_psom_user = getenv('USER');
case 'windows'
	gb_psom_user = getenv('USERNAME');	
otherwise
	gb_psom_user = 'unknown';
end

%% Getting the local computer's name
switch (gb_psom_OS)
case 'unix'
	[gb_psom_tmp_var,gb_psom_localhost] = system('uname -n');
    gb_psom_localhost = deblank(gb_psom_localhost);
otherwise
	gb_psom_localhost = 'unknown';
end
