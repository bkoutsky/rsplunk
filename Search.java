import java.util.ArrayList;
import java.io.InputStream;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Pattern;

import com.splunk.Service;
import com.splunk.MultiResultsReaderXml;
import com.splunk.JobExportArgs;
import com.splunk.SearchResults;
import com.splunk.Event;

class Search extends Thread {

    private Splunk splunk;
    private String query;
    private String earliest, latest;
    private String errorMessage;
    private boolean columnsDone;

    private MultiResultsReaderXml multiResultsReader;
    private ArrayList<Event> results = new ArrayList<Event>(10000);
    private TreeSet<String> fields = new TreeSet<String>();
    private Column [] columns;

    public static final int STRING = 1;
    public static final int DOUBLE = 2;
    public static final int INT = 3;


    // Handling of the Columns is suboptimal in regard to memory consumption.
    // I collect all the values as Objects first
    // then, when asked, convert to [] of primitives/Strings
    // OTOH, it allows us to easily automatically detect "best" possible
    // type for the column.
    
    final static Pattern reInt = Pattern.compile("^\\d+$");
    // TODO: handle exp. notation
    final static Pattern reDouble = Pattern.compile("^\\d+\\.\\d+$");
    final static Pattern reTimestamp = Pattern.compile("^\\d{4}-\\d{1,2}-\\d{1,2} \\d{1,2}:\\d{1,2}:\\d{1,2}\\.\\d+? [A-Z]+$");

    class Column {
        String name;
        Object [] values;
        int type;
        boolean onlyNulls;
        boolean onlyTimestamps;

        Column(String name, int size) {
            this.type = INT;
            this.name = name;
            values = new Object[size];
            onlyNulls = true;
            onlyTimestamps = true;
        }

        int size() {
            return values.length;
        }

        // Adds values to the column, also tracks the "best" possible type
        // for this column so far.
        void add(Event event, int index) {
            String s = event.get(name);
            Object o;

            if (s == null) {
                values[index] = null;
                return;
            }

            onlyNulls = false;

            if (reTimestamp.matcher(s).matches()) {
                type = STRING;
                values[index] = s;
                return;
            }

            onlyTimestamps = false;

            if (reInt.matcher(s).matches()) {
                type = Math.min(type, INT);
                o = new Integer(s);
            }
            else if (reDouble.matcher(s).matches()) {
                type = Math.min(type, DOUBLE);
                o = new Double(s);
            }
            else {
                type = STRING;
                o = s;
            }

            values[index] = o;
        }

        Object [] values() {
            Object [] result = new Object[values.length];
            int i=0;
            for(Object o: values) {
                result[i++] = o;
            }
            return result;
        }

        String getName() {
            return this.name;
        }

        String getSubType() {
            return onlyTimestamps ? "timestamps" : "none";
        }
        
        String getDesc() {
            String desc;
            switch(this.type) {
                case INT:
                    desc = "I intValue";
                    break;
                case DOUBLE:
                    desc = "D doubleValue";
                    break;
                case STRING:
                    desc = "Ljava/lang/String; toString";
                    break;
                default:
                    throw new Error("Unexpected type " + type);
            }
            desc += " " + getSubType();
            return desc;
        }
    }

    public Search(Splunk splunk, String query, String earliest, String latest) {
        this.columnsDone = false;
        this.splunk = splunk;
        this.query = query;
        this.earliest = earliest;
        this.latest = latest;
        this.start();
    }

    public int numResults() {
        return results.size();
    }

    public boolean isRunning() {
        return isAlive();
    }

    public boolean hasError() {
        return this.errorMessage != null;
    }

    public String getErrorMessage() {
        return this.errorMessage;
    }
    public void run() {
        try {
            startSearch();
            readResults();
            this.errorMessage = null;
        }
        catch (java.io.IOException e) {
            this.errorMessage = e.getMessage();
        }
    }

    private void startSearch() throws java.io.IOException {

        JobExportArgs jobArgs = new JobExportArgs();
        jobArgs.setOutputMode(JobExportArgs.OutputMode.XML);
        jobArgs.setSearchMode(JobExportArgs.SearchMode.NORMAL);

        jobArgs.setEarliestTime(this.earliest);
        jobArgs.setLatestTime(this.latest);

        //TODO: support at least following options
        //jobargs.setMaximumLines=
        //jobargs.setMaximumTime=
        
        InputStream stream = this.splunk.getService().export(this.query, jobArgs);

        this.multiResultsReader = new MultiResultsReaderXml(stream);
    }

    private void readResults() throws java.io.IOException {
        boolean lastWasPreview = true;
        for (SearchResults searchResults : this.multiResultsReader)
        {
            //searchResults.isPreview()
            // for (String f: searchResults.getFields()) { fields = fields + " " + f; };
            ArrayList<Event> newResults = new ArrayList<Event>();
            for (Event e : searchResults) {
                newResults.add(e);
            }
            // make sure we change everything atomically
            synchronized(this) {
                // I'm not quite sure about the semantics of the Splunk API at this point.
                // I assume the following about export searches:
                // - Transforming searches:
                // -- First send multiple SearchResults with .isPreview()==true, each contains "complete" preview.
                //    Thus, while receiving previews, each time new one arrives, replace old one with new one.
                // -- Then send one or more SearchResults with .isPreview()==false, each containing part of the result.
                //    Thus, while receiving finals, append each one to old ones.
                // - Non-transforming searches 
                // -- Do not send preview at all.
                // -- Results are spread over multiple SearchResults
                //    Thus, these SearchResults should be concetanated together.
                //    
                // This is probably a little to generic. It seems that the splunk API sends all the final results in a single
                // SearchResult (the last one). But to err on the side of caution, I'll assume there may be multiple final
                // that should be concated together. For the preview results, I'll assume that each SearchResult is "complete".
                
                if (searchResults.isPreview() || lastWasPreview) {
                    this.results.clear();
                    this.fields.clear();
                    lastWasPreview = searchResults.isPreview();
                }

                this.results.addAll(newResults);
                this.fields.addAll(searchResults.getFields());
                this.columnsDone = false;
            }
        }
        this.multiResultsReader.close();
    }

    // Parse list of events and create result columns from snapshot of current result (may be incomplete/preview)
    public boolean columnize() {
        ArrayList<Event> snapResults;
        TreeSet<String> snapFields;
        synchronized(this) {
            snapResults = new ArrayList<Event>(this.results);
            snapFields = new TreeSet<String>(this.fields);
            if(snapFields.size() == 0) {
                // no fields in the result
                return false;
            }
            if (!this.isRunning()) {
                // Search is finished already, so...
                if (this.columnsDone) {
                    // ... either do nothing, we already columnized final data.
                    return true;
                }
                else {
                    // ... or remember that after this, we will have columnized final data.
                    this.columnsDone = true;
                }
            }
        }
        // TODO: remove debug code
        //for (String s: snapField) {
        //    System.out.println("field: " + s);
        //}

        this.columns = new Column[snapFields.size()];
        int column = 0;
        for (String name: snapFields) {
            this.columns[column++] = new Column(name, snapResults.size());
        }
        
        int row = 0;
        for (Event e: snapResults) {
            column = 0;
            for (String name: snapFields) {
                this.columns[column++].add(e, row);
            }
            row++;
        }
        return true;
    }

    public Object [] getColumnValues(int c) {
        return columns[c].values();
    }

    public String getColumnDesc(int c) {
        return this.columns[c].getDesc();
    }

    public String[] getFieldNames() {
        String [] names = new String [this.columns.length];
        for (int i = 0; i < columns.length; i++) {
            names[i] = columns[i].getName();
        }
        return names;
    }
}    
