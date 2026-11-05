create or alter procedure build_jobindex 
	@job_id uniqueidentifier,
	@pNbOfRowsToMove bigint,
	@pTableName sysname,
	@pTrgTableName sysname,
	@pKeyCol nvarchar(200),
	@params_txt nvarchar(max),
	@last_keyid bigint,
	@silent bit = 1,
	@est_count bigint out
as
declare @stmt nvarchar(max);

begin try
	if object_id('ga_jobindex_' + cast(@job_id as nvarchar(200))) is not null
	raiserror('jobindex table exists', 16, 1);

	select @stmt =
		'select '
		+ case when isnull(@pNbOfRowsToMove,0) > 0
			then 'top ('+cast(@pNbOfRowsToMove as nvarchar(20))+') ' else '' end
		+ @pKeyCol + ' as rowkey,'
		+ ' row_number() over (order by '+@pKeyCol+' asc ) as rownum'
		+ ' into "ga_jobindex_' + cast(@job_id as nvarchar(200))+'"'
		+ ' from '+@pTableName+' st with (nolock) where 1=1 ' + isnull(@params_txt,'')
		+ case when isnull(@last_keyid,0) > 0 
			then ' and '+@pKeyCol+'>'+cast(@last_keyid as varchar(20)) else '' end
		+ ' and not exists (select 1 from '+@pTrgTableName+' where '+@pKeyCol+'=st.'+@pKeyCol+')'
		+ '; set @ec = @@rowcount;'

	if @stmt is null
		raiserror('NULL enum statement', 16, 1);

	if @silent = 0
		select @stmt as stmt
		
	execute sp_executesql @stmt, @params = N'@ec bigint out', @ec = @est_count output;

end try
begin catch
	declare @emsg nvarchar(2000) = 'Fail build_jobindex: '+error_message();
	raiserror(@emsg, 16, 1);
end catch
