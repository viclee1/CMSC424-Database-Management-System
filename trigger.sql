-- trigger on customers
CREATE OR REPLACE FUNCTION process_customer() RETURNS TRIGGER AS $$
    BEGIN
        IF (TG_OP = 'DELETE') THEN

            DELETE FROM newcustomers WHERE customerid = (SELECT o.customerid FROM old_table o);
            DELETE FROM ffairlines WHERE customerid = (SELECT o.customerid FROM old_table o);
            IF NOT FOUND THEN RETURN NULL; END IF;

        ELSIF (TG_OP = 'UPDATE') THEN

            IF ((SELECT n.frequentflieron FROM new_table n) IS NULL) THEN -- delete every customerid

                DELETE FROM ffairlines WHERE customerid = (SELECT o.customerid FROM old_table o);

            ELSIF (NOT EXISTS(SELECT airlineid from ffairlines 
                WHERE customerid = (SELECT n.customerid FROM new_table n)
                AND airlineid = (SELECT n.frequentflieron from new_table n))) THEN
                INSERT INTO ffairlines
                    SELECT n.customerid, 
                    n.frequentflieron, 
                    COALESCE((SELECT sum(extract(epoch FROM local_arrival_time) - extract(epoch FROM local_departing_time))/60 AS points
                    FROM flewon NATURAL JOIN flights
                    WHERE airlineid = (SELECT n.frequentflieron FROM new_table n) 
                    AND customerid = (SELECT n.customerid FROM new_table n)), 0)
                    FROM new_table n;

                UPDATE customers
                SET
                    frequentflieron = 
                        (SELECT airlineid
                        FROM ffairlines
                        WHERE customerid = (SELECT n.customerid FROM new_table n)
                        AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT n.customerid FROM new_table n))
                        GROUP BY airlineid, points 
                        ORDER BY airlineid LIMIT 1)
                WHERE customerid = (SELECT n.customerid FROM new_table n);

            END IF;

            UPDATE newcustomers
                SET 
                customerid = (SELECT n.customerid FROM new_table n),
                name = (SELECT n.name FROM new_table n), 
                birthdate = (SELECT n.birthdate FROM new_table n)
                WHERE customerid = (SELECT n.customerid FROM new_table n);

        ELSIF (TG_OP = 'INSERT') THEN
            INSERT INTO newcustomers
                SELECT n.customerid, n.name, n.birthdate FROM new_table n;
            IF ((SELECT n.frequentflieron FROM new_table n) IS NOT NULL) THEN
                INSERT INTO ffairlines
                    SELECT n.customerid, 
                    n.frequentflieron, 
                    0
                    FROM new_table n;
            END IF;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER customers_ins
    AFTER INSERT ON customers
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_customer();
CREATE TRIGGER customers_upd
    AFTER UPDATE ON customers
    REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_customer();
CREATE TRIGGER customers_del
    AFTER DELETE ON customers
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_customer();

-- trigger on newcustomers
CREATE OR REPLACE FUNCTION process_new_customers() RETURNS TRIGGER AS $$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            DELETE FROM customers WHERE customerid = (SELECT o.customerid FROM old_table o);
            DELETE FROM ffairlines WHERE customerid = (SELECT o.customerid FROM old_table o);
            IF NOT FOUND THEN RETURN NULL; END IF;
        ELSIF (TG_OP = 'UPDATE') THEN
            UPDATE customers
                SET 
                customerid = (SELECT n.customerid FROM new_table n),
                name = (SELECT n.name FROM new_table n), 
                birthdate = (SELECT n.birthdate FROM new_table n),
                frequentflieron = 
                (SELECT airlineid FROM ffairlines 
                WHERE points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT n.customerid FROM new_table n)))
            WHERE customers.customerid = (SELECT n.customerid FROM new_table n);
        ELSIF (TG_OP = 'INSERT') THEN
            INSERT INTO customers
                SELECT n.customerid,
                n.name,
                n.birthdate,
                (SELECT airlineid FROM ffairlines 
                WHERE points = (SELECT max(points) FROM ffairlines) 
                AND customerid = (SELECT n.customerid FROM new_table n))
                FROM new_table n;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER newcustomers_ins
    AFTER INSERT ON newcustomers
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_new_customers();
CREATE TRIGGER newcustomers_upd
    AFTER UPDATE ON newcustomers
    REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_new_customers();
CREATE TRIGGER newcustomers_del
    AFTER DELETE ON newcustomers
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_new_customers();

CREATE OR REPLACE FUNCTION process_ffairlines() RETURNS TRIGGER AS $$
    BEGIN
        IF (TG_OP = 'UPDATE') THEN
            UPDATE customers
                SET frequentflieron = 
                (SELECT airlineid
                FROM ffairlines
                WHERE customerid = (SELECT n.customerid FROM new_table n)
                AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT n.customerid FROM new_table n))
                GROUP BY airlineid, points 
                ORDER BY airlineid LIMIT 1)
            WHERE customerid = (SELECT n.customerid FROM new_table n);
        ELSIF (TG_OP = 'DELETE') THEN
            UPDATE customers
                SET frequentflieron = 
                (SELECT airlineid
                FROM ffairlines
                WHERE customerid = (SELECT o.customerid FROM old_table o)
                AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT o.customerid FROM old_table o))
                GROUP BY airlineid, points 
                ORDER BY airlineid LIMIT 1)
            WHERE customerid = (SELECT o.customerid FROM old_table o);
        ELSIF (TG_OP = 'INSERT') THEN
            UPDATE customers
                SET frequentflieron =
                (SELECT airlineid
                FROM ffairlines
                WHERE customerid = (SELECT n.customerid FROM new_table n)
                AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT n.customerid FROM new_table n))
                GROUP BY airlineid, points 
                ORDER BY airlineid LIMIT 1)
            WHERE customerid = (select n.customerid FROM new_table n);
            
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ffairline_ins
    AFTER INSERT ON ffairlines
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_ffairlines();
CREATE TRIGGER ffairline_upd
    AFTER UPDATE ON ffairlines
    REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_ffairlines();
CREATE TRIGGER ffairline_del
    AFTER DELETE ON ffairlines
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_ffairlines();

CREATE OR REPLACE FUNCTION process_flewon() RETURNS TRIGGER AS $$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            IF (SELECT count(*) from flewon WHERE customerid = ((SELECT DISTINCT o.customerid FROM old_table o))) = 0 THEN
                UPDATE ffairlines
                    SET points = 0
                WHERE customerid = (SELECT DISTINCT o.customerid FROM old_table o);
            ELSE
                UPDATE ffairlines
                    SET points =
                        COALESCE((SELECT sum(extract(epoch FROM local_arrival_time) - extract(epoch FROM local_departing_time))/60 AS points
                        FROM flewon NATURAL JOIN flights
                        WHERE airlineid = 
                            (SELECT substring(flightid FROM 1 FOR 2) FROM old_table o LIMIT 1)
                        AND customerid = (SELECT o.customerid FROM old_table o LIMIT 1)), 0)
                    WHERE customerid = (SELECT o.customerid FROM old_table o LIMIT 1) AND
                    airlineid = (SELECT substring(flightid FROM 1 FOR 2) FROM old_table o);
            END IF;

                UPDATE customers
                    SET
                    frequentflieron = 
                        (SELECT airlineid
                        FROM ffairlines
                        WHERE customerid = (SELECT o.customerid FROM old_table o LIMIT 1)
                        AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT DISTINCT o.customerid FROM old_table o))
                        GROUP BY airlineid, points 
                        ORDER BY airlineid LIMIT 1)
                    WHERE customerid = (SELECT DISTINCT o.customerid FROM old_table o);
        ELSIF (TG_OP = 'UPDATE') THEN
            UPDATE ffairlines
                    SET points =
                        COALESCE((SELECT sum(extract(epoch FROM local_arrival_time) - extract(epoch FROM local_departing_time))/60 AS points
                        FROM flewon NATURAL JOIN flights
                        WHERE airlineid = 
                            (SELECT substring(flightid FROM 1 FOR 2) FROM old_table o)
                        AND customerid = (SELECT o.customerid FROM old_table o)), 0)
                    WHERE customerid = (SELECT o.customerid FROM old_table o) AND
                    airlineid = (SELECT substring(flightid FROM 1 FOR 2) FROM old_table o);

                UPDATE customers
                    SET
                    frequentflieron = 
                        (SELECT airlineid
                        FROM ffairlines
                        WHERE customerid = (SELECT n.customerid FROM new_table n)
                        AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT n.customerid FROM new_table n))
                        GROUP BY airlineid, points 
                        ORDER BY airlineid LIMIT 1)
                    WHERE customerid = (SELECT n.customerid FROM new_table n);
        ELSIF (TG_OP = 'INSERT') THEN
            UPDATE ffairlines
                    SET points =
                        (SELECT sum(extract(epoch FROM local_arrival_time) - extract(epoch FROM local_departing_time))/60 AS points
                        FROM flewon NATURAL JOIN flights
                        WHERE airlineid = 
                            (SELECT substring(flightid FROM 1 FOR 2) FROM new_table n)
                        AND customerid = (SELECT n.customerid FROM new_table n))
                    WHERE customerid = (SELECT n.customerid FROM new_table n) AND
                    airlineid = (SELECT substring(flightid FROM 1 FOR 2) FROM new_table n);

                UPDATE customers
                    SET
                    frequentflieron = 
                        (SELECT airlineid
                        FROM ffairlines
                        WHERE customerid = (SELECT n.customerid FROM new_table n)
                        AND points = (SELECT max(points) FROM ffairlines WHERE customerid = (SELECT n.customerid FROM new_table n))
                        GROUP BY airlineid, points 
                        ORDER BY airlineid LIMIT 1)
                    WHERE customerid = (SELECT n.customerid FROM new_table n);
        END IF;
        RETURN NULL;

    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER flewon_ins
    AFTER INSERT ON flewon
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_flewon();
CREATE TRIGGER flewon_upd
    AFTER UPDATE ON flewon
    REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_flewon();
CREATE TRIGGER flewon_del
    AFTER DELETE ON flewon
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT 
    WHEN (pg_trigger_depth() = 0)
    EXECUTE FUNCTION process_flewon();