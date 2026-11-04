USE DBA
GO
/****** Object:  StoredProcedure [dbo].[delete_job]    Script Date: 15-04-2024 18:30:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create or alter procedure [dbo].[cleanup_ga]
	@job_name nvarchar(200) = NULL, @job_id nvarchar(50) = NULL, @status nvarchar(40) = NULL
as

if @status = 'orphaned'
begin
	delete ga_log where job_id not in (	select job_id from ga_status ) or job_id is null
	return
end


--declare @job_id uniqueidentifier;
declare @degree int = 0;
declare @jobname nvarchar(128);
declare @jobid_tx nvarchar(50); 
declare @thread tinyint = 0;
declare @threadsuffix nvarchar(100);


declare job_cur cursor
for 
select 
	cast(job_id as nvarchar(50)),
	job_id, 
	parallel_degree
from ga_status  
where 
	(cast(job_id as nvarchar(50))=@job_id)
	or ( @job_id is null and (job_name = @job_name and status_desc in ('stopped','failed','completed','init')) ) 
	or ( @job_id is null and @job_name is null and status_desc = @status )
order by start_time
for read only;

open job_cur 
fetch next from job_cur into @jobid_tx,@job_id,@degree;

print 'delete jobs'

while @@fetch_status = 0 
begin --while job_Cur
	if exists (
		select 1 from msdb.dbo.sysjobs sj where sj.name like 'job_'+@jobid_tx +'._'
	)
	begin
		print @jobid_tx
		set @thread = 0 ;

		while @thread < @degree
		begin --while

			set @threadsuffix = case when @degree > 0 then '.'+cast(@thread as nvarchar(5)) else '' end;
			set @jobname = 'job_' + @jobid_tx + @threadsuffix;

			print @jobname
			EXEC msdb.dbo.sp_delete_job @job_name = @jobname ;  

			set @thread = @thread+1

		end--while
	end

	print 'delete ga_logs'
	delete ga_log where cast(job_id as nvarchar(50))=@jobid_tx;


	declare @shedulename nvarchar(100) = 'jobSchedule_' + @jobid_tx;
	declare @sheduleid int;

	declare schedule_cur cursor
	for select schedule_id from msdb.dbo.sysschedules ss where ss.name = @shedulename for read only;
	open schedule_cur 
	fetch next from schedule_cur into @sheduleid;

	print 'delete schedules'
	while @@fetch_status = 0 
	begin
		print @shedulename
		EXEC msdb.dbo.sp_delete_schedule @schedule_id = @sheduleid;  

		fetch next from schedule_cur into @sheduleid;
	end
	close schedule_cur;
	deallocate schedule_cur;

	update ga_status set status_desc = status_desc + '(x)'
	where job_id = @job_id;

	fetch next from job_cur into @jobid_tx,@job_id,@degree;

end --while job_Cur

close job_cur;
deallocate job_cur;

