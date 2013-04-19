library(rJava)

options("digits.secs" = 3);
# OO stuff taken from http://bryer.org/2012/object-oriented-programming-in-r

initJava <- function() {
	.jinit()
	# TODO: find the path properly. Maybe use system.file ? Or better yet, .jpackage?
	.jaddClassPath("/Users/bohumil.koutsky/gd/bkoutsky/rsplunk") 	
	.jaddClassPath("/Users/bohumil.koutsky/gd/bkoutsky/rsplunk/splunk-1.1.jar") 	
}

Splunk <- function(username, password, host, port) {
	this <- list(
		username = username,
		password = password,
		host = host,
        port = port,
		get = function(x) this[[x]],
		set = function(x, value) this[[x]] <<- value
	)

    this$connect <- function() {
        this$splunk <- .jnew("Splunk", this$username, this$password, this$host, as.integer(this$port));
    }

    this$getApps <- function() {
        .jcall(this$splunk, "[S", "getApps");
    }

    this$mkSearch <- function(query, earliest, latest) {
        Search(this$splunk, query, earliest, latest);
    }

	this <- list2env(this)
	class(this) <- "Splunk"

    this$connect();
	return(this)
}

# Define S3 generic method for the print function.
print.Splunk <- function(x) {
	if(class(x) != "Splunk") stop();
	cat(paste(
        'Splunk\n',
        "  Host: ", x$get("host"), '\n',
        "  Username: ", x$get("username"), '\n', sep=''))
}



Search <- function(splunk, query, earliest, latest) {
    this <- list(
        query = query,
        earliest = earliest,
        latest = latest,
        splunk = splunk,
		get = function(x) this[[x]],
		set = function(x, value) this[[x]] <<- value
    )

    this$isRunning <- function() {
        .jcall(this$search, "Z", "isRunning");
    }

    this$numResults <- function() {
        .jcall(this$search, "I", "numResults");
    }

    this$column <- function(i) {
        desc <- strsplit(.jcall(this$search, "S", "getColumnDesc", as.integer(i))," ")[[1]] ;
        objs <- .jcall(this$search, "[Ljava/lang/Object;", "getColumnValues", as.integer(i));

        x <- sapply(objs, function(x) {if (is.jnull(x)) { NA } else { .jcall(x, desc[[1]], desc[[2]])}});
        if (desc[[3]] == "timestamps") {
            x <- as.POSIXct(x);
        }
        x;
    }

    this$mkdf = function() {
        fields <- .jcall(this$search, "[S", "getFieldNames");
    
        fieldNo = 0;
        columns = list();
        for (field in fields) {
            # TODO: assigning directly to a list element may be
            # and undocumented implementation peculiarity.
            # Verify & fix if needed
            columns[[field]] <- this$column(fieldNo);
            fieldNo <- fieldNo+1;
        }
        data.frame(columns);
    }

    this$result <- function() {
        # TODO: this is probably not needed, default shoud work even on empty data.
        if (.jcall(this$search, "Z", "columnize")) {
            this$mkdf();
        }
        else {
            data.frame();
        }
    }

    this$search <- .jnew("Search", splunk, query, earliest, latest);

	this <- list2env(this)
	class(this) <- "SplunkSearch"

	return(this)
}

# Define S3 generic method for the print function.
print.SplunkSearch <- function(x) {
	if(class(x) != "SplunkSearch") stop();
	cat(paste(
        'Splunk Search\n', 
        " Query: ", x$get("query"), "\n",
        " From: ", x$get("earliest"), " To: ", x$get("latest"), "\n",
        " Running: ", x$isRunning(), "\n",
        " Number of results: ", x$numResults(), "\n",
        sep=""));
}

username <- Sys.getenv("SPLUNK_USERNAME");
password <- Sys.getenv("SPLUNK_PASSWORD");
host <- Sys.getenv("SPLUNK_HOST");


initJava();
splunk <- Splunk(username, password, host, 8089);

print(splunk);
#apps <- splunk$getApps();
#print(apps);

tt = splunk$mkSearch('search index=gdc host=cl-pdwh* gcf_event="task computed" task_type="perl.pixtab.*" | eval time=time/1000/60 | timechart span=10min sum(time) as time', "-10min@min-10sec", "-10min@min");
#tt = splunk$mkSearch('search index=gdc sourcetype=erlang host=cl-gcf* gcf_event="task started" | fields _time, host, task_type, gcf_event, waiting_cnt', "-10min@min", "-9min@min");
print(tt);


options(width = 250);
while(tt$isRunning()) {
    print(tt$result());
    foo <- tt$result();
    Sys.sleep(0.1);
}
bar <- tt$result();

print(bar);
print(class(bar$X_time));
