package edu.umd.cs424.database.query;

import edu.umd.cs424.database.Database;
import java.util.*;
import edu.umd.cs424.database.DatabaseException;
import edu.umd.cs424.database.databox.DataBox;
import edu.umd.cs424.database.table.Record;
import edu.umd.cs424.database.table.Schema;
import edu.umd.cs424.database.common.BacktrackingIterator;
import edu.umd.cs424.database.common.Pair;
import edu.umd.cs424.database.io.PageAllocator.PageIterator;

public class SortOperator {
    private Database.Transaction transaction;
    private String tableName;
    private Comparator<Record> comparator;
    private Schema operatorSchema;
    private int numBuffers;
    private String sortedTableName = null;

    public SortOperator(Database.Transaction transaction, String tableName,
                        Comparator<Record> comparator) throws DatabaseException, QueryPlanException {
        this.transaction = transaction;
        this.tableName = tableName;
        this.comparator = comparator;
        this.operatorSchema = this.computeSchema();
        this.numBuffers = this.transaction.getNumMemoryPages();
    }

    public Schema computeSchema() throws QueryPlanException {
        try {
            return this.transaction.getFullyQualifiedSchema(this.tableName);
        } catch (DatabaseException de) {
            throw new QueryPlanException(de);
        }
    }

    public class Run {
        String tempTableName;

        public Run() throws DatabaseException {
            this.tempTableName = SortOperator.this.transaction.createTempTable(
                                     SortOperator.this.operatorSchema);
        }

        public void addRecord(List<DataBox> values) throws DatabaseException {
            SortOperator.this.transaction.addRecord(this.tempTableName, values);
        }

        public void addRecords(List<Record> records) throws DatabaseException {
            for (Record r : records) {
                this.addRecord(r.getValues());
            }
        }

        public Iterator<Record> iterator() throws DatabaseException {
            return SortOperator.this.transaction.getRecordIterator(this.tempTableName);
        }

        public String tableName() {
            return this.tempTableName;
        }
    }

    /**
     * Returns a Run containing records from the input iterator in sorted order.
     * You're free to use an in memory sort over all the records using one of
     * Java's built-in sorting methods.
     *
     * Return a single sorted run containing all the records from the input
     * iterator
     */
    public Run sortRun(Run run) throws DatabaseException {
        Iterator<Record> iter = run.iterator();
        List<Record> records = new ArrayList<>();
        
        while (iter.hasNext()) {
        	records.add(iter.next());
        }
        
        Collections.sort(records, this.comparator);
        Run sort = this.createRun();
        sort.addRecords(records);
        return sort;
    }

    /**
     * Given a list of sorted runs, returns a new run that is the result of
     * merging the input runs. You should use a Priority Queue (java.util.PriorityQueue)
     * to determine which record should be should be added to the output run
     * next.
     *
     * You are NOT allowed to have more than runs.size() records in your
     * priority queue at a given moment. It is recommended that your Priority
     * Queue hold Pair<Record, Integer> objects where a Pair (r, i) is the
     * Record r with the smallest value you are sorting on currently unmerged
     * from run i. `i` can be useful to locate which record to add to the queue
     * next after the smallest element is removed.
     *
     * Return a single sorted run obtained by merging the input runs
     */
    public Run mergeSortedRuns(List<Run> runs) throws DatabaseException {
    	Run run = this.createRun();
    	PriorityQueue<Pair<Record, Integer>> pq = new PriorityQueue<>(new RecordPairComparator());
    	ArrayList<Iterator<Record>> iters = new ArrayList<>();
    	
    	for(int i = 0; i < runs.size(); i++) {
    		Iterator<Record> iter = runs.get(i).iterator();
    		
    		while (iter.hasNext()) {
    			pq.add(new Pair<>(iter.next(), i));
    		}
    	}
    	
    	while (!pq.isEmpty()) {
    		run.addRecord(pq.poll().getFirst().getValues());
    	}
    	
    	return run;
    }

    /**
     * Given a list of N sorted runs, returns a list of sorted runs that is the
     * result of merging (numBuffers - 1) of the input runs at a time. If N is
     * not a perfect multiple of (numBuffers - 1) the last sorted run should be
     * the result of merging less than (numBuffers - 1) runs.
     *
     * Return a list of sorted runs obtained by merging the input runs
     */
    public List<Run> mergePass(List<Run> runs) throws DatabaseException {
    	List<Run> sortRun = new ArrayList<>();
    	
    	for (int i = 0; i < runs.size(); i += (this.numBuffers - 1)) {
    		int idx = Math.min(runs.size(), i + (this.numBuffers - 1));
    		sortRun.add(this.mergeSortedRuns(runs.subList(i, idx)));
    	}
    	
    	return sortRun;
    }

    /**
     * Does an external merge sort on the table with name tableName
     * using numBuffers.
     * Returns the name of the table that backs the final run.
     */
    public String sort() throws DatabaseException {
        List<Run> sorted = new ArrayList<>();
        
        PageIterator iter = this.transaction.getPageIterator(this.tableName);
        iter.next();
        
        while (iter.hasNext()) {
        	BacktrackingIterator<Record> recordIterator = this.transaction.getBlockIterator(this.tableName, iter, this.numBuffers);
        	Run run = this.createRun();
        	
        	while (recordIterator.hasNext()) {
        		run.addRecord(recordIterator.next().getValues());
        	}
        	sorted.add(sortRun(run));
        }
        
        return sorted.get(0).tableName();
    }

    public Iterator<Record> iterator() throws DatabaseException {
        if (sortedTableName == null) {
            sortedTableName = sort();
        }
        return this.transaction.getRecordIterator(sortedTableName);
    }

    private class RecordPairComparator implements Comparator<Pair<Record, Integer>> {
        public int compare(Pair<Record, Integer> o1, Pair<Record, Integer> o2) {
            return SortOperator.this.comparator.compare(o1.getFirst(), o2.getFirst());

        }
    }

    public Run createRun() throws DatabaseException {
        return new Run();
    }
}

