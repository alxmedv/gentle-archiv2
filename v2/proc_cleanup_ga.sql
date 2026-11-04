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

declare @stmt nvarchar(max);

if @status = 'orphaned'
begin
	--delete orphaned logs
	delete ga_log where job_id not in (	select job_id from ga_status ) or job_id is null;
	
	--drop orphaned index tables
	declare cur_orph_jobindex cursor for 
		select 'drop table "'+name+'"' from sys.tables 
		where name like 'ga_jobindex_%'
		and name not in (select 'ga_jobindex_' + cast(job_id as nvarchar(200)) from ga_status)
	open cur_orph_jobindex 
	fetch cur_orph_jobindex into @stmt;
	while @@FETCH_STATUS=0
	begin
		print @stmt
		exec @stmt
		fetch cur_orph_jobindex into @stmt
	end
	close cur_orph_jobindex;
	deallocate cur_orph_jobindex;
	
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
	case when isnull(parallel_degree,0) = 0 then 1 else parallel_degree end
from ga_status  
where 
	(cast(job_id as nvarchar(50))=@job_id)
	or ( @job_id is null and (job_name = @job_name and status_desc in ('stopped','failed','completed','init')) ) 
	or ( @job_id is null and @job_name is null and status_desc = @status )
order by start_time
for read only;

open job_cur 
fetch next from job_cur into @jobid_tx,@job_id,@degree;

while @@fetch_status = 0 
begin --while job_Cur
	print 'delete job ' + @jobid_tx
	if exists (select 1 from msdb.dbo.sysjobs sj where sj.name like 'job_'+@jobid_tx +'._')
	begin
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

	declare @shedulename nvarchar(100) = 'jobSchedule_' + @jobid_tx;
	declare @sheduleid int;

	declare schedule_cur cursor
	for select schedule_id from msdb.dbo.sysschedules ss where ss.name = @shedulename for read only;

	open schedule_cur 
	fetch next from schedule_cur into @sheduleid;

	while @@fetch_status = 0 
	begin
		print 'delete schedule ' + @shedulename + ', id:' + cast(@sheduleid as nvarchar(20))
		EXEC msdb.dbo.sp_delete_schedule @schedule_id = @sheduleid;  

		fetch next from schedule_cur into @sheduleid;
	end
	close schedule_cur;
	deallocate schedule_cur;

	select @stmt = 'drop table "'+name+'"' from sys.tables 
	where name = 'ga_jobindex_' + @jobid_tx
	print @stmt
	if @stmt is not null
		exec @stmt
	
	print 'delete ga_logs for '+@jobid_tx
	delete ga_log where cast(job_id as nvarchar(50))=@jobid_tx;

	update ga_status set status_desc = status_desc + '(x)'
	where job_id = @job_id;

	fetch next from job_cur into @jobid_tx,@job_id,@degree;

end --while job_Cur

close job_cur;
deallocate job_cur;

