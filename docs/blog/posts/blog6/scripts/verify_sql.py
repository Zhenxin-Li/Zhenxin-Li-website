"""Small adversarial fixture: current households, bad origin IDs, missing years."""
from pathlib import Path
import sqlite3

c = sqlite3.connect(':memory:')
c.executescript('''CREATE TABLE persons(person_id INTEGER PRIMARY KEY, origin_family_id INTEGER,
 current_family_id INTEGER, role TEXT, parent_id INTEGER, birth_year INTEGER);
 CREATE TABLE income(person_id INTEGER,year INTEGER,age INTEGER,real_income REAL,
 PRIMARY KEY(person_id,year));''')
c.executemany('INSERT INTO persons VALUES (?,?,?,?,?,?)', [
 (1,10,10,'parent',None,1940),(2,10,20,'child',1,1965),
 (3,99,30,'child',1,1965),  # wrong origin: must not link despite valid parent ID
 (4,40,40,'parent',None,1940),(5,40,50,'child',4,1965)])
for pid in (1,2,3,4,5):
    for age in list(range(25,30))+list(range(35,40)):
        if pid==5 and age==39: continue  # incomplete child: exclude from final sample
        c.execute('INSERT INTO income VALUES (?,?,?,?)',(pid,age,age,100*age))
try:
    c.execute('INSERT INTO income VALUES (1,25,25,999)')
except sqlite3.IntegrityError:
    pass
else:
    raise AssertionError('Duplicate person-year accepted')
c.executescript((Path(__file__).with_name('match.sql')).read_text())
assert c.execute('SELECT child_id,parent_id FROM pairs ORDER BY child_id').fetchall()==[(2,1),(5,4)]
matched=c.execute('SELECT child_id,parent_mean,child_mid_mean FROM matched').fetchall()
assert matched==[(2,3700.0,3700.0)], matched
print('PASS: split households matched; wrong origin rejected; incomplete window excluded; duplicate year rejected; aggregation preserved one row per pair.')
