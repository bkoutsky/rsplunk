library(rJava)


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

#' Define S3 generic method for the print function.
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

    this$result <- function() {
        if (.jcall(this$search, "Z", "columnize")) {
            host <- .jcall(this$search, "[S", "getColumnString", as.integer(0));
            data.frame(host);
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

#' Define S3 generic method for the print function.
print.SplunkSearch <- function(x) {
	if(class(x) != "SplunkSearch") stop();
	cat(paste(
        'Splunk Search\n', 
        " Query: ", x$get("query"), "\n",
        " From: ", x$get("earliest"), " to ", x$get("latest"), "\n",
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

tt = splunk$mkSearch("search index=gdc host=cl-pdw*| stats count by host", "-10min@min", "now");
print(tt);


while(tt$isRunning()) {
    print(tt$result());
    cat("\n===\n");
    Sys.sleep(0.1);
}
print(tt$result());

