exec dbo.invoke_ga
	@job_name = 'ga_Wanted',
	@pTableName = 'bricklink.dbo.Wanted',
	@pKeyCol = 'wantedID',
	@pNbOfRowsToMove = 100000,
	@async = 1

--delete ga_status where job_id='6642A421-A7E6-4697-ACC2-32BD8A95B391'

exec dbo.create_ga_job 'ga_Wanted'

exec [dbo].[populate_ga] 'ga_Wanted'

exec [dbo].[cleanup_ga] @status = 'completed'--'ga_Wanted'

exec [dbo].[cleanup_ga] '6642A421-A7E6-4697-ACC2-32BD8A95B391'


select top 3 * from ga_status order by start_time desc


select * from ga_log order by ts desc

