use DBA
go

create or alter procedure create_ga_job_async
	@job_id uniqueidentifier	
as

declare @job_name nvarchar(200);
declare @job_idtx nvarchar(200);
declare @degree int = 0;
declare @async bit = 0;
declare @params_txt varchar(max) = '';
declare @est_count bigint = 0, @req_count bigint = 0, @com_count bigint = 0;
declare @jobname nvarchar(128);

declare @thread tinyint = 0;
declare @jobstep1sql nvarchar(2000);
declare @threadsuffix nvarchar(100);
declare @shedulename nvarchar(100);
declare @dbname nvarchar(100) = db_name(db_id());
declare @database_user nvarchar(100) = system_user;
declare @starttime int;

begin try

select top 1 
	@job_name = job_name, 
	@job_idtx = cast(job_id as nvarchar(40)),
	@est_count = estimated_rows,
	@req_count = requested_rows,
	@degree = parallel_degree,
	@async = job_async,
	@params_txt = params
from ga_status 
where job_id = @job_id and status_desc in ('init') order by start_time

if @job_idtx is null
begin
	print 'No initialized job found for '+cast(@job_id as nvarchar(40))
	return
end

if exists (select 1 from msdb.dbo.sysjobs sj where sj.name like 'job_'+@job_idtx+'._')
begin
	print 'Requested job(s) exists ' + 'job_'+@job_idtx+'._'
	return
end

set @shedulename = 'jobSchedule_'+@job_idtx

if exists (select 1 from msdb.dbo.sysschedules ss where ss.name = @shedulename)  
raiserror('Requested job schedule exists without job', 16, 1);

select @starttime=cast(replace(convert(nvarchar(10),dateadd(n,1,getdate()),108),':','') as int);

print 'create job schedule '+@shedulename

EXEC msdb.dbo.sp_add_schedule  
	@schedule_name = @shedulename,  
	@freq_type = 1,  
	@active_start_time = @starttime ;  

if isnull(@degree,0)=0
	set @degree = 1;

if @degree>0
	set @req_count = @req_count/@degree;

while @thread < @degree
begin --while

	set @threadsuffix = case when @degree > 0 then '.'+cast(@thread as nvarchar(5)) else '' end;
	set @jobname = 'job_'+@job_idtx+@threadsuffix;

	set @jobstep1sql = N'exec populate_ga @job_name='''+@job_name+''''
		+ case when @degree > 0 then ', @threadno='+cast(@thread as nvarchar(5)) else '' end

	EXEC msdb.dbo.sp_add_job @job_name = @jobname, @enabled = 1 ;  
	EXEC msdb.dbo.sp_add_jobstep  
		@job_name = @jobname,  
		@step_name = N'Step 1',  
		@subsystem = N'TSQL',  
		@database_name = @dbname,
		@command = @jobstep1sql,   
		@retry_attempts = 0,  
		@retry_interval = 0 ;  

	EXEC msdb.dbo.sp_attach_schedule  
	   @job_name = @jobname, 
	   @schedule_name = @shedulename;  

	EXEC msdb.dbo.sp_add_jobserver @job_name = @jobname;  

	print 'create job '+@jobname

	set @thread = @thread+1
end--while

end try
	
begin catch
	print 'create job failed ' + @job_idtx
	update ga_status set status_desc = 'failed'	where job_id = @job_id 
end catch

--select js.job_id, sj.name
--from ga_status js join msdb.dbo.sysjobs sj on sj.name like 'job_'+cast(js.job_id as nvarchar(50)) +'._'
--where js.job_name = @job_name 

GO

