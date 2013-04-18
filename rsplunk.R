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

	this$search <- function(query) {
		#stuff here
	}

    this$connect <- function() {
        this$splunk <- .jnew("Splunk", this$username, this$password, this$host, as.integer(this$port));
    }

    this$getApps <- function() {
        .jcall(this$splunk, "[S", "getApps");
    }

	this <- list2env(this)
	class(this) <- "Splunk"

    this$connect();
	return(this)
}
 

username <- Sys.getenv("SPLUNK_USERNAME");
password <- Sys.getenv("SPLUNK_PASSWORD");
host <- Sys.getenv("SPLUNK_HOST");

#' Define S3 generic method for the print function.
print.Splunk <- function(x) {
	if(class(x) != "Splunk") stop();
	cat(paste('Splunk Server "', x$get("host"), '"', '", connected as "', x$get("username"), '".', sep=''))
}


initJava();
splunk <- Splunk(username, password, host, 8089);

print(splunk);
apps <- splunk$getApps();
print(apps);
