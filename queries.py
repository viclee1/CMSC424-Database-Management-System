queries = ["" for i in range(0, 11)]
### EXAMPLE
### 0. List all airport codes and their cities. Order by the city name in the increasing order.
### Output column order: airportid, city

queries[0] = """
select airportid, city
from airports
order by city;
"""

### 1. Write a query to find the names of customers who have flights on a friday and 
###    first name that has a second letter is not a vowel [a, e, i, o, u].
###    If a customer who satisfies the condition flies on multiple fridays, output their name only once.
###    Do not include the youngest customer among those that satisfies the above conditions in the results.
### Hint:  - See postgresql date operators that are linked to from the README, and the "like" operator (see Chapter 3.4.2). 
###        - Alternately, you can use a regex to match the condition imposed on the name.
###        - See postgresql date operators and string functions
###        - You may want to use a self-join to avoid including the youngest customer.
###        - When testing, write a query that includes all customers, then modify that to exclude the youngest.
### Order: by name
### Output columns: name
queries[1] = """
select name from customers inner join flewon
on customers.customerid = flewon.customerid
where customers.birthdate < 
    (select max(customers.birthdate) 
    from customers inner join flewon 
    on customers.customerid = flewon.customerid
    where customers.name not similar to '_(a|e|i|o|u)%') and
customers.name not similar to '_(a|e|i|o|u)%' and
extract(dow from flewon.flightdate)=5
order by name;
"""


### 2. Write a query to find customers who are frequent fliers on United Airlines (UA) 
###    and have their birthday between 07/15 and 12/15 (mm/dd). 
### Hint: See postgresql date functions.
### Order: by name
### Output columns: customer id, name, birthdate, frequentflieron
queries[2] = """
select customerid, name, birthdate, frequentflieron from customers
where frequentflieron='UA' 
and extract(doy from birthdate)>extract(doy from timestamp '2000-07-15 00:00:00') 
and extract(doy from birthdate)<extract(doy from timestamp '2000-12-15 00:00:00')
order by name;
"""

### 3. Write a query to rank the airlines have the most flights on airports other than their hubs.
### Output the airlineid along with the number of fligths not connecting their hubs. 
### Output: (airlineid, count)
### Order: first by count in descending order, then airline in ascending order
### Note: A flight does not connect a hub if the hub is neither the source nor the destination of the flight. 
queries[3] = """
select airlines.airlineid, count(flightid) from flights join airlines 
on airlines.airlineid=flights.airlineid
where flights.source!=airlines.hub and flights.dest!=airlines.hub
group by airlines.airlineid
order by count(flightid) desc, airlines.airlineid asc;
"""

### 4. Write a query to find the names of customers with the least common frequent flier airline.
###    For example, if 10 customers have Delta as their frequent flier airline, and no other airlines have fewer than 10 frequent flier customers, 
###    then the query should return all customers that have Delta as their frequent flier airline. 
###    In the case of a tie, return all customers from all tied airlines.
### Hint: use `with clause` and nested queries (Chapter 3.8.6). 
### Output: only the names of the customer.
### Order: order by name.
queries[4] = """
with grouped(frequentflieron, counter) as
(select frequentflieron, count(name) from customers group by frequentflieron),

minimum(frequentflieron, small) as
(select frequentflieron, min(counter) from grouped 
where (select min(counter) from grouped)=grouped.counter 
group by frequentflieron)

select name from customers, minimum 
where customers.frequentflieron=minimum.frequentflieron;
"""


### 5. Write a query to find the most-frequent flyers (customers who have flown on most number of flights).
###    In this dataset and in general, always assume that there could be multiple flyers who satisfy this condition.
###    Assuming multiple customers exist, list the customer names along with the count of other frequent flyers
###    they have never flown with.
###    Two customers are said to have flown together when they have a flewon entry with a matching flightid and flightdate.
###    For example if Alice, Bob and Charlie flew on the most number of flighs (3 each). Assuming Alice and Bob never flew together,
###    while Charlie flew with both of them, the expected output would be: [('Alice', 1), ('Bob', 1), ('Charlie', 0)].
### NOTE: A frequent flyer here is purely based on number of occurances in flewon, (not the frequentflieron field).
### Output: name, count
### Order: order by count desc, name.
queries[5] = """
with aggregate(customerid, name, counter) as
(select customers.customerid, customers.name, count(flewon.customerid) from customers join flewon
on customers.customerid=flewon.customerid
group by customers.name, customers.customerid),

maximum(customerid, name, big) as
(select customerid, name, max(counter) from aggregate 
where (select max(counter) from aggregate)=aggregate.counter
group by name, customerid),

flightinfo(customerid, flightid, flightdate, name) as
(select maximum.customerid, flewon.flightid, flewon.flightdate, maximum.name
from maximum join flewon
on maximum.customerid=flewon.customerid
order by name),

otherpeople(name, others) as
(select distinct flightinfo.name, copy.name
from flightinfo join (select * from flightinfo) as copy
on flightinfo.flightid=copy.flightid and flightinfo.flightdate=copy.flightdate and flightinfo.name!=copy.name)

select name,
(select count(*)from maximum) - count(otherpeople.others) - 1 as count
from otherpeople
group by name
order by count desc, name;
"""

### 6. Write a query to find the percentage participation of United Airlines in each airport, relative to the other airlines.
### One instance of participation in an airport is defined as a flight (EX. UA101) having a source or dest of that airport.
### If UA101 leaves BOS and arrives in FLL, that adds 1 to United's count for each airport
### This means that if UA has 1 in BOS, AA has 1 in BOS, DL has 2 in BOS, and SW has 3 in BOS, the query returns:
###     airport 		                              | participation
###     General Edward Lawrence Logan International   | .14
### Output: (airport_name, participation).
### Order: Participation in descending order, airport name
### Note: - The airport column must be the full name of the airport
###       - The participation percentage is rounded to 2 decimals, as shown above
###       - You do not need to confirm that the flights actually occur by referencing the flewon table. This query is only concerned with
###         flights that exist in the flights table.
###       - You must not leave out airports that have no UA flights (participation of 0)

queries[6] = """
with totalflights(airportid, total) as
(select source, totaltakeoffs + totallandings as total
from (select source, count(flightid) as totaltakeoffs from flights group by source) as departures join
(select dest, count(flightid) as totallandings from flights group by dest) as arrivals
on departures.source = arrivals.dest),

totalUAflights(UAid, UAtotal) as
(select source, totaltakeoffs + totallandings as total
from (select source, count(flightid) as totaltakeoffs from flights where airlineid='UA' group by source) as departures join
(select dest, count(flightid) as totallandings from flights where airlineid='UA' group by dest) as arrivals
on departures.source = arrivals.dest)

select name,
case when totalUAflights.UAtotal IS NULL 
    then round(cast(0 as decimal), 2)
    else round(cast(totalUAflights.UAtotal as decimal) / totalflights.total, 2)
end as percentage
from airports left join totalUAflights 
on airports.airportid = totalUAflights.UAid
join totalflights
on airports.airportid = totalflights.airportid
order by percentage desc, name
"""

### 7. Write a query to find the customer/customers that taken the highest number of flights but have never flown on their frequentflier airline.
###    If there is a tie, return the names of all such customers. 
### Output: Customer name
### Order: name
queries[7] = """
with aggregate(name, customerid, counter, frequentflieron) as
(select customers.name, customers.customerid, count(flewon.customerid), customers.frequentflieron from customers join flewon
on customers.customerid=flewon.customerid
group by customers.name, customers.customerid, frequentflieron),

maximum(name, customerid, big, frequentflieron) as
(select name, customerid, max(counter), frequentflieron from aggregate 
where (select max(counter) from aggregate)=aggregate.counter
group by name, customerid, frequentflieron),

fliers(name, count) as
(select name, count(flights.flightid) 
from maximum join flewon
on maximum.customerid=flewon.customerid
join flights
on flights.flightid=flewon.flightid
where airlineid!=frequentflieron
group by name),

total(name, count) as
(select name, count(flightid)
from customers natural join flewon
group by name)

select name from fliers
where count=(select max(count) 
from total);
"""

### 8. Write a query to find customers that took flights on four consecutive days, but did not fly any other day.
###    Return the name, start and end date of the customers flights.
### Output: customer_name, start_date, end_date
### Order: by customer_name
queries[8] = """
with inbetween(name, first, last, total) as
(select name, min(flewon.flightdate), max(flewon.flightdate), count(flewon.flightid)
from flewon natural join customers
group by name)

select name, first, last
from inbetween
where extract(doy from last) - extract(doy from first) = 3 and total = 4
order by name;
"""

### 9. A layover consists of set of two flights where the destination of the first flight is the same 
###    as the source of the second flight. Additionally, the arrival of the first flight must be before the
###    departure of the first flight. 
###    Write a query to find all pairs of flights belonging to the same airline that had a layover in JFK
###    between 1 and 3 hours in length (inclusive).
### Output columns: 1st flight id, 2nd flight id, source city, destination city, layover duration
### Order by: layover duration
queries[9] = """
with jfkdest(flightid, source, dest, airlineid, time) as
(select flightid, source, dest, airlineid, local_arrival_time
from flights where dest='JFK'),

jfksource(flightid, source, dest, airlineid, time) as
(select flightid, source, dest, airlineid, local_departing_time 
from flights where source='JFK')

select jfkdest.flightid, jfksource.flightid, jfkdest.source, jfksource.dest, jfksource.time-jfkdest.time
from jfkdest join jfksource on jfksource.source=jfkdest.dest
where jfksource.time-jfkdest.time >= INTERVAL '1 hour' and jfksource.time-jfkdest.time <= INTERVAL '3 hours'
and jfkdest.airlineid=jfksource.airlineid
order by jfksource.time-jfkdest.time;
"""

### 10. Provide a top-10 ranking of the most loyal frequent fliers.
### We rank these fliers by the ratio of flights that they take that are with their frequentflieron airline. 
### The customer with the highest ratio of (flights with frequentflieron) / total flights is rank 1, and so on.
### A customer needs more than 7 flights to be considered for the ranking
### Output: (customer_name, rank)
### Order: by the ascending rank
### Note: a) If two customers tie, then they should both get the same rank, and the next rank should be skipped. For example, if the top two customers have the same ratio, then there should be no rank 2, e.g., 1, 1, 3 ...
###       b) This means there may be more than 10 customers in this ranking, so long as their ranks are under 10. This may occur if there are 10 at rank 5, etc.
queries[10] = """
with aggregate(customerid, name, frequentflieron, count) as
(select flewon.customerid, customers.name, customers.frequentflieron, count(flewon.flightid)
from customers natural join flewon
group by flewon.customerid, customers.name, customers.frequentflieron),

overseven(customerid, name, frequentflieron, count) as
(select customerid, name, frequentflieron, count
from aggregate
where count>7),

flightscount(customerid, name, count) as
(select overseven.customerid, overseven.name, count(flewon.flightid)
from overseven join flewon
on overseven.customerid=flewon.customerid
join flights
on flights.flightid=flewon.flightid
where overseven.frequentflieron=flights.airlineid
group by overseven.name, overseven.customerid),

ratios(name, ratio) as
(select flightscount.name, cast(flightscount.count as decimal)/overseven.count
from overseven join flightscount
on overseven.name=flightscount.name),

ranks(name, rank) as
(select name, rank() over (order by ratio desc) theranks 
from ratios 
order by theranks)

select * from ranks where rank <= 10;
"""
