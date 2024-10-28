CREATE DATABASE ironhack_echarger;
USE ironhack_echarger;

SHOW TABLES;
SELECT * FROM chargers;
SELECT * FROM users;
SELECT * FROM sessions;
-- -----------------------------------------------------------------

-- --- Mini Proyecto | IronHack eCharger Product Analytics SQL ---


-- LEVEL 1

-- Question 1: Number of users with sessions
SELECT COUNT(DISTINCT u.id) AS Users_with_sessions
 FROM users u INNER JOIN sessions s ON (u.id=s.user_id)
   ORDER BY u.id;
   
-- Question 2: Number of chargers used by user with id 1
SELECT COUNT(DISTINCT s.charger_id)
 FROM users u INNER JOIN sessions s ON (u.id=s.user_id)
  WHERE u.id=1;

-- -----------------------------------------------------------------

-- LEVEL 2

-- Question 3: Number of sessions per charger type (AC/DC):
SELECT c.type,COUNT(s.id) AS num_sesiones
 FROM chargers c LEFT JOIN sessions s ON (s.charger_id=c.id)
	GROUP BY c.type;
  
-- Question 4: Chargers being used by more than one user
SELECT COUNT(sub.id)
FROM (
	SELECT c.id,c.label,COUNT(DISTINCT s.user_id)
	 FROM chargers c LEFT JOIN sessions s ON (s.charger_id=c.id)
	  GROUP BY c.id,c.label
) AS sub;

-- Question 5: Average session time per charger
SELECT c.id,c.label,AVG(TIMESTAMPDIFF(MINUTE, s.start_time, s.end_time)) AS minutes
 FROM chargers c LEFT JOIN sessions s ON (s.charger_id=c.id)
  GROUP BY c.id,c.label;

-- -----------------------------------------------------------------

-- LEVEL 3

-- Question 6: Full username of users that have used more than one charger in one day (NOTE: for date only consider start_time)
WITH cte AS(
SELECT u.name,u.surname,DATE(s.start_time) AS _day,COUNT(DISTINCT s.charger_id) AS num_cargadores
 FROM users u 
  INNER JOIN sessions s ON (u.id=s.user_id)
   GROUP BY u.name,u.surname,DATE(s.start_time)
   HAVING COUNT(DISTINCT s.charger_id) > 1
   ORDER BY u.name,u.surname,DATE(s.start_time)
)
SELECT name, surname
 FROM cte
  GROUP BY name, surname;
 
-- Question 7: Top 3 chargers with longer sessions
SELECT c.label, SUM(TIMESTAMPDIFF(HOUR, s.start_time, s.end_time)) AS total_duration
FROM sessions s
JOIN chargers c ON s.charger_id = c.id
GROUP BY c.label
ORDER BY total_duration DESC
LIMIT 3;

-- Question 8: Average number of users per charger (per charger in general, not per charger_id specifically)
SELECT c.label, ROUND(COUNT(DISTINCT s.user_id), 2) AS avg_users_per_charger
FROM sessions s
JOIN chargers c ON s.charger_id = c.id
GROUP BY c.label;

-- Question 9: Top 3 users with more chargers being used
SELECT u.name, u.surname, COUNT(DISTINCT s.charger_id) AS chargers_used
FROM sessions s
JOIN users u ON s.user_id = u.id
GROUP BY u.id, u.name, u.surname
ORDER BY chargers_used DESC
LIMIT 3;

-- -----------------------------------------------------------------

-- LEVEL 4

-- Question 10: Number of users that have used only AC chargers, DC chargers or both
DROP VIEW users_chargers;
CREATE VIEW users_chargers AS 
SELECT DISTINCT u.id AS user_id, c.type
 FROM users u 
  INNER JOIN sessions s ON (u.id=s.user_id)
  INNER JOIN chargers c ON (s.charger_id=c.id)
   ORDER BY u.id;

DROP VIEW users_type;
CREATE VIEW users_type AS    
SELECT 
	user_id,
    type,
    COUNT(type) OVER(PARTITION BY user_id) AS num_tipos
	FROM users_chargers;

SELECT * 
 FROM users_type;
    
SELECT type,COUNT(*) 
 FROM users_type
  WHERE num_tipos=1 AND type='AC'
UNION
SELECT type,COUNT(*) 
 FROM users_type
  WHERE num_tipos=1 AND type='DC'
UNION
SELECT 'both',COUNT(DISTINCT user_id) 
 FROM users_type
  WHERE num_tipos=2;

-- Question 11: Monthly average number of users per charger
SELECT 
    c.label, 
    DATE_FORMAT(s.start_time, '%Y-%m') AS month, 
    ROUND(COUNT(DISTINCT s.user_id), 2) AS avg_users_per_charger
FROM sessions s
JOIN chargers c ON s.charger_id = c.id
GROUP BY c.label, month
ORDER BY month, avg_users_per_charger DESC;

-- Question 12: Top 3 users per charger (for each charger, number of sessions)
SELECT c.label, u.name, u.surname, COUNT(s.id) AS session_count
FROM sessions s
JOIN chargers c ON s.charger_id = c.id
JOIN users u ON s.user_id = u.id
GROUP BY c.label, u.id, u.name, u.surname
ORDER BY c.label, session_count DESC
LIMIT 3;

-- -----------------------------------------------------------------

-- LEVEL 5

-- Question 13: Top 3 users with longest sessions per month (consider the month of start_time)
DROP VIEW users_month;
CREATE VIEW users_month AS    
SELECT u.id, u.name, u.surname, MONTH(s.start_time) AS _month, TIMESTAMPDIFF(MINUTE, s.start_time, s.end_time) As session_length
 FROM users u 
  INNER JOIN sessions s ON (u.id=s.user_id);    

SELECT name, surname, session_length,
 DENSE_RANK() OVER(ORDER BY session_length DESC) as ranking
 FROM users_month
 LIMIT 3;
  
-- Question 14. Average time between sessions for each charger for each month (consider the month of start_time)
SELECT 
    charger_id,
    DATE_FORMAT(start_time, '%Y-%m') AS month,
    ROUND(AVG(ABS(TIMESTAMPDIFF(SECOND, previous_end_time, start_time))) / 3600, 2) AS avg_time_between_sessions_hours
FROM 
    (
        SELECT 
            charger_id,
            start_time,
            end_time,
            LAG(end_time) OVER (PARTITION BY charger_id ORDER BY start_time) AS previous_end_time
        FROM 
            sessions
    ) AS session_with_previous
WHERE 
    previous_end_time IS NOT NULL
GROUP BY 
    charger_id, month
ORDER BY 
    charger_id, month;

-- -----------------------------------------------------------------