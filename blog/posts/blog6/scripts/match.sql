-- Resolve stable person IDs within the childhood family, not current households.
CREATE TABLE pairs AS
SELECT c.person_id AS child_id, p.person_id AS parent_id, c.origin_family_id
FROM persons AS c
JOIN persons AS p
  ON c.parent_id = p.person_id AND c.origin_family_id = p.origin_family_id
WHERE c.role = 'child' AND p.role = 'parent';
CREATE UNIQUE INDEX one_parent_per_child ON pairs(child_id);

-- Aggregate each person BEFORE joining income histories: avoid a 5 x 5 join.
CREATE TABLE measures AS
SELECT person_id,
 MAX(CASE WHEN age = 25 THEN real_income END) AS income25,
 MAX(CASE WHEN age = 35 THEN real_income END) AS income35,
 AVG(CASE WHEN age BETWEEN 25 AND 29 THEN real_income END) AS mean25_29,
 AVG(CASE WHEN age BETWEEN 35 AND 39 THEN real_income END) AS mean35_39,
 COUNT(CASE WHEN age BETWEEN 25 AND 29 THEN real_income END) AS n_early,
 COUNT(CASE WHEN age BETWEEN 35 AND 39 THEN real_income END) AS n_mid
FROM income WHERE real_income > 0
GROUP BY person_id;

CREATE TABLE matched AS
SELECT k.*, p.income35 AS parent_single, p.mean35_39 AS parent_mean,
 c.income25 AS child_early_single, c.income35 AS child_mid_single,
 c.mean25_29 AS child_early_mean, c.mean35_39 AS child_mid_mean
FROM pairs AS k
JOIN measures AS p ON p.person_id = k.parent_id
JOIN measures AS c ON c.person_id = k.child_id
WHERE p.n_mid = 5 AND c.n_mid = 5 AND c.n_early = 5;
