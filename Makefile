JAR_SPLUNK = splunk-1.1.jar
CLASSPATH = .:$(JAR_SPLUNK)

JAVAC = javac
JAVAC_FLAGS = -Xlint -g -cp $(CLASSPATH)

.SUFFIXES: .java .class

.java.class:
	$(JAVAC) $(JAVAC_FLAGS) $*.java

JAVA_SRC = \
        Splunk.java \
		Search.java

all: build

classes: $(JAVA_SRC:.java=.class)

clean:
	$(RM) *.class

build: classes

jrun: build
	java -cp $(CLASSPATH) Splunk ${SPLUNK_USERNAME} ${SPLUNK_PASSWORD} ${SPLUNK_HOST}


rrun: build
	Rscript rsplunk.R
