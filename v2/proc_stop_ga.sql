USE DBA
GO


create or alter procedure [dbo].[stop_ga]
	@job_name nvarchar(200) = NULL, @job_id nvarchar(50) = NULL, @force int = 0, @cleanup int = 0
as

declare @status nvarchar(40) = NULL;
declare @degree int = 0;
declare @jobname nvarchar(128);
declare @jobstatus nvarchar(50);
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
	or ( @job_id is null and (job_name = @job_name and status_desc in ('run','init')) ) 
	--or ( @job_id is null and @job_name is null and status_desc = @status )
order by start_time
for read only;

open job_cur 
fetch next from job_cur into @jobid_tx,@job_id,@degree;

print 'stop jobs'

while @@fetch_status = 0 
begin --while job_Cur
		print @jobid_tx+': '++cast(@degree as nvarchar(10))
		set @thread = 0 ;

		update ga_status set status_desc = 'stopped'
		where job_id = @job_id;

		while @thread < @degree and @force = 1
		begin --while

			set @threadsuffix = case when @degree > 0 then '.'+cast(@thread as nvarchar(5)) else '' end;
			set @jobname = 'job_' + @jobid_tx + @threadsuffix;

			print 'look for '+@jobname

			select 
				@jobstatus = 
				case 
					when o.enabled = 0 then 'disabled'
					when oa.run_requested_date is null then 'idle'
					when jh.run_status = 0 then 'failed'
					when jh.run_status = 1 then 'succeeded'
					when jh.run_status = 2 then 'retry step'
					when jh.run_status = 3 then 'cancelled'
					when jh.run_status = 5 then 'unknown'
					when jh.run_status is null or jh.run_status = 4 then 'in progress'
				end        
			from msdb.dbo.sysjobs o 
			inner join msdb.dbo.sysjobactivity oa on (o.job_id = oa.job_id) 
			inner join (select max(session_id) as session_id from msdb.dbo.syssessions ) as s on (oa.session_id = s.session_id) 
			left join msdb.dbo.sysjobhistory jh on (oa.job_history_id = jh.instance_id) 
			where o.name = @jobname 

			if @jobstatus = 'in progress' 
			begin
				print 'stop job '+ @jobname
				EXEC msdb.dbo.sp_stop_job @job_name = @jobname
			end
			
			if @cleanup = 1
			begin
				print 'delete job '+ @jobname
				EXEC msdb.dbo.sp_delete_job @job_name = @jobname ;  
			end

			set @thread = @thread+1

		end--while

	if @cleanup = 1
	begin
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

	end 
	fetch next from job_cur into @jobid_tx,@job_id,@degree;

end --while job_Cur

close job_cur;
deallocate job_cur;
