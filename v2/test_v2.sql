exec dbo.invoke_ga
	@job_name = 'ga_Wanted',
	@pTableName = 'bricklink.dbo.Wanted',
	@pKeyCol = 'wantedID',
	@pNbOfRowsToMove = 100000

--delete ga_status where job_id='2D49859C-B216-4622-9D49-558FDA35715F'

exec [dbo].[populate_ga] 'ga_Wanted'


select top 3 * from ga_status order by start_time desc


select top 10 * from ga_log order by ts desc

