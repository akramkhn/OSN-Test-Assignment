CREATE TABLE dim_user (
    user_id VARCHAR(50) PRIMARY KEY,
    user_name VARCHAR(100),
    email VARCHAR(100),
    signup_date DATE
);

INSERT INTO dim_user (user_id, user_name, email, signup_date) VALUES
('U001', 'John Smith', 'john.smith@email.com', '2024-01-15'),
('U002', 'Sarah Johnson', 'sarah.j@email.com', '2024-02-10'),
('U003', 'Mike Brown', 'mike.brown@email.com', '2024-03-05'),
('U004', 'Emily Davis', 'emily.davis@email.com', '2024-04-20');

SELECT * FROM dim_user;

CREATE TABLE DimPlan (
    PlanKey INT PRIMARY KEY,
    PlanName VARCHAR(20),
    PlanRank INT
);

INSERT INTO DimPlan (PlanKey, PlanName, PlanRank) VALUES
(1, 'Mobile', 1),
(2, 'Basic', 2),
(3, 'Standard', 3),
(4, 'Premium', 4);

SELECT * FROM DimPlan

CREATE TABLE FactSubscription (
    UserID VARCHAR(50),
    PlanKey INT,
    StartDate DATE,
    EndDate DATE,
    FOREIGN KEY (UserID) REFERENCES dim_user(user_id),
    FOREIGN KEY (PlanKey) REFERENCES DimPlan(PlanKey)
);

INSERT INTO FactSubscription (UserID, PlanKey, StartDate, EndDate) VALUES
('U001', 1, '2024-01-15', '2024-02-15'),  
('U001', 2, '2024-02-15', '2024-04-10'), 
('U001', 3, '2024-04-10', '2024-06-01'),
('U001', 4, '2024-06-01', '2024-08-15'),
('U001', NULL, '2024-08-15', NULL), 
('U002', 2, '2024-02-10', '2024-05-20'),
('U002', 4, '2024-05-20', '2024-07-15'),
('U002', 3, '2024-07-15', '2024-09-01'),
('U002', NULL, '2024-09-01', NULL),
('U003', 1, '2024-03-05', '2024-04-05'),
('U003', 3, '2024-04-05', '2024-07-20'),
('U003', 3, '2024-07-20', NULL),
('U004', 2, '2024-04-20', '2024-06-10'),
('U004', 4, '2024-06-10', '2024-08-01'),
('U004', 2, '2024-08-01', '2024-10-15'),
('U004', 2, '2024-10-15', NULL);


----Query

WITH cte1 AS (
SELECT
	fs.UserID,
	fs.StartDate,
	fs.EndDate,
	dm.PlanName,
	dm.PlanRank,
	LAG(fs.EndDate) OVER(PARTITION BY fs.UserID ORDER BY fs.StartDate) pre_plan_end_date,
	LAG(dm.PlanRank) OVER(PARTITION BY fs.UserID ORDER BY fs.StartDate) pre_rank,
	LEAD(fs.StartDate) OVER(PARTITION BY fs.UserID ORDER BY fs.StartDate) next_plan_start_date,
	LEAD(dm.PlanRank) OVER(PARTITION BY fs.UserID ORDER BY fs.StartDate) next_rank
FROM FactSubscription fs
JOIN DimPlan dm on fs.PlanKey = dm.PlanKey
),
cte2 AS (
SELECT 
	*,
	DATEDIFF(DAY, StartDate, pre_plan_end_date) gap_pre_cur_plan,
	DATEDIFF(DAY, next_plan_start_date, EndDate) gap_cur_next_plan,
	PlanRank - pre_rank as plan_change
FROM cte1
),
cte3 AS (
SELECT 
	*,
	CASE 
		WHEN gap_pre_cur_plan IS NULL THEN 'Subscribed'
		WHEN gap_pre_cur_plan > 0 THEN 'Subscribed'
		WHEN plan_change > 0 THEN 'Upgraded'
		WHEN plan_change < 0 THEN 'Downgraded'
		WHEN EndDate IS NULL THEN 'Active'
	END AS action_taken_on_startDate,
	CASE 
		WHEN gap_cur_next_plan > 0 THEN 'Cancelled'
		WHEN next_plan_start_date IS NULL AND EndDate < CAST(GETDATE() AS DATE) THEN 'Cancelled'
	END AS action_taken_on_EndDate
FROM cte2
)
SELECT
	UserID,
	StartDate AS action_date,
	action_taken_on_startDate as 'action'
FROM cte3
UNION ALL
SELECT
	UserID,
	EndDate AS action_date,
	action_taken_on_EndDate as 'action'
FROM cte3
WHERE (action_taken_on_EndDate IS NOT NULL) AND (action_taken_on_StartDate IS NOT NULL)
ORDER BY UserID, action_date
