-- =====================================================================
-- TASK 2: SPORTS ANALYTICS & PERFORMANCE METRICS (SQL)
-- Run this ENTIRE script (Execute-all, not just a selected block).
-- Target schema: ipl_analysis
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ipl_analysis;
USE ipl_analysis;

-- ---------------------------------------------------------------------
-- Drop old objects so the script is safely re-runnable
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS deliveries;
DROP TABLE IF EXISTS matches;
DROP TABLE IF EXISTS venues;
DROP TABLE IF EXISTS teams;

-- ---------------------------------------------------------------------
-- SCHEMA
-- ---------------------------------------------------------------------
CREATE TABLE teams (
    team_id     INT AUTO_INCREMENT PRIMARY KEY,
    team_name   VARCHAR(60) NOT NULL UNIQUE,
    short_code  VARCHAR(5)  NOT NULL
);

CREATE TABLE venues (
    venue_id    INT AUTO_INCREMENT PRIMARY KEY,
    venue_name  VARCHAR(100) NOT NULL,
    city        VARCHAR(50)  NOT NULL
);

CREATE TABLE matches (
    match_id        INT AUTO_INCREMENT PRIMARY KEY,
    season          YEAR        NOT NULL,
    match_date      DATE        NOT NULL,
    venue_id        INT         NOT NULL,
    team1_id        INT         NOT NULL,
    team2_id        INT         NOT NULL,
    toss_winner_id  INT         NOT NULL,
    winner_id       INT         NULL,
    FOREIGN KEY (venue_id)       REFERENCES venues(venue_id),
    FOREIGN KEY (team1_id)       REFERENCES teams(team_id),
    FOREIGN KEY (team2_id)       REFERENCES teams(team_id),
    FOREIGN KEY (toss_winner_id) REFERENCES teams(team_id),
    FOREIGN KEY (winner_id)      REFERENCES teams(team_id)
);

CREATE TABLE deliveries (
    delivery_id      INT AUTO_INCREMENT PRIMARY KEY,
    match_id         INT NOT NULL,
    batting_team_id  INT NOT NULL,
    over_num         INT NOT NULL,
    runs_in_over     INT NOT NULL,
    wickets_in_over  INT NOT NULL DEFAULT 0,
    FOREIGN KEY (match_id)        REFERENCES matches(match_id),
    FOREIGN KEY (batting_team_id) REFERENCES teams(team_id)
);

-- ---------------------------------------------------------------------
-- SAMPLE DATA
-- ---------------------------------------------------------------------
INSERT INTO teams (team_name, short_code) VALUES
('Kolkata Knight Riders', 'KKR'),
('Mumbai Indians',        'MI'),
('Chennai Super Kings',   'CSK'),
('Royal Challengers Bengaluru', 'RCB'),
('Delhi Capitals',        'DC'),
('Sunrisers Hyderabad',   'SRH'),
('Punjab Kings',          'PBKS'),
('Rajasthan Royals',      'RR');

INSERT INTO venues (venue_name, city) VALUES
('Eden Gardens',                 'Kolkata'),
('Wankhede Stadium',             'Mumbai'),
('M. Chinnaswamy Stadium',       'Bengaluru'),
('Arun Jaitley Stadium',         'Delhi'),
('MA Chidambaram Stadium',       'Chennai'),
('Rajiv Gandhi Intl. Stadium',   'Hyderabad');

-- team_id: 1=KKR 2=MI 3=CSK 4=RCB 5=DC 6=SRH 7=PBKS 8=RR
-- venue_id: 1=Eden Gardens 2=Wankhede 3=Chinnaswamy 4=Arun Jaitley 5=Chidambaram 6=Rajiv Gandhi
INSERT INTO matches (season, match_date, venue_id, team1_id, team2_id, toss_winner_id, winner_id) VALUES
(2021, '2021-04-11', 1, 1, 2, 1, 1),
(2021, '2021-04-25', 1, 1, 3, 3, 3),
(2022, '2022-04-06', 1, 1, 6, 1, 1),
(2022, '2022-05-01', 1, 1, 4, 4, 4),
(2023, '2023-04-16', 1, 1, 5, 1, 1),
(2023, '2023-05-13', 1, 1, 7, 7, 1),
(2021, '2021-04-18', 2, 2, 1, 2, 2),
(2022, '2022-04-13', 2, 2, 1, 1, 1),
(2023, '2023-04-24', 2, 8, 1, 1, 1),
(2021, '2021-09-25', 3, 4, 1, 4, 1),
(2022, '2022-04-30', 3, 4, 1, 1, 4),
(2023, '2023-05-07', 3, 4, 1, 4, 4),
(2021, '2021-04-29', 4, 5, 1, 1, 1),
(2022, '2022-05-08', 4, 5, 1, 5, 5),
(2021, '2021-04-23', 5, 3, 1, 3, 3),
(2023, '2023-04-28', 5, 3, 1, 1, 3),
(2022, '2022-04-17', 6, 6, 1, 1, 1),
(2023, '2023-05-02', 6, 6, 1, 6, 6);

-- Over-by-over KKR run data (20 overs per match, batting_team_id = 1)
DROP PROCEDURE IF EXISTS seed_kkr_overs;
DELIMITER $$
CREATE PROCEDURE seed_kkr_overs()
BEGIN
    DECLARE m INT DEFAULT 1;
    DECLARE o INT;
    DECLARE base INT;
    WHILE m <= 18 DO
        SET o = 1;
        SET base = 6 + (m % 4);
        WHILE o <= 20 DO
            INSERT INTO deliveries (match_id, batting_team_id, over_num, runs_in_over, wickets_in_over)
            VALUES (
                m, 1, o,
                GREATEST(2, base + FLOOR(RAND() * 7) - (o = 20) * (-3) - (o <= 6) * (-2)),
                FLOOR(RAND() * 2)
            );
            SET o = o + 1;
        END WHILE;
        SET m = m + 1;
    END WHILE;
END$$
DELIMITER ;

CALL seed_kkr_overs();
DROP PROCEDURE seed_kkr_overs;

-- =====================================================================
-- ANALYSIS QUERIES
-- =====================================================================

-- Q1. KKR win rate by stadium
SELECT
    v.venue_name,
    v.city,
    COUNT(*)                                                       AS matches_played,
    SUM(CASE WHEN m.winner_id = kkr.team_id THEN 1 ELSE 0 END)     AS matches_won,
    ROUND(
        SUM(CASE WHEN m.winner_id = kkr.team_id THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 2)                                       AS win_rate_percent
FROM matches m
JOIN venues v  ON v.venue_id = m.venue_id
JOIN teams kkr ON kkr.team_name = 'Kolkata Knight Riders'
WHERE kkr.team_id IN (m.team1_id, m.team2_id)
GROUP BY v.venue_name, v.city
ORDER BY win_rate_percent DESC;

-- Q2. KKR average run rate by stadium (subquery, no CTE needed)
SELECT
    v.venue_name,
    v.city,
    COUNT(*)                                       AS matches_measured,
    ROUND(AVG(mr.total_runs / mr.overs_faced), 2)  AS avg_run_rate
FROM (
    SELECT
        d.match_id,
        m.venue_id,
        SUM(d.runs_in_over) AS total_runs,
        COUNT(d.over_num)   AS overs_faced
    FROM deliveries d
    JOIN matches m ON m.match_id = d.match_id
    WHERE d.batting_team_id = 1
    GROUP BY d.match_id, m.venue_id
) AS mr
JOIN venues v ON v.venue_id = mr.venue_id
GROUP BY v.venue_name, v.city
ORDER BY avg_run_rate DESC;

-- Q3. WINDOW FUNCTION - rank stadiums by KKR win rate
SELECT
    venue_name, matches_played, matches_won, win_rate_percent,
    RANK() OVER (ORDER BY win_rate_percent DESC) AS win_rate_rank
FROM (
    SELECT
        v.venue_name,
        COUNT(*)                                                    AS matches_played,
        SUM(CASE WHEN m.winner_id = kkr.team_id THEN 1 ELSE 0 END)  AS matches_won,
        ROUND(
            SUM(CASE WHEN m.winner_id = kkr.team_id THEN 1 ELSE 0 END)
            / COUNT(*) * 100, 2)                                    AS win_rate_percent
    FROM matches m
    JOIN venues v  ON v.venue_id = m.venue_id
    JOIN teams kkr ON kkr.team_name = 'Kolkata Knight Riders'
    WHERE kkr.team_id IN (m.team1_id, m.team2_id)
    GROUP BY v.venue_name
) AS venue_perf
ORDER BY win_rate_rank;

-- Q4. WINDOW FUNCTION - running average run rate over time
SELECT
    match_date, venue_name,
    ROUND(run_rate, 2) AS match_run_rate,
    ROUND(AVG(run_rate) OVER (
        ORDER BY match_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_avg_run_rate
FROM (
    SELECT
        d.match_id, m.match_date, v.venue_name,
        SUM(d.runs_in_over) / COUNT(d.over_num) AS run_rate
    FROM deliveries d
    JOIN matches m ON m.match_id = d.match_id
    JOIN venues  v ON v.venue_id = m.venue_id
    WHERE d.batting_team_id = 1
    GROUP BY d.match_id, m.match_date, v.venue_name
) AS match_runs
ORDER BY match_date;

-- Q5. WINDOW FUNCTION - best-ever KKR run rate per stadium
SELECT venue_name, match_date, run_rate
FROM (
    SELECT
        venue_name, match_date,
        ROUND(run_rate, 2) AS run_rate,
        RANK() OVER (PARTITION BY venue_name ORDER BY run_rate DESC) AS venue_rank
    FROM (
        SELECT
            d.match_id, m.match_date, v.venue_name,
            SUM(d.runs_in_over) / COUNT(d.over_num) AS run_rate
        FROM deliveries d
        JOIN matches m ON m.match_id = d.match_id
        JOIN venues  v ON v.venue_id = m.venue_id
        WHERE d.batting_team_id = 1
        GROUP BY d.match_id, m.match_date, v.venue_name
    ) AS match_runs
) AS ranked
WHERE venue_rank = 1
ORDER BY run_rate DESC;
