function [] = psom_pipeline_process(file_pipeline,opt)
%
% _________________________________________________________________________
% SUMMARY OF PSOM_PIPELINE_PROCESS
%
% Process a pipeline that has previously been initialized.
%
% SYNTAX:
% [] = PSOM_PIPELINE_PROCESS(FILE_PIPELINE,OPT)
%
% _________________________________________________________________________
% INPUTS:
%
% FILE_PIPELINE
%       (string) The file name of a .MAT file generated using
%       PSOM_PIPELINE_INIT.
%
% OPT
%       (structure) with the following fields :
%
%       MODE
%           (string, default 'session') how to execute the jobs :
%
%           'session'
%               the pipeline is executed within the current session. The
%               current matlab search path will be used instead of the one
%               that was active when the pipeline was initialized. In that
%               mode, the log files of individual jobs are appendend to the
%               log file of the pipeline.
%
%           'batch'
%               Start the pipeline manager and each job in independent
%               matlab sessions. Note that more than one session can be
%               started at the same time to take advantage of
%               muli-processors machine. Moreover, the pipeline will run in
%               the background, you can continue to work, close matlab or
%               even unlog from your machine on a linux system without
%               interrupting it. The matlab path will be the same as the
%               one that was active when the pipeline was initialized. Log
%               files will be created for all jobs.
%
%           'qsub'
%               Use the qsub system (sge or pbs) to process the jobs. The
%               pipeline runs in the background.
%
%       FLAG_BATCH
%           (boolean, default 0) how to execute the pipeline :
%
%           If FLAG_BATCH == 0, the pipeline is executed within the session.
%               Interrupting the pipeline with CTRL-C will result in
%               interrupting the pipeline (you can always do a 'restart'
%               latter).
%
%           If FLAG_BATCH == 1, the pipeline manager is started as a
%               separate process in its own Matlab or Octave session using
%               the 'at' system command. The pipeline will thus run in the
%               background and you can continue to work, close matlab or
%               even unlog from your machine on a linux system without
%               interrupting it.
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
%       COMMAND_MATLAB
%           (string, default GB_PSOM_COMMAND_MATLAB or
%           GB_PSOM_COMMAND_OCTAVE depending on the current environment)
%           how to invoke matlab (or OCTAVE).
%           You may want to update that to add the full path of the command.
%           The defaut for this field can be set using the variable
%           GB_PSOM_COMMAND_MATLAB/OCTAVE in the file PSOM_GB_VARS.
%
%       TIME_BETWEEN_CHECKS
%           (real value, default 0 in 'session' mode, 10 otherwise)
%           The time (in seconds) where the pipeline processing remains
%           inactive to wait for jobs to complete before attempting to
%           submit new jobs.
%
%       NB_CHECKS_PER_POINT
%           (integer,defautlt 6) After NB_CHECK_PER_POINT successive checks
%           where the pipeline processor did not find anything to do, it
%           will issue a '.' verbose to show it is not dead.
%
% _________________________________________________________________________
% OUTPUTS:
%
% _________________________________________________________________________
% SEE ALSO:
%
% PSOM_PIPELINE_INIT, PSOM_PIPELINE_VISU, PSOM_DEMO_PIPELINE,
% PSOM_RUN_PIPELINE.
%
% _________________________________________________________________________
% COMMENTS:
%
% Empty file names, or file names equal to 'gb_niak_omitted' are ignored
% when building the dependency graph between jobs.
%
% Existing 'running' or 'failed' tags will be removed. Make sure the
% pipeline is not already running if the background if you do that. That
% behavior is useful to restart a pipeline that has somehow crashed.
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
if ~exist('file_pipeline','var')
    error('SYNTAX: [] = PSOM_PIPELINE_PROCESS(FILE_PIPELINE,OPT). Type ''help psom_pipeline_manage'' for more info.')
end

%% Options
gb_name_structure = 'opt';
gb_list_fields = {'shell_options','command_matlab','mode','flag_batch','max_queued','qsub_options','time_between_checks','nb_checks_per_point'};
gb_list_defaults = {'','','session',false,0,'',[],[]};
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
            opt.time_between_checks = 0;
            time_between_checks = 0;
        end
        if isempty(nb_checks_per_point)
            opt.nb_checks_per_point = Inf;
            nb_checks_per_point = Inf;
        end
    otherwise
        if isempty(time_between_checks)
            opt.time_between_checks = 10;
            time_between_checks = 10;
        end
        if isempty(nb_checks_per_point)
            opt.nb_checks_per_point = 6;
            nb_checks_per_point = 6;
        end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The pipeline processing starts now  %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Generating file names
[path_logs,name_pipeline,ext_pl] = fileparts(file_pipeline);
file_pipe_running = cat(2,path_logs,filesep,name_pipeline,'.running');
file_pipe_log = cat(2,path_logs,filesep,name_pipeline,'.log');
file_pipe_path = cat(2,path_logs,filesep,name_pipeline,'.path_def.mat');

%% Check for the existence of the pipeline
if ~exist(file_pipeline,'file') % Does the pipeline exist ?
    error('Could not find the pipeline file %s. You first need to initialize the pipeline using PSOM_PIPELINE_INIT !',file_pipeline);
end

%% If specified, start the pipeline in the background
if flag_batch

    switch opt.mode
        case 'qsub'
            fprintf('I am sending the pipeline manager in the background using the ''qsub'' command.\n')
        otherwise
            fprintf('I am sending the pipeline manager in the background using the ''at'' command.\n')
    end

    switch gb_psom_language
        case 'matlab'
            instr_job = sprintf('%s -nosplash -nojvm -logfile %s -r "cd %s, load %s, path(path_work), opt.nb_checks_per_point = %i; opt.time_between_checks = %1.3f; opt.command_matlab = ''%s''; opt.mode = ''%s''; opt.flag_batch = false; opt.max_queued = %i; opt.qsub_options = ''%s'', psom_pipeline_process(''%s'',opt),"\n',opt.command_matlab,file_pipe_log,path_logs,file_pipe_path,opt.nb_checks_per_point,opt.time_between_checks,opt.command_matlab,opt.mode,opt.max_queued,opt.qsub_options,file_pipeline);
        case 'octave'
            instr_job = sprintf('%s --silent --eval "diary ''%s'', cd %s, load %s, path(path_work), opt.nb_checks_per_point = %i; opt.time_between_checks = %1.3f; opt.command_matlab = ''%s''; opt.mode = ''%s''; opt.flag_batch = false; opt.max_queued = %i; opt.qsub_options = ''%s'', psom_pipeline_process(''%s'',opt),"\n',opt.command_matlab,file_pipe_log,path_logs,file_pipe_path,opt.nb_checks_per_point,opt.time_between_checks,opt.command_matlab,opt.mode,opt.max_queued,opt.qsub_options,file_pipeline);
    end

    file_shell = psom_file_tmp('_proc_pipe.sh');
    hf = fopen(file_shell,'w');
    fprintf(hf,'%s',instr_job);
    fclose(hf);

    switch opt.mode
        case 'qsub'
            file_qsub_o = [path_logs filesep name_pipeline '.oqsub'];
            file_qsub_e = [path_logs filesep name_pipeline '.eqsub'];
            instr_batch = ['qsub -e ' file_qsub_e ' -o ' file_qsub_o ' -N ' name_pipeline(1:min(15,length(name_pipeline))) ' ' opt.qsub_options ' ' file_shell];
        otherwise
            instr_batch = ['at -f ' file_shell ' now'];
    end
    [fail,msg] = system(instr_batch);
    if fail~=0
        error('Something went bad with the at command. The error message was : %s',msg)
    end

    delete(file_shell)
    return
end

% a try/catch block is used to clean temporary file if the user is
% interrupting the pipeline of if an error occurs
try

    %% Check if the pipeline was not already running
    if exist(file_pipe_running,'file') % Is the pipeline running ?
        fprintf('A running tag has been found on the pipeline ! This means the pipeline was either running or crashed.\nI will assume it crashed and restart the pipeline.\n')
        delete(file_pipe_running);
    end
    str_now = datestr(clock);
    save(file_pipe_running,'str_now'); %% Put a running tag on the pipeline
    
    %% Load the pipeline
    fprintf('Loading the pipeline dependencies ...\n')
    load(file_pipeline,'list_jobs','deps','graph_deps','files_in');

    %% Check if all the files necessary to complete the pipeline can be found
    flag_ready = true;
    fprintf('Checking if all the files necessary to complete the pipeline can be found ...\n')
    for num_j = 1:length(list_jobs)

        name_job = list_jobs{num_j};
        list_files_needed = files_in.(name_job);
        list_files_tobe = psom_files2cell(deps.(name_job));
        list_files_necessary = list_files_needed(~ismember(list_files_needed,list_files_tobe));

        for num_f = 1:length(list_files_necessary)
            if ~exist(list_files_necessary{num_f},'file')&~isempty(list_files_necessary{num_f})&~strcmp(list_files_necessary{num_f},'gb_niak_omitted')
                fprintf('The file %s is necessary to run job %s, but is unfortunately missing.\n',list_files_necessary{num_f},name_job)
                flag_ready = false;
            end
        end
    end
    clear files_in

    if ~flag_ready
        error('Some files are missing, sorry dude I must quit ...')
    end

    %% Clean up left-over 'running' tags
    fprintf('Checking the current status of jobs ...\n')
    curr_status = psom_job_status(path_logs,list_jobs);
    mask_running = ismember(curr_status,'running'); % running jobs

    fprintf('Checking for ''running'' tags ...\n')
    if max(mask_running)>0
        fprintf('   Some running tags were found on some jobs before even starting the pipeline. I reseted all tags to ''none''.\n');
        list_jobs_running = list_jobs(mask_running);
        for num_f = 1:length(list_jobs_running)
            file_running = [path_logs filesep list_jobs_running{num_f} '.running'];
            delete(file_running)
        end
    end

    fprintf('Checking for ''failed'' tags ...\n')
    %% Clean up left-over 'failed' tags
    mask_failed = ismember(curr_status,{'failed'}); % failed jobs
    if max(mask_failed)>0
        fprintf('Some failed tags were found on some jobs. I will restart them.\n');
        list_jobs_failed = list_jobs(mask_failed);
        for num_f = 1:length(list_jobs_failed)
            file_failed = [path_logs filesep list_jobs_failed{num_f} '.failed'];
            delete(file_failed)
        end
    end

    %% Clean up log files for unfinished jobs
    fprintf('Clean up left-over ''log'', ''exit'' and ''qsub'' error/outputs of unfinished jobs ...\n')
    mask_unfinished = ~ismember(curr_status,'finished'); % non finished jobs
    if max(mask_unfinished)>0
        list_jobs_unfinished = list_jobs(mask_unfinished);
        for num_f = 1:length(list_jobs_unfinished)
            name_job = list_jobs_unfinished{num_f};
            file_log = [path_logs filesep name_job '.log'];
            file_exit = [path_logs filesep name_job '.exit'];
            
            if exist(file_log,'file')
                system(['rm ' file_log]);
            end
            
            if exist(file_exit,'file')
                system(['rm ' file_exit]);
            end

        end
    end

    %%%%%%%%%%%%%%%%%%%%%%
    %% Run the pipeline %%
    %%%%%%%%%%%%%%%%%%%%%%

    %% Print general info about the pipeline
    msg = sprintf('The pipeline %s is now being processed.\nStarted on %s\nUser: %s\nhost : %s\nsystem : %s',name_pipeline,datestr(clock),gb_psom_user,gb_psom_localhost,gb_psom_OS);
    stars = repmat('*',[1 30]);
    fprintf('\n%s\n%s\n%s\n',stars,msg,stars);

    nb_checks = 0;
    nb_points = 0;
    path_tmp = [path_logs tmp]; % Create a temporary folder for shell scripts
    if exist(path_tmp,'dir')
        rmdir(path_tmp,'s');
    end
    mkdir(path_tmp);

    %% Initialize job status
    fprintf('Initializing job status ...\n')
    mask_todo = ~ismember(curr_status,{'finished'}); % done jobs (there is no failed jobs at this stage)
    mask_todo = mask_todo(:);
    mask_done = ~mask_todo;
    mask_running = mask_done; % Start back at the point where all the finished jobs have just finished
    nb_queued = sum(mask_running);

    %% Loop until there are jobs to do, or some jobs are still running
    fprintf('The pipeline manager starts now !\n')
    
    while (max(mask_todo)>0) || (max(mask_running)>0)

        flag_nothing_happened = true;

        %% Update the status of running jobs
        list_jobs_running = list_jobs(mask_running);
        list_num_running = find(mask_running);
        new_status_running_jobs = psom_job_status(path_logs,list_jobs_running);
        mask_done(mask_running) = ismember(new_status_running_jobs,{'finished','failed'});
        mask_todo(mask_running) = mask_todo(mask_running)&~mask_done(mask_running);

        %% In qsub mode, check if a script crashed ('exit' tag)
        if strcmp(opt.mode,'qsub')
            mask_exit = ismember(new_status_running_jobs,{'exit'});
            list_num_exit = find(mask_exit);
            list_num_exit = list_num_exit(:)';
            for num_f = list_num_exit
                name_job = list_jobs_running{num_f};
                fprintf('%s - The script of job %s terminated without generating any tag, I guess we will count that one as failed (%i jobs in queue).\n',datestr(clock),name_job,nb_queued);
                file_failed = [path_logs filesep name_job '.failed']; % put a failed tag
                system(['touch ' file_failed]);
                new_status_running_jobs{num_f} = 'failed';
            end
        end

        %% Remove the children of failed jobs from the to-do list
        mask_failed = ismember(new_status_running_jobs,'failed');

        if max(mask_failed)>0
            list_num_failed = list_num_running(mask_failed);
            list_num_failed = list_num_failed(:)';
            list_jobs_failed = list_jobs_running(mask_failed);

            if flag_nothing_happened
                flag_nothing_happened = false;
                nb_checks = 0;
                if nb_points>0
                    fprintf('\n');
                end
                nb_points = 0;
            end
            for num_f = 1:length(list_jobs_failed)
                name_job = list_jobs_failed{num_f};
                nb_queued = nb_queued - 1;
                fprintf('%s - The job %s has failed (%i jobs in queue).\n',datestr(clock),name_job,nb_queued);
            end

            for num_j = list_num_failed
                list_num_child = find(sub_find_children(num_j,graph_deps));
                mask_todo(list_num_child) = false;
            end
        end

        %% Remove the dependencies on finished jobs
        mask_finished = ismember(new_status_running_jobs,'finished');

        if max(mask_finished)>0

            list_num_finished = list_num_running(mask_finished);
            list_num_finished = list_num_finished(:)';
            list_jobs_finished = list_jobs_running(mask_finished);

            if flag_nothing_happened
                flag_nothing_happened = false;
                nb_checks = 0;
                if nb_points>0
                    fprintf('\n');
                end
                nb_points = 0;
            end

            for num_f = 1:length(list_jobs_finished)
                name_job = list_jobs_finished{num_f};
                nb_queued = nb_queued - 1;
                fprintf('%s - The job %s has been successfully completed (%i jobs in queue).\n',datestr(clock),name_job,nb_queued);
            end

            %% update dependencies
            graph_deps(list_num_finished,:) = 0;
        end

        %% Update the dependency mask
        mask_deps = max(graph_deps,[],1)>0;
        mask_deps = mask_deps(:);

        %% Finally update the list of currently running jobs
        mask_running(mask_running) = mask_running(mask_running)&~mask_done(mask_running);

        %% Time to submit jobs !!
        list_num_to_run = find(mask_todo&~mask_deps);
        num_jr = 1;

        while (nb_queued < max_queued) && (num_jr <= length(list_num_to_run))

            if flag_nothing_happened
                flag_nothing_happened = false;
                nb_checks = 0;
                if nb_points>0
                    fprintf('\n');
                end
                nb_points = 0;
            end

            %% Pick up a job to run
            num_job = list_num_to_run(num_jr);
            num_jr = num_jr + 1;
            name_job = list_jobs{num_job};
            file_job = [path_logs filesep name_job '.mat'];
            file_log = [path_logs filesep name_job '.log'];
            mask_todo(num_job) = false;
            mask_running(num_job) = true;
            nb_queued = nb_queued + 1;
            fprintf('%s - The job %s is now running (%i jobs in queue).\n',datestr(clock),name_job,nb_queued)

            %% Create a temporary shell scripts for 'batch' or 'qsub' modes
            if ~strcmp(opt.mode,'session')

                switch gb_psom_language
                    case 'matlab'
                        if ~isempty(opt.shell_options)
                            instr_job = sprintf('%s\n%s -nosplash -nojvm -r "cd %s, load %s, path(path_work), psom_run_job(''%s''),">%s\n',opt.shell_options,opt.command_matlab,path_logs,file_pipe_path,file_job,file_log);
                        else
                            instr_job = sprintf('%s -nosplash -nojvm -r "cd %s, load %s, path(path_work), psom_run_job(''%s''),">%s\n',opt.command_matlab,path_logs,file_pipe_path,file_job,file_log);
                        end
                    case 'octave'
                        if ~isempty(opt.shell_options)
                            instr_job = sprintf('%s\n%s --eval "cd %s, load %s, path(path_work), psom_run_job(''%s''),">%s\n',opt.shell_options,opt.shell_options,opt.command_matlab,path_logs,file_pipe_path,file_job,file_log);
                        else
                            instr_job = sprintf('%s --eval "cd %s, load %s, path(path_work), psom_run_job(''%s''),">%s\n',opt.shell_options,opt.command_matlab,path_logs,file_pipe_path,file_job,file_log);
                        end
                end

                file_shell = [path_tmp filesep name_job '.sh'];
                file_exit = [path_logs filesep name_job '.exit'];
                hf = fopen(file_shell,'w');
                fprintf(hf,'%s\ntouch %s',instr_job,file_exit);
                fclose(hf);

            end

            %% run the job

            switch opt.mode

                case 'session'

                    psom_run_job(file_job);

                case 'batch'

                    instr_batch = ['at -f ' file_shell ' now'];
                    [fail,msg] = system(instr_batch);
                    if fail~=0
                        error('Something went bad with the at command. The command was : %s . The error message was : %s',instr_batch,msg)
                    end

                case 'qsub'

                    file_qsub_o = [path_logs filesep name_job '.oqsub'];
                    file_qsub_e = [path_logs filesep name_job '.eqsub'];

                    instr_qsub = ['qsub -e ' file_qsub_e ' -o ' file_qsub_o ' -N ' name_job(1:min(15,length(name_job))) ' ' opt.qsub_options ' ' file_shell];
                    [fail,msg] = system(instr_qsub);
                    if fail~=0
                        error('Something went bad with the qsub command. The command was : %s . The error message was : %s',instr_qsub,msg)
                    end
                    
            end % switch mode
        end % submit jobs

        pause(time_between_checks); % To avoid wasting resources, wait a bit before re-trying to submit jobs

        if nb_checks >= nb_checks_per_point
            nb_checks = 0;
            fprintf('.')
            nb_points = nb_points+1;
        else
            nb_checks = nb_checks+1;
        end

    end % While there are jobs to do

catch

    errmsg = lasterror;
    
    if exist('path_tmp','var')
        if exist(path_tmp,'dir')
            rmdir(path_tmp,'s'); % Clean the temporary folder
        end
    end

    if exist('file_pipe_running','var')
        if exist(file_pipe_running,'file')
            delete(file_pipe_running); % remove the 'running' tag
        end
    end

    fprintf('\n\n******************\nSomething went bad ... the pipeline has FAILED !\nThe last error message occured was :\n%s\n',errmsg.message);
    if isfield(errmsg,'stack')
        for num_e = 1:length(errmsg.stack)
            fprintf('File %s at line %i\n',errmsg.stack(num_e).file,errmsg.stack(num_e).line);
        end
    end

end

if exist('path_tmp','var')
    if exist(path_tmp,'dir')
        rmdir(path_tmp,'s'); % Clean the temporary folder
    end
end

if exist('file_pipe_running','var')
    if exist(file_pipe_running,'file')
        delete(file_pipe_running); % remove the 'running' tag
    end
end

%% Print general info about the job
msg = sprintf('The processing of the pipeline %s was closed on %s',name_pipeline,datestr(clock));
stars = repmat('*',[1 length(msg)]);
fprintf('\n%s\n%s\n%s\n',stars,msg,stars);


%%%%%%%%%%%%%%%%%%
%% subfunctions %%
%%%%%%%%%%%%%%%%%%

function mask_child = sub_find_children(num_j,graph_deps)
%% GRAPH_DEPS(J,K) == 1 if and only if JOB K depends on JOB J. GRAPH_DEPS =
%% 0 otherwise. This (ugly but reasonably fast) recursive code will work
%% only if the directed graph defined by GRAPH_DEPS is acyclic.
mask_child = graph_deps(num_j,:);
list_num_child = find(mask_child);

if ~isempty(list_num_child)
    for num_c = list_num_child        
        mask_child = mask_child | sub_find_children(num_c,graph_deps);
    end
end