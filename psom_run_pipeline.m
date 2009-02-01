function [] = psom_run_pipeline(pipeline,opt)
%
% _________________________________________________________________________
% SUMMARY OF PSOM_RUN_PIPELINE
%
% Run a pipeline using the Pipeline System for Octave and Matlab (PSOM).
%
% SYNTAX:
% [] = PSOM_RUN_PIPELINE(PIPELINE,OPT)
%
% _________________________________________________________________________
% INPUTS:
%
% * PIPELINE
%       (structure) a matlab structure which defines a pipeline.
%       Each field name <JOB_NAME> will be used to name jobs of the 
%       pipeline. The fields <JOB_NAME> are themselves structure, with the 
%       following fields :
%
%       COMMAND
%           (string) the name of the command applied for this job.
%           This command can use the variables FILES_IN, FILES_OUT and OPT
%           associated with the job (see below).
%           Examples :
%               'niak_brick_something(files_in,files_out,opt);'
%               'my_function(opt)'
%
%       FILES_IN
%           (string, cell of strings, structure whose terminal nodes are
%           string or cell of strings)
%           The argument FILES_IN of the BRICK. Note that for properly
%           handling dependencies, this field needs to contain the exact
%           name of the file (full path, no wildcards, no '' for default
%           values).
%
%       FILES_OUT
%           (string, cell of strings, structure whose terminal nodes are
%           string or cell of strings) the argument FILES_OUT of
%           the BRICK. Note that for properly handling dependencies, this
%           field needs to contain the exact name of the file
%           (full path, no wildcards, no '' for default values).
%
%       OPT
%           (any matlab variable) options of the job. This field has no
%           impact on dependencies. OPT can for example be a structure,
%           where each field will be used as an argument of the command.
%
% * OPT
%       (structure) with the following fields :
%
%       PATH_LOGS
%           (string) The folder where the .M and .MAT files will be stored.
%
%       MODE
%           (string, default GB_PSOM_MODE defined in PSOM_GB_VARS)
%           how to execute the jobs :
%
%           'session'
%               the pipeline is executed within the current session. The
%               current matlab search path will be used instead of the one
%               that was active when the pipeline was initialized.
%
%           'batch'
%               Start the pipeline manager and each job in independent
%               matlab sessions. Note that more than one session can be
%               started at the same time to take advantage of
%               muli-processors machine. Moreover, the pipeline will run in
%               the background, you can continue to work, close matlab or
%               even unlog from your machine on a linux system without
%               interrupting it. The matlab path will be the same as the
%               current path. Log files will be created for all jobs.
%
%           'qsub'
%               Use the qsub system (sge or pbs) to process the jobs. The
%               pipeline runs in the background.
%
%       MODE_PIPELINE_MANAGER
%           (string, default GB_PSOM_MODE_PM defined in PSOM_GB_VARS) 
%           same as OPT.MODE, but applies to the pipeline manager itself.
%
%       MAX_QUEUED
%           (integer, default 1 'batch' modes, Inf in 'session' and 'qsub'
%           modes)
%           The maximum number of jobs that can be processed
%           simultaneously. Some qsub systems actually put restrictions
%           on that. Contact your local system administrator for more info.
%
%       SHELL_OPTIONS
%           (string, default GB_PSOM_SHELL_OPTIONS defined in PSOM_GB_VARS)
%           some commands that will be added at the begining of the shell
%           script submitted to batch or qsub. This can be used to set 
%           important variables, or source an initialization script.
%
%       QSUB_OPTIONS
%           (string, GB_PSOM_QSUB_OPTIONS defined in PSOM_GB_VARS)
%           This field can be used to pass any argument when submitting a
%           job with qsub. For example, '-q all.q@yeatman,all.q@zeus' will
%           force qsub to only use the yeatman and zeus workstations in the
%           all.q queue. It can also be used to put restrictions on the
%           minimum avalaible memory, etc.
%
%       RESTART
%           (cell of strings, default {}) any job whose name contains one 
%           of the strings in RESTART will be restarted
%
%       There are actually other minor options available, see 
%       PSOM_PIPELINE_INIT and PSOM_PIPELINE_PROCESS for details.
%
% _________________________________________________________________________
% OUTPUTS:
%
% The pipeline manager is going to try to process the pipeline and create 
% all the output files. In addition logs and parameters of the pipeline are
% stored in the log folder :
%
%   PIPE.mat
%
%       A .MAT file with the following variables:
%
%       OPT
%           The options used to initialize the pipeline
%
%       PIPELINE
%           The pipeline structure
%
%       HISTORY
%           A string recapituling when and who created the pipeline, (and
%           on which machine).
%
%       DEPS, LIST_JOBS, FILES_IN, FILES_OUT, GRAPH_DEPS
%           See PSOM_BUILD_DEPENDENCIES for more info.
%
%       PATH_WORK
%           The matlab/octave search path
%
%   PIPE_history.txt
%
%       A text file with the history of the pipeline. Basically, it keeps
%       track of the time of submission, completion and failure of all jobs
%       of the pipeline. If the pipeline is executed multiple times with
%       the same log folders, the history file is keeping track of all
%       sessions. 
%
%   PIPE_jobs.mat
%
%       A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%       the name of any job in the pipeline, and is equal to the field
%       PIPELINE.<NAME_JOB> for the lattest execution of this job in the 
%       pipeline.
%
%   PIPE_LOGS
%
%       A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%       the name of any job in the pipeline. The variable <NAME_JOB> is a 
%       string which contains the log of the job. Jobs that have not been 
%       processed yet have an empty log.
%
%   PIPE_status.mat
%
%       A .mat file which contains variables <NAME_JOB> where NAME_JOB is
%       the name of any job in the pipeline. The variable <NAME_JOB> is a 
%       string which describes the current status of the job (either
%       'submitted', 'finished', 'failed', 'none').
%
% _________________________________________________________________________
% SEE ALSO:
%
% PSOM_DEMO_PIPELINE, PSOM_PIPELINE_VISU
%
% _________________________________________________________________________
% COMMENTS:
%
% Empty file strings or strings equal to 'gb_niak_omitted' in the pipeline 
% description are ignored in the dependency graph and checks for 
% the existence of required files.
%
% If a pipeline is already running (a 'PIPE.lock' file could be found in
% the logs folder), a warning will be issued and the user may choose to
% stop the pipeline execution. Otherwise, the '.lock' file will be deleted
% and the pipeline will be restarted.
%
% If this is not the first time a pipeline is executed, the pipeline
% manager will check which jobs have been successfully completed, and will
% not restart these ones. If a job description has somehow been
% modified since a previous processing, this job and all its children will 
% be restarted. For more details on this behavior, please read the 
% documentation of PSOM_PIPELINE_INIT or run the pipeline demo in 
% NIAK_DEMO_PIPELINE.
%
% Copyright (c) Pierre Bellec, Montreal Neurological Institute, 2008.
% Maintainer : pbellec@bic.mni.mcgill.ca
% See licensing information in the code.
% Keywords : pipeline

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

psom_gb_vars

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setting up default values for inputs %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SYNTAX
if ~exist('pipeline','var')||~exist('opt','var')
    error('SYNTAX: [] = PSOM_RUN_PIPELINE(FILE_PIPELINE,OPT). Type ''help psom_run_pipeline'' for more info.')
end

%% Options
name_pipeline = 'PIPE';

gb_name_structure = 'opt';
gb_list_fields = {'restart','shell_options','path_logs','command_matlab','flag_verbose','mode','mode_pipeline_manager','max_queued','qsub_options','time_between_checks','nb_checks_per_point','time_cool_down'};
gb_list_defaults = {{},'',NaN,'',true,gb_psom_mode,gb_psom_mode_pm,0,'',[],[],[]};
psom_set_defaults

if isempty(opt.command_matlab)
    if strcmp(gb_psom_language,'matlab')
        opt.command_matlab = gb_psom_command_matlab;
    else
        opt.command_matlab = gb_psom_command_octave;
    end
end

if isempty(opt.qsub_options)
    opt.qsub_options = gb_psom_qsub_options;
end

if isempty(opt.shell_options)
    opt.shell_options = gb_psom_shell_options;
end

if max_queued == 0
    switch opt.mode
        case {'batch'}
            opt.max_queued = 1;
            max_queued = 1;
        case {'session','qsub'}
            opt.max_queued = Inf;
            max_queued = Inf;
    end % switch action
end % default of max_queued

if ~ismember(opt.mode,{'session','batch','qsub'})
    error('%s is an unknown mode of pipeline execution. Sorry dude, I must quit ...',opt.mode);
end

switch opt.mode
    case 'session'
        if isempty(time_between_checks)
            time_between_checks = 0;
        end
        if isempty(nb_checks_per_point)
            nb_checks_per_point = Inf;
        end        
    otherwise
        if isempty(time_between_checks)
            time_between_checks = 10;
        end
        if isempty(nb_checks_per_point)
            nb_checks_per_point = 6;
        end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The pipeline processing starts now  %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Check for a 'lock' tag
file_pipe_running = cat(2,path_logs,filesep,name_pipeline,'.lock');
if exist(file_pipe_running,'file') % Is the pipeline running ?
    fprintf('A lock tag has been found on the pipeline ! This means the pipeline was either running or crashed.\nI will assume it crashed and restart the pipeline.\nIf you are NOT CERTAIN that you want to restart the pipeline, press CTRL-C now !\n')
    pause
    delete(file_pipe_running);
end

%% Initialize the logs folder
opt_init.path_logs = opt.path_logs;
opt_init.command_matlab = opt.command_matlab;
opt_init.flag_verbose = opt.flag_verbose;
opt_init.restart = opt.restart;

psom_pipeline_init(pipeline,opt_init);

%% Run the pipeline manager
file_pipeline = cat(2,path_logs,filesep,name_pipeline,'.mat');

opt_proc.mode = opt.mode;
opt_proc.mode_pipeline_manager = opt.mode_pipeline_manager;
opt_proc.max_queued = opt.max_queued;
opt_proc.qsub_options = opt.qsub_options;
opt_proc.command_matlab = opt.command_matlab;
opt_proc.time_between_checks = opt.time_between_checks;
opt_proc.nb_checks_per_point = opt.nb_checks_per_point;

psom_pipeline_process(file_pipeline,opt_proc);

%% In batch and qsub modes, monitor the execution of the pipeline
switch opt.mode_pipeline_manager
    
    case {'batch','qsub'}

        psom_pipeline_visu(file_pipeline,'monitor');

end

