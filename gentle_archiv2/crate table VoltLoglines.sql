
/****** Object:  Table [dbo].[VoltLoglines]    Script Date: 09-04-2024 17:32:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP TABLE IF EXISTS [dbo].[VoltLoglines];
GO

CREATE TABLE [dbo].[VoltLoglines](
	[ReceivedTime] [datetime] NOT NULL,
	[Uac] [float] NULL,
	[Warning] [int] NOT NULL,
	[ProbeLogLineId] [int] NOT NULL,
	[ProbeId] [int] NOT NULL,
	[SourceId] [int] NULL,
	[dataSource] [int] NOT NULL,
	[DataSourceId] [int] NULL,
	[UserId] [uniqueidentifier] NULL,
	[TagId] [int] NOT NULL,
	[Edc] [float] NULL,
	[Temperature] [float] NULL,
	[Power] [float] NULL,
	[UtcTimeOffset] [float] NULL,
	[OriginalErrCode] [int] NULL,
	[SensorDetails] [nvarchar](48) NULL,
	[MeasurementTypes] [int] NOT NULL,
	[Eoff] [float] NULL,
	[EoffStructure] [float] NULL,
	[UpdateDone] [bit] NULL,
	[CampaignId] [int] NOT NULL,
	[WebRegisteredTime] [datetime] NULL,
 CONSTRAINT [PK_VoltLogLines_PT] PRIMARY KEY NONCLUSTERED 
(
	[ProbeLogLineId] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
) ON [ps_LOGYEAR]([ReceivedTime])
GO

ALTER TABLE [dbo].[VoltLoglines] ADD  DEFAULT ((0)) FOR [ProbeId]
GO

ALTER TABLE [dbo].[VoltLoglines] ADD  DEFAULT ((0)) FOR [dataSource]
GO

ALTER TABLE [dbo].[VoltLoglines] ADD  DEFAULT ((0)) FOR [TagId]
GO

ALTER TABLE [dbo].[VoltLoglines] ADD  CONSTRAINT [DF_VoltLogLines_PT_MeasurementTypes]  DEFAULT ((0)) FOR [MeasurementTypes]
GO

ALTER TABLE [dbo].[VoltLoglines] ADD  DEFAULT ((0)) FOR [CampaignId]
GO


CREATE CLUSTERED INDEX [Cl_VoltLoglines_PT] ON [dbo].[VoltLoglines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

CREATE NONCLUSTERED INDEX [Non_Clustered_ProdeId_fk] ON [dbo].[VoltLoglines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC
)
INCLUDE([Uac],[Warning],[ProbeLogLineId],[dataSource],[DataSourceId],[UserId],[TagId],[Edc],[Power],[Temperature],[UtcTimeOffset],[OriginalErrCode],[SensorDetails],[MeasurementTypes],[Eoff],[UpdateDone],[EoffStructure],[CampaignId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

CREATE NONCLUSTERED INDEX [VoltLoglines_ProbeId_2_PT] ON [dbo].[VoltLoglines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC,
	[MeasurementTypes] ASC
)
INCLUDE([Uac],[Warning],[ProbeLogLineId],[dataSource],[DataSourceId],[UserId],[TagId],[Edc],[Temperature],[Power],[UtcTimeOffset],[OriginalErrCode],[SensorDetails],[Eoff],[EoffStructure],[UpdateDone],[CampaignId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

CREATE NONCLUSTERED INDEX [VoltLoglines_ProbeId_PT] ON [dbo].[VoltLoglines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

CREATE NONCLUSTERED INDEX [VoltLoglines_ProbeId_PT_Inc] ON [dbo].[VoltLoglines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC
)
INCLUDE([Uac],[Warning],[ProbeLogLineId],[dataSource],[DataSourceId],[UserId],[TagId],[Edc],[Temperature],[Power],[UtcTimeOffset],[OriginalErrCode],[SensorDetails],[MeasurementTypes],[Eoff],[EoffStructure],[UpdateDone],[CampaignId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

--/****** Object:  Index [VoltLoglines_ProbeId_ReceivedTime_PT]    Script Date: 09-04-2024 17:36:36 ******/
--CREATE NONCLUSTERED INDEX [VoltLoglines_ProbeId_ReceivedTime_PT] ON [dbo].[VoltLoglines]
--(
--	[ProbeId] ASC,
--	[ReceivedTime] ASC
--)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
--GO

CREATE NONCLUSTERED INDEX [VoltLoglines_ProbeLogLineId] ON [dbo].[VoltLoglines]
(
	[ProbeLogLineId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [VoltLoglines_ReceivedTime_PT] ON [dbo].[VoltLoglines]
(
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO