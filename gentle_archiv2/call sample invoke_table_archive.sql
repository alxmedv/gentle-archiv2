
exec invoke_table_archive 'ProbeLogLines'

exec invoke_table_archive 
	@pTableName = 'ProbeLogLines',
	@pProbeId = NULL,
	@pMeasurementTypes = 0,
	@pMaxReceivedTime = '2024-01-01',
	@pNbOfLinesToMove = 1000000,
	@degree = 8,
	@async = 1


exec invoke_table_archive 
	@pTableName = 'VoltLogLines',
	@pProbeId = NULL,
	@pMeasurementTypes = 0,
	@pMaxReceivedTime = '2024-01-01',
	@pNbOfLinesToMove = 1000000,
	@degree = 8,
	@async = 1

exec invoke_table_archive 
	@pTableName = 'LcsLoglines',
	@pProbeId = NULL,
	@pMeasurementTypes = NULL,
	@pMaxReceivedTime = '2024-01-01',
	@pNbOfLinesToMove = 10000,
	@degree = 0,
	@async = 0

exec create_job 'Arc_VoltLoglines'

exec create_job 'Arc_ProbeLoglines'

exec create_job 'Arc_LcsLoglines'


/*
delete from job_status
delete from job_log
*/

select * from job_status

select * from job_log
order by 1 desc

select count(*) from [dbo].[VoltLoglines]
select count(*) from [dbo].[ProbeLoglines]
select count(*) from [dbo].[LcsLoglines]
--truncate table [dbo].[VoltLoglines];
--truncate table [dbo].[ProbeLoglines];
--truncate table [dbo].[LcsLoglines];
--exec delete_job 'Arc_VoltLogLines'

/* delete jobs and their traces */
exec cleanup_job @status='completed'
exec cleanup_job 'Arc_LcsLoglines'

delete from job_status where status_desc='init(x)'

exec stop_job 'Arc_LcsLoglines', @cleanup=1




