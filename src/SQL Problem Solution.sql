CREATE TABLE user_plans (
    UserID INT,
    FromDate DATE,
    ToDate DATE,
    userPlan VARCHAR(20)
);


INSERT INTO user_plans (UserID, FromDate, ToDate, userPlan) VALUES
(1, '2022-01-10', '2022-03-10', 'Mobile'),
(1, '2022-04-05', '2022-05-05', 'Premium'),
(1, '2022-05-05', '2022-08-05', 'Standard'),
(1, '2022-09-01', NULL, 'Premium');


---- SOLUTION


WITH cte1 AS (
select 
	*,
	CASE 
		WHEN userPlan = 'Mobile' Then 1
		WHEN userPlan = 'Basic' Then 2
		WHEN userPlan = 'Standard' Then 3
		WHEN userPlan = 'Premium' Then 4
	END AS cur_plan
FROM user_plans
),
cte2 AS (
SELECT
	*,
	LAG(ToDate) OVER(PARTITION BY UserID ORDER BY FromDate) pre_plan_end_date,
	LAG(cur_plan) OVER(PARTITION BY UserID ORDER BY FromDate) prev_plan,
	LEAD(FromDate) OVER(PARTITION BY UserID ORDER BY FromDate) next_plan_start_date,
	LEAD(cur_plan) OVER(PARTITION BY UserID ORDER BY FromDate) next_plan
FROM cte1
),
cte3 AS (
SELECT
	*,
	DATEDIFF(DAY, pre_plan_end_date, FromDate) gap_pre_cur_plan,
	DATEDIFF(DAY, ToDate, next_plan_start_date) gap_cur_next_plan,
	cur_plan - prev_plan AS plan_change
FROM cte2
),
cte4 AS (
SELECT 
	*,
	CASE
		WHEN gap_pre_cur_plan IS NULL THEN 'Subscribed'
		WHEN gap_pre_cur_plan > 0 THEN 'Subscribed'
		WHEN plan_change > 0 THEN 'Upgraded'
		WHEN plan_change < 0 THEN 'Downgraded'
	END AS action_on_start_date,
	CASE
		WHEN gap_cur_next_plan > 0 THEN 'Cancelled'
	END AS action_on_end_date
FROM cte3
)
SELECT 
	UserID,
	FromDate AS Action_Date,
	action_on_start_date AS Action
FROM cte4
UNION ALL
SELECT 
	UserID,
	ToDate AS Action_Date,
	action_on_end_date AS Action
FROM cte4
WHERE action_on_end_date IS NOT NULL
ORDER BY Action_Date