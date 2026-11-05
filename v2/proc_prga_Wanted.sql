USE DBA
GO

create or alter procedure dbo.prga_Wanted
	@parkeys gaBatchKeyType READONLY, @rows_affected bigint OUTPUT
AS
	set identity_insert bricklink.[dbo].[ga_Wanted] on

	insert into bricklink.[dbo].[ga_Wanted]
			([wantedColor], [wantedPrice], [wantedQty], [wantedUserID], [wantedNew], [wantedItemID], [wantedNotify], [wantedRemarks], [wantedMoreID], [wantedID], [wantedQtyFilled], [wantedDtCreate], [wantedDtModified], [wantedUploadFrom], [srcLocation])
	select 
		[wantedColor], [wantedPrice], [wantedQty], [wantedUserID], [wantedNew], [wantedItemID], [wantedNotify], [wantedRemarks], [wantedMoreID], [wantedID], [wantedQtyFilled], [wantedDtCreate], [wantedDtModified], [wantedUploadFrom], [srcLocation]
		from bricklink.[dbo].[Wanted] with (nolock)
		where [wantedID] in (select [rowkey] from @parkeys)

	select @rows_affected = @@ROWCOUNT;
	set identity_insert bricklink.[dbo].[ga_Wanted] off
	
GO


--select 
--[wantedColor], [wantedPrice], [wantedQty], [wantedUserID], [wantedNew], [wantedItemID], [wantedNotify], [wantedRemarks], [wantedMoreID], [wantedID], [wantedQtyFilled], [wantedDtCreate], [wantedDtModified], [wantedUploadFrom], [srcLocation]
--into bricklink.[dbo].[ga_Wanted]
--from bricklink.[dbo].[Wanted] with (nolock)
--where 1=0
--CREATE INDEX [IX_ga_Wanted_1] ON [dbo].[ga_Wanted] ([wantedID])


--select count(*) from bricklink.[dbo].[ga_Wanted]

--truncate table bricklink.[dbo].[ga_Wanted]
