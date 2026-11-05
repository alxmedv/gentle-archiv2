
--exec adjust_agent_job N'$(ESCAPE_SQUOTE(JOBNAME))'

create or alter procedure adjust_agent_job @agent_job_name varchar(50)
as

declare @new_interval_min int;
declare @schedule_id int;

select top 1 
    @new_interval_min = 
        case when estimated_rows+committed_rows = 0 then 60 --set interval to 1 hr if the last run was empty
        else datediff(minute,start_time,end_time)+1 --adjust interval closer to last duration
        end
from ga_status gs 
where status_desc in ('completed','completed(x)','stopped')
order by start_time desc

SELECT
    @schedule_id = s.schedule_id,
    @new_interval_min = case when abs(@new_interval_min-s.freq_subday_interval)>1
    then @new_interval_min else null end
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js
    ON j.job_id = js.job_id
JOIN msdb.dbo.sysschedules s
    ON js.schedule_id = s.schedule_id
WHERE j.name = @agent_job_name
and s.freq_type = 4 -- 4 = Daily
and s.freq_subday_type = 4; -- 4 = Minutes


if @schedule_id is not null and @new_interval_min is not null
begin
    print 'update schedule interval to '+cast(@new_interval_min as varchar(10))
    EXEC msdb.dbo.sp_update_schedule
        @schedule_id = @schedule_id,
        @freq_subday_type = 4,    
        @freq_subday_interval = @new_interval_min ; 
end
else 
    print 'no schedule update'
