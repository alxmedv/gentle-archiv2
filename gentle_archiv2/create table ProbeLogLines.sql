
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ProbeLogLines](
	[ProbeLogLineId] [int] NOT NULL,
	[ProbeId] [int] NOT NULL,
	[ReceivedTime] [datetime] NOT NULL,
	[Thickness] [float] NULL,
	[Uac] [float] NULL,
	[Iac] [float] NULL,
	[Jac] [float] NULL,
	[Rs] [float] NULL,
	[Idc] [float] NULL,
	[Jdc] [float] NULL,
	[Edc] [float] NULL,
	[Rr] [float] NULL,
	[Rc] [float] NULL,
	[Warning] [int] NOT NULL,
	[SourceId] [int] NULL,
	[Power] [float] NULL,
	[dataSource] [int] NOT NULL,
	[DataSourceId] [int] NULL,
	[UserId] [uniqueidentifier] NULL,
	[Eoff] [float] NULL,
	[Temperature] [float] NULL,
	[UtcTimeOffset] [float] NULL,
	[OriginalErrCode] [int] NULL,
	[SensorDetails] [nvarchar](48) NULL,
	[MeasurementTypes] [int] NOT NULL,
	[UpdateDone] [bit] NULL,
	[CampaignId] [int] NOT NULL,
	[Latitude] [float] NULL,
	[Longitude] [float] NULL,
	[TempCoupon] [float] NULL,
	[WebRegisteredTime] [datetime] NULL,
	[EirFree] [float] NULL,
 CONSTRAINT [PK_ProbeLogLines_PT] PRIMARY KEY NONCLUSTERED 
(
	[ProbeLogLineId] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
) ON [ps_LOGYEAR]([ReceivedTime])
WITH (DATA_COMPRESSION = ROW)
GO

ALTER TABLE [dbo].[ProbeLogLines] ADD  CONSTRAINT [DF_ProbeLogLines_dataSource3]  DEFAULT ((0)) FOR [dataSource]
GO

ALTER TABLE [dbo].[ProbeLogLines] ADD  CONSTRAINT [DF_ProbeLogLines_MeasurementTypes3]  DEFAULT ((0)) FOR [MeasurementTypes]
GO

--ALTER TABLE [dbo].[ProbeLogLines]  WITH NOCHECK ADD  CONSTRAINT [FK_dbo.ProbeLogLines3_dbo.Probes_ProbeId] FOREIGN KEY([ProbeId])
--REFERENCES [dbo].[Probes] ([ProbeId])
--ON DELETE CASCADE
GO

--ALTER TABLE [dbo].[ProbeLogLines] NOCHECK CONSTRAINT [FK_dbo.ProbeLogLines3_dbo.Probes_ProbeId]
--GO

CREATE CLUSTERED INDEX [Cl_ProbeLogLines_PT] ON [dbo].[ProbeLogLines]
(
	[ProbeId] ASC,
	[MeasurementTypes] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF, 
DATA_COMPRESSION = PAGE)
GO


CREATE NONCLUSTERED INDEX [NonClustered_ProbeId] ON [dbo].[ProbeLogLines]
(
	[ProbeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [NonClustered_ProbeId_ReceivedTime] ON [dbo].[ProbeLogLines]
(
	[ProbeId] ASC,
	[ReceivedTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

CREATE NONCLUSTERED INDEX [NonClustered_ReceivedTime] ON [dbo].[ProbeLogLines]
(
	[ReceivedTime] ASC
)
INCLUDE([ProbeLogLineId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [ps_LOGYEAR]([ReceivedTime])
GO

ALTER INDEX [NonClustered_ReceivedTime] ON [dbo].[ProbeLogLines] DISABLE
GO