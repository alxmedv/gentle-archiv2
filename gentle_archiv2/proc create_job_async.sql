use [MetriCorr_WebTestOldData]
go

alter procedure create_job_async
	@job_id uniqueidentifier	
as

declare @job_name nvarchar(200);
declare @degree int = 0;
declare @async bit = 0;
declare @params_txt varchar(max) = '';
declare @est_count bigint = 0, @req_count bigint = 0, @com_count bigint = 0;
declare @jobname nvarchar(128);

select top 1 
	@job_name = job_name, 
	@est_count = estimated_rows,
	@req_count = requested_rows,
	@degree = parallel_degree,
	@async = job_async,
	@params_txt = params
from job_status 
where @job_id = @job_id and status_desc in ('init') order by start_time

declare @thread tinyint = 0;
declare @jobstep1sql nvarchar(2000);
declare @threadsuffix nvarchar(100);
declare @shedulename nvarchar(100) = 'jobSchedule_'+(cast(@job_id as nvarchar(40)));
declare @dbname nvarchar(100) = db_name(db_id());
declare @database_user nvarchar(100) = system_user;
declare @starttime int;

select @starttime=cast(replace(convert(nvarchar(10),dateadd(n,1,getdate()),108),':','') as int);

print 'create job schedule '+@shedulename

EXEC msdb.dbo.sp_add_schedule  
	@schedule_name = @shedulename,  
	@freq_type = 1,  
	@active_start_time = @starttime ;  

if @degree>0
	set @req_count = @req_count/@degree;

while @thread < @degree
begin --while

	set @threadsuffix = case when @degree > 0 then '.'+cast(@thread as nvarchar(5)) else '' end;
	set @jobname = 'job_'+(cast(@job_id as nvarchar(40)))+@threadsuffix;

	set @jobstep1sql = N'exec populate_archive @job_name='''+@job_name+''''
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

--select js.job_id, sj.name
--from job_status js join msdb.dbo.sysjobs sj on sj.name like 'job_'+cast(js.job_id as nvarchar(50)) +'._'
--where js.job_name = @job_name 

GO

