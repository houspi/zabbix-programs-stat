# zabbix-programs-stat
Calculates some stats for running programs.

Takes the program name as an argument.
Finds all processes with the specified name and calculates their stats using pidstat.

* mem stat, I/O stat, cpu stat.
* SUM of values for all processes
* MIN value from all processes
* MAX value from all processes
* AVG value for all processes
* COUNT of all processes
